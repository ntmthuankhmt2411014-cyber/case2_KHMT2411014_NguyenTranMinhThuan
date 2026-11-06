const EmailLog = require('../models/emailLog.model');
const { sendMail } = require('./mailer');

// Lỗi SMTP có thể chứa xuống dòng hoặc nội dung dài; lưu gọn để hiển thị.
function sanitizeErrorMessage(error) {
  const raw = error && error.message ? error.message : String(error || 'Lỗi gửi email');
  return raw.replace(/\s+/g, ' ').trim().slice(0, 300);
}

// Nội dung tối thiểu khi gửi lại: email_logs không lưu body gốc.
function buildRetryText(task) {
  return `Công việc "${task.title}" có cập nhật mới. Vui lòng mở ứng dụng Task Manager để xem chi tiết.`;
}

// Gửi một log đã có sẵn, luôn lưu kết quả rồi resolve.
// Nhờ vậy lỗi SMTP không bao giờ làm hỏng thao tác chính của người dùng.
async function sendLog(log, text) {
  log.attempts += 1;

  try {
    await sendMail({
      to: log.recipientEmail,
      subject: log.subject,
      text,
    });
    log.status = 'sent';
    log.sentAt = new Date();
    log.errorMessage = '';
  } catch (error) {
    log.status = 'failed';
    log.errorMessage = sanitizeErrorMessage(error);
  }

  await log.save();
  return log;
}

// Tạo bản ghi pending trước, sau đó gửi và cập nhật sent/failed.
async function queueAndSendEmail({ taskId = null, recipientEmail, eventType, subject, text }) {
  const log = await EmailLog.create({
    taskId: taskId || null,
    recipientEmail,
    eventType,
    subject,
    status: 'pending',
    attempts: 0,
  });

  return sendLog(log, text);
}

function listLogsByTask(taskId) {
  return EmailLog.find({ taskId }).sort({ createdAt: -1 });
}

module.exports = {
  queueAndSendEmail,
  sendLog,
  listLogsByTask,
  sanitizeErrorMessage,
  buildRetryText,
};
