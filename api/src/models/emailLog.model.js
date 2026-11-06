const mongoose = require('mongoose');
const { ALL_EVENT_TYPES } = require('../utils/notificationEvents');

// Lịch sử gửi email. Một bản ghi được tạo trước khi gửi (pending)
// rồi cập nhật thành sent/failed kèm số lần thử và lỗi nếu có.
const emailLogSchema = new mongoose.Schema({
  taskId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Task',
    default: null,
  },
  recipientEmail: {
    type: String,
    required: true,
    trim: true,
  },
  eventType: {
    type: String,
    required: true,
    enum: ALL_EVENT_TYPES,
  },
  subject: {
    type: String,
    default: '',
  },
  status: {
    type: String,
    enum: ['pending', 'sent', 'failed'],
    default: 'pending',
  },
  attempts: {
    type: Number,
    default: 0,
  },
  errorMessage: {
    type: String,
    default: '',
  },
  sentAt: {
    type: Date,
    default: null,
  },
  createdAt: {
    type: Date,
    default: Date.now,
  },
});

emailLogSchema.index({ taskId: 1, createdAt: -1 });
// Dùng để kiểm tra đã nhắc hạn cho người này trong 24h qua chưa.
emailLogSchema.index({ recipientEmail: 1, eventType: 1, createdAt: -1 });

module.exports = mongoose.model('EmailLog', emailLogSchema);
