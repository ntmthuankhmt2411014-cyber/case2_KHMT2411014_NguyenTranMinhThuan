const mongoose = require('mongoose');
const Task = require('../models/task.model');
const EmailLog = require('../models/emailLog.model');
const emailService = require('../services/email.service');
const { shouldRetryLog } = require('../utils/notificationEvents');

function isValidId(value) {
  return typeof value === 'string' && mongoose.Types.ObjectId.isValid(value);
}

// 1. Lịch sử gửi email của một công việc.
// Chỉ người tạo được xem, giống quyền quản lý giao việc/chia sẻ.
exports.getTaskEmailLogs = async (req, res) => {
  try {
    if (!isValidId(req.params.id)) {
      return res.status(400).json({ message: 'ID công việc không hợp lệ' });
    }

    const task = await Task.findById(req.params.id);
    if (!task) {
      return res.status(404).json({ message: 'Không tìm thấy công việc' });
    }

    if (String(task.createdBy) !== String(req.user._id)) {
      return res.status(403).json({ message: 'Bạn không có quyền xem lịch sử email của công việc này' });
    }

    const emailLogs = await emailService.listLogsByTask(task._id);
    return res.status(200).json({ emailLogs });
  } catch (error) {
    console.error('Lỗi lấy lịch sử email:', error);
    return res.status(500).json({ message: 'Lỗi server khi lấy lịch sử email' });
  }
};

// 2. Gửi lại một email đã thất bại.
exports.retryEmailLog = async (req, res) => {
  try {
    if (!isValidId(req.params.id)) {
      return res.status(400).json({ message: 'ID email không hợp lệ' });
    }

    const log = await EmailLog.findById(req.params.id);
    if (!log) {
      return res.status(404).json({ message: 'Không tìm thấy email' });
    }

    if (!log.taskId) {
      return res.status(400).json({ message: 'Email không gắn với công việc nào' });
    }

    const task = await Task.findById(log.taskId);
    if (!task) {
      return res.status(404).json({ message: 'Không tìm thấy công việc' });
    }

    if (String(task.createdBy) !== String(req.user._id)) {
      return res.status(403).json({ message: 'Bạn không có quyền gửi lại email của công việc này' });
    }

    if (!shouldRetryLog(log)) {
      return res.status(400).json({
        message: 'Chỉ gửi lại được email đã thất bại và chưa quá 3 lần',
      });
    }

    const emailLog = await emailService.sendLog(log, emailService.buildRetryText(task));
    return res.status(200).json({ success: true, emailLog });
  } catch (error) {
    console.error('Lỗi gửi lại email:', error);
    return res.status(500).json({ message: 'Lỗi server khi gửi lại email' });
  }
};
