const mongoose = require('mongoose');
const Task = require('../models/task.model');
const TaskShare = require('../models/taskShare.model');
const User = require('../models/user.model');
const { getTaskAccess } = require('../utils/taskPermissions');
const { validateSharePermission } = require('../utils/shareRules');
const taskEventService = require('../services/taskEvent.service');
const { EVENT_TYPES } = require('../utils/notificationEvents');

const SHARE_POPULATE = [
  { path: 'userId', select: 'fullName email avatarUrl' },
  { path: 'sharedBy', select: 'fullName email' },
];

function isValidId(value) {
  return typeof value === 'string' && mongoose.Types.ObjectId.isValid(value);
}

// Tìm công việc và quyền của người dùng hiện tại.
// Trả về null nếu đã gửi response lỗi.
async function loadTaskAndAccess(req, res) {
  if (!isValidId(req.params.id)) {
    res.status(400).json({ message: 'ID công việc không hợp lệ' });
    return null;
  }

  const task = await Task.findById(req.params.id);
  if (!task) {
    res.status(404).json({ message: 'Không tìm thấy công việc' });
    return null;
  }

  const share = await TaskShare.findOne({ taskId: task._id, userId: req.user._id });
  return { task, access: getTaskAccess(task, req.user._id, share) };
}

async function listShares(taskId) {
  return TaskShare.find({ taskId })
    .populate('userId', 'fullName email avatarUrl')
    .populate('sharedBy', 'fullName email')
    .sort({ createdAt: 1 });
}

// 1. Danh sách người được chia sẻ
exports.getShares = async (req, res) => {
  try {
    const loaded = await loadTaskAndAccess(req, res);
    if (!loaded) return;

    if (!loaded.access.canView) {
      return res.status(403).json({ message: 'Bạn không có quyền truy cập công việc này' });
    }

    const shares = await listShares(loaded.task._id);
    return res.status(200).json({ shares });
  } catch (error) {
    console.error('Lỗi lấy danh sách chia sẻ:', error);
    return res.status(500).json({ message: 'Lỗi server khi lấy danh sách chia sẻ' });
  }
};

// 2. Chia sẻ công việc cho một hoặc nhiều người
exports.shareUsers = async (req, res) => {
  try {
    const loaded = await loadTaskAndAccess(req, res);
    if (!loaded) return;

    const { task, access } = loaded;
    if (!access.canManageShares) {
      return res.status(403).json({ message: 'Bạn không có quyền chia sẻ công việc này' });
    }

    const { userIds, permission } = req.body || {};

    try {
      validateSharePermission(permission);
    } catch (error) {
      return res.status(400).json({ message: error.message });
    }

    if (!Array.isArray(userIds) || userIds.length === 0) {
      return res.status(400).json({ message: 'Danh sách người được chia sẻ không được để trống' });
    }

    const normalizedIds = [...new Set(userIds.map((id) => String(id)))];
    if (normalizedIds.some((id) => !isValidId(id))) {
      return res.status(400).json({ message: 'ID người dùng không hợp lệ' });
    }

    if (normalizedIds.includes(task.createdBy.toString())) {
      return res.status(400).json({ message: 'Không thể chia sẻ công việc cho chính người tạo' });
    }

    const users = await User.find({ _id: { $in: normalizedIds } }).select('_id');
    if (users.length !== normalizedIds.length) {
      return res.status(400).json({ message: 'Một hoặc nhiều người dùng không tồn tại' });
    }

    // Xác định ai là người mới trước khi upsert để không gửi thông báo trùng
    // cho người đã được chia sẻ từ trước.
    const existing = await TaskShare.find({
      taskId: task._id,
      userId: { $in: normalizedIds },
    }).select('userId');
    const existingIds = new Set(existing.map((item) => String(item.userId)));
    const newShareIds = normalizedIds.filter((id) => !existingIds.has(id));

    // Upsert để chia sẻ lại chỉ cập nhật quyền, không tạo bản ghi trùng.
    for (const userId of normalizedIds) {
      await TaskShare.findOneAndUpdate(
        { taskId: task._id, userId },
        { $set: { permission, sharedBy: req.user._id } },
        { upsert: true, returnDocument: 'after', runValidators: true }
      );
    }

    const shares = await listShares(task._id);

    // Chỉ báo cho người vừa được chia sẻ, kèm quyền họ nhận được.
    if (newShareIds.length > 0) {
      try {
        await taskEventService.emitTaskEvent({
          task,
          actorId: req.user._id,
          actorName: req.user.fullName,
          eventType: EVENT_TYPES.TASK_SHARED,
          targetUserIds: newShareIds,
          permission,
        });
      } catch (error) {
        // Lỗi thông báo/email không được làm hỏng thao tác chia sẻ.
        console.error('Lỗi gửi thông báo chia sẻ:', error);
      }
    }

    return res.status(200).json({
      message: 'Chia sẻ công việc thành công',
      shares,
    });
  } catch (error) {
    console.error('Lỗi chia sẻ công việc:', error);
    return res.status(500).json({ message: 'Lỗi server khi chia sẻ công việc' });
  }
};

