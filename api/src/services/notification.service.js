const Notification = require('../models/notification.model');

// Tạo nhiều thông báo cùng lúc; bỏ qua nếu không có người nhận.
async function createNotifications({ userIds, taskId, type, title, message }) {
  if (!Array.isArray(userIds) || userIds.length === 0) return [];

  return Notification.insertMany(
    userIds.map((userId) => ({ userId, taskId, type, title, message }))
  );
}

function listForUser(userId, limit = 50) {
  return Notification.find({ userId }).sort({ createdAt: -1 }).limit(limit);
}

function unreadCount(userId) {
  return Notification.countDocuments({ userId, isRead: false });
}

// Chỉ tìm trong thông báo của chính người dùng để tránh đọc/sửa hộ người khác.
function markRead(userId, notificationId) {
  return Notification.findOneAndUpdate(
    { _id: notificationId, userId },
    { $set: { isRead: true } },
    { new: true }
  );
}

async function markAllRead(userId) {
  const result = await Notification.updateMany(
    { userId, isRead: false },
    { $set: { isRead: true } }
  );
  return result.modifiedCount;
}

module.exports = {
  createNotifications,
  listForUser,
  unreadCount,
  markRead,
  markAllRead,
};
