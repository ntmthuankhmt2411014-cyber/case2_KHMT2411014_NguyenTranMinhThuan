const mongoose = require('mongoose');
const { ALL_EVENT_TYPES } = require('../utils/notificationEvents');

// Thông báo trong ứng dụng. Mỗi bản ghi thuộc về đúng một người nhận.
const notificationSchema = new mongoose.Schema({
  userId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true,
  },
  taskId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Task',
    required: true,
  },
  type: {
    type: String,
    required: true,
    enum: ALL_EVENT_TYPES,
  },
  title: {
    type: String,
    required: true,
    trim: true,
  },
  message: {
    type: String,
    required: true,
  },
  isRead: {
    type: Boolean,
    default: false,
  },
  createdAt: {
    type: Date,
    default: Date.now,
  },
});

// Truy vấn chính: thông báo của một người, mới nhất trước, lọc chưa đọc.
notificationSchema.index({ userId: 1, isRead: 1, createdAt: -1 });

module.exports = mongoose.model('Notification', notificationSchema);
