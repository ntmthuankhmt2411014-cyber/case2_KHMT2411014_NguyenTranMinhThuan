const mongoose = require('mongoose');
const notificationService = require('../services/notification.service');

// Giới hạn số thông báo trả về: mặc định 50, tối đa 100.
function parseLimit(value) {
  const parsed = parseInt(value, 10);
  if (Number.isNaN(parsed)) return 50;
  return Math.min(Math.max(parsed, 1), 100);
}

// 1. Danh sách thông báo của người dùng hiện tại
exports.getNotifications = async (req, res) => {
  try {
    const notifications = await notificationService.listForUser(
      req.user._id,
      parseLimit(req.query.limit)
    );
    return res.status(200).json({ notifications });
  } catch (error) {
    console.error('Lỗi lấy danh sách thông báo:', error);
    return res.status(500).json({ message: 'Lỗi server khi lấy danh sách thông báo' });
  }
};

// 2. Đếm số thông báo chưa đọc
exports.getUnreadCount = async (req, res) => {
  try {
    const count = await notificationService.unreadCount(req.user._id);
    return res.status(200).json({ count });
  } catch (error) {
    console.error('Lỗi đếm thông báo chưa đọc:', error);
    return res.status(500).json({ message: 'Lỗi server khi đếm thông báo chưa đọc' });
  }
};

// 3. Đánh dấu một thông báo đã đọc
exports.markRead = async (req, res) => {
  try {
    const { id } = req.params;
    if (!mongoose.Types.ObjectId.isValid(id)) {
      return res.status(400).json({ message: 'ID thông báo không hợp lệ' });
    }

    const notification = await notificationService.markRead(req.user._id, id);
    if (!notification) {
      // Trả 404 thay vì 403 để không tiết lộ thông báo của người khác.
      return res.status(404).json({ message: 'Không tìm thấy thông báo' });
    }

    return res.status(200).json({ success: true, notification });
  } catch (error) {
    console.error('Lỗi đánh dấu thông báo đã đọc:', error);
    return res.status(500).json({ message: 'Lỗi server khi đánh dấu thông báo đã đọc' });
  }
};

// 4. Đánh dấu tất cả thông báo đã đọc
exports.markAllRead = async (req, res) => {
  try {
    const modifiedCount = await notificationService.markAllRead(req.user._id);
    return res.status(200).json({ success: true, modifiedCount });
  } catch (error) {
    console.error('Lỗi đánh dấu tất cả thông báo đã đọc:', error);
    return res.status(500).json({ message: 'Lỗi server khi đánh dấu tất cả thông báo đã đọc' });
  }
};

// Xuất riêng để unit test phần thuần, không cần kết nối MongoDB.
exports.parseLimit = parseLimit;