// 3. Cập nhật quyền của một bản ghi chia sẻ
exports.updateSharePermission = async (req, res) => {
  try {
    const loaded = await loadTaskAndAccess(req, res);
    if (!loaded) return;

    const { task, access } = loaded;
    if (!access.canManageShares) {
      return res.status(403).json({ message: 'Bạn không có quyền thay đổi quyền chia sẻ' });
    }

    const { shareId } = req.params;
    if (!isValidId(shareId)) {
      return res.status(400).json({ message: 'ID chia sẻ không hợp lệ' });
    }

    const { permission } = req.body || {};
    try {
      validateSharePermission(permission);
    } catch (error) {
      return res.status(400).json({ message: error.message });
    }

    const share = await TaskShare.findOne({ _id: shareId, taskId: task._id });
    if (!share) {
      return res.status(404).json({ message: 'Không tìm thấy chia sẻ' });
    }

    // Lưu id dạng chuỗi trước khi populate vì populate sẽ thay userId bằng object.
    const shareUserId = String(share.userId);

    share.permission = permission;
    await share.save();
    await share.populate(SHARE_POPULATE);

    // Đổi quyền cũng là một lần chia sẻ lại: báo cho người được đổi quyền.
    try {
      await taskEventService.emitTaskEvent({
        task,
        actorId: req.user._id,
        actorName: req.user.fullName,
        eventType: EVENT_TYPES.TASK_SHARED,
        targetUserIds: [shareUserId],
        permission,
      });
    } catch (error) {
      console.error('Lỗi gửi thông báo đổi quyền chia sẻ:', error);
    }

    return res.status(200).json({
      message: 'Cập nhật quyền chia sẻ thành công',
      share,
    });
  } catch (error) {
    console.error('Lỗi cập nhật quyền chia sẻ:', error);
    return res.status(500).json({ message: 'Lỗi server khi cập nhật quyền chia sẻ' });
  }
};

// 4. Thu hồi quyền chia sẻ
exports.removeShare = async (req, res) => {
  try {
    const loaded = await loadTaskAndAccess(req, res);
    if (!loaded) return;

    const { task, access } = loaded;
    if (!access.canManageShares) {
      return res.status(403).json({ message: 'Bạn không có quyền thu hồi chia sẻ' });
    }

    const { shareId } = req.params;
    if (!isValidId(shareId)) {
      return res.status(400).json({ message: 'ID chia sẻ không hợp lệ' });
    }

    const share = await TaskShare.findOneAndDelete({ _id: shareId, taskId: task._id });
    if (!share) {
      return res.status(404).json({ message: 'Không tìm thấy chia sẻ' });
    }

    return res.status(200).json({ message: 'Thu hồi quyền chia sẻ thành công' });
  } catch (error) {
    console.error('Lỗi thu hồi chia sẻ:', error);
    return res.status(500).json({ message: 'Lỗi server khi thu hồi chia sẻ' });
  }
};
