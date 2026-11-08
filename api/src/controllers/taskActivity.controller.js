const mongoose = require('mongoose');
const Task = require('../models/task.model');
const TaskShare = require('../models/taskShare.model');
const { getTaskAccess } = require('../utils/taskPermissions');
const taskActivityService = require('../services/taskActivity.service');

// GET /api/tasks/:id/activities — lịch sử hoạt động của công việc.
// Chỉ người có quyền xem công việc (tạo, được giao, được chia sẻ) mới xem được.
exports.getTaskActivities = async (req, res) => {
  try {
    if (!mongoose.Types.ObjectId.isValid(req.params.id)) {
      return res.status(400).json({ message: 'ID công việc không hợp lệ' });
    }

    const task = await Task.findById(req.params.id);
    if (!task) {
      return res.status(404).json({ message: 'Không tìm thấy công việc' });
    }

    const share = await TaskShare.findOne({ taskId: task._id, userId: req.user._id });
    const access = getTaskAccess(task, req.user._id, share);
    if (!access.canView) {
      return res.status(403).json({ message: 'Bạn không có quyền truy cập công việc này' });
    }

    const activities = await taskActivityService.listTaskActivities(task._id);
    return res.status(200).json({ activities });
  } catch (error) {
    console.error('Lỗi lấy lịch sử hoạt động:', error);
    return res.status(500).json({ message: 'Lỗi server khi lấy lịch sử hoạt động' });
  }
};
