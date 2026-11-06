const TaskShare = require('../models/taskShare.model');
const User = require('../models/user.model');
const notificationService = require('./notification.service');
const emailService = require('./email.service');
const { buildEventContent, resolveRecipientIds } = require('../utils/notificationEvents');

const EMPTY_RESULT = { recipientCount: 0, notificationCount: 0, emailCount: 0 };

// Tạo thông báo trong app + gửi email cho một danh sách người nhận.
// Luôn trả về số liệu thay vì ném lỗi ra ngoài, để controller không bị hỏng
// chỉ vì SMTP/email gặp sự cố.
async function emitForRecipients({
  task,
  recipientIds = [],
  eventType,
  actorName,
  permission,
  dueDate,
}) {
  const uniqueIds = [...new Set(recipientIds.map((id) => String(id)))];
  if (uniqueIds.length === 0) return { ...EMPTY_RESULT };

  const users = await User.find({ _id: { $in: uniqueIds } }).select('fullName email');
  if (users.length === 0) return { ...EMPTY_RESULT };

  const content = buildEventContent({
    eventType,
    actorName,
    taskTitle: task.title,
    // Ưu tiên hạn mới được truyền vào (ví dụ sự kiện đổi hạn).
    dueDate: dueDate === undefined ? task.dueDate : dueDate,
    permission,
  });

  await notificationService.createNotifications({
    userIds: users.map((user) => user._id),
    taskId: task._id,
    type: eventType,
    title: content.title,
    message: content.message,
  });

  // Gửi song song; một email lỗi không chặn những email còn lại.
  const results = await Promise.allSettled(
    users.map((user) =>
      emailService.queueAndSendEmail({
        taskId: task._id,
        recipientEmail: user.email,
        eventType,
        subject: content.subject,
        text: content.text,
      })
    )
  );

  results.forEach((result) => {
    if (result.status === 'rejected') {
      console.error('Lỗi gửi email sự kiện:', result.reason);
    }
  });

  return {
    recipientCount: users.length,
    notificationCount: users.length,
    emailCount: results.filter((result) => result.status === 'fulfilled').length,
  };
}

// Tính người nhận theo loại sự kiện rồi gọi emitForRecipients.
// - task_assigned / task_shared: chỉ targetUserIds (người vừa được thêm/đổi quyền).
// - due_date_changed / task_completed: creator + assignee + share.
async function emitTaskEvent({
  task,
  actorId,
  actorName,
  eventType,
  targetUserIds = [],
  permission,
}) {
  const shareUserIds = await TaskShare.find({ taskId: task._id }).distinct('userId');

  const recipientIds = resolveRecipientIds({
    createdBy: task.createdBy,
    assigneeIds: task.assigneeIds,
    shareUserIds,
    actorId,
    eventType,
    targetUserIds,
  });

  return emitForRecipients({ task, recipientIds, eventType, actorName, permission });
}

module.exports = {
  emitForRecipients,
  emitTaskEvent,
};
