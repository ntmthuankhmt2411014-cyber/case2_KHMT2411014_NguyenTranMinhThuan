const cron = require('node-cron');
const Task = require('../models/task.model');
const TaskShare = require('../models/taskShare.model');
const User = require('../models/user.model');
const EmailLog = require('../models/emailLog.model');
const { EVENT_TYPES, resolveRecipientIds } = require('../utils/notificationEvents');
const { emitForRecipients } = require('../services/taskEvent.service');

// Quét và gửi thông báo/email nhắc nhở các công việc sắp đến hạn
async function scanAndRemind({ now = new Date() } = {}) {
  const hours = Number(process.env.REMINDER_HOURS) || 24;
  const windowEnd = new Date(now.getTime() + hours * 60 * 60 * 1000);

  // Tìm các công việc chưa hoàn thành có hạn chót trong khoảng (now, now + hours]
  const tasks = await Task.find({
    status: { $ne: 'Completed' },
    dueDate: { $gt: now, $lte: windowEnd },
  }).select('_id title dueDate createdBy assigneeIds');

  let scanned = 0;
  let reminded = 0;

  for (const task of tasks) {
    scanned++;
    try {
      const shareUserIds = await TaskShare.find({ taskId: task._id }).distinct('userId');

      // Nhắc hạn do hệ thống kích hoạt nên actorId = null (gửi cho tất cả những người liên quan)
      const recipientIds = resolveRecipientIds({
        createdBy: task.createdBy,
        assigneeIds: task.assigneeIds,
        shareUserIds,
        actorId: null,
        eventType: EVENT_TYPES.DEADLINE_REMINDER,
      });

      if (recipientIds.length === 0) continue;

      const users = await User.find({ _id: { $in: recipientIds } }).select('email');
      const oneDayAgo = new Date(now.getTime() - 24 * 60 * 60 * 1000);

      // Chống gửi trùng: kiểm tra xem người nhận đã nhận email nhắc hạn cho task này trong 24h qua chưa
      const eligibleRecipientIds = [];
      for (const user of users) {
        const alreadyReminded = await EmailLog.exists({
          taskId: task._id,
          eventType: EVENT_TYPES.DEADLINE_REMINDER,
          recipientEmail: user.email,
          createdAt: { $gte: oneDayAgo },
        });

        if (!alreadyReminded) {
          eligibleRecipientIds.push(String(user._id));
        }
      }

      if (eligibleRecipientIds.length > 0) {
        const result = await emitForRecipients({
          task,
          recipientIds: eligibleRecipientIds,
          eventType: EVENT_TYPES.DEADLINE_REMINDER,
          actorName: 'Hệ thống',
        });
        reminded += result.recipientCount;
      }
    } catch (error) {
      console.error(`Lỗi nhắc hạn cho task ${task._id}:`, error);
    }
  }

  return { scanned, reminded };
}

// Khởi chạy tác vụ cron định kỳ
function startDeadlineReminderJob() {
  if (process.env.DISABLE_REMINDER_JOB === 'true') {
    return null;
  }

  const cronSchedule = process.env.REMINDER_CRON || '0 * * * *';
  const job = cron.schedule(cronSchedule, () => {
    scanAndRemind().catch((err) => {
      console.error('Lỗi chạy cron nhắc việc trước hạn:', err);
    });
  });

  console.log(`Cron nhắc việc trước hạn đã kích hoạt: ${cronSchedule}`);
  return job;
}

module.exports = {
  scanAndRemind,
  startDeadlineReminderJob,
};
