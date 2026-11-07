const TaskActivity = require('../models/taskActivity.model');

// Ghi lịch sử hoạt động. Lỗi ghi log không được làm hỏng thao tác chính
// (tạo/sửa/giao việc/chia sẻ vẫn phải thành công), nên chỉ log ra console.
async function logActivity({ taskId, userId, action, details = {} }) {
  try {
    await TaskActivity.create({ taskId, userId, action, details });
  } catch (error) {
    console.error('Lỗi ghi lịch sử hoạt động:', error);
  }
}

// Lấy lịch sử hoạt động của một công việc, mới nhất trước.
// Populate userId để client hiển thị tên người thao tác.
async function listTaskActivities(taskId) {
  return TaskActivity.find({ taskId })
    .populate('userId', 'fullName email avatarUrl')
    .sort({ createdAt: -1 })
    .limit(100);
}

module.exports = {
  logActivity,
  listTaskActivities,
};
