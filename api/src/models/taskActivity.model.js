const mongoose = require('mongoose');

// Các hành động được ghi vào lịch sử hoạt động của công việc.
const ACTIONS = [
  'created',
  'updated',
  'status_changed',
  'assigned',
  'primary_changed',
  'assignee_removed',
  'shared',
  'permission_changed',
  'share_removed',
];

// Collection task_activities: lịch sử thao tác trên công việc (mục E).
const taskActivitySchema = new mongoose.Schema({
  taskId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Task',
    required: true,
  },
  userId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true,
  },
  action: {
    type: String,
    required: true,
    enum: ACTIONS,
  },
  // Chi tiết thay đổi (from/to, danh sách người nhận, quyền...).
  // Dùng Mixed vì mỗi action có cấu trúc khác nhau.
  details: {
    type: mongoose.Schema.Types.Mixed,
    default: {},
  },
  createdAt: {
    type: Date,
    default: Date.now,
  },
});

// Truy vấn chính: lịch sử của một công việc, mới nhất trước.
taskActivitySchema.index({ taskId: 1, createdAt: -1 });

module.exports = mongoose.model('TaskActivity', taskActivitySchema, 'task_activities');
