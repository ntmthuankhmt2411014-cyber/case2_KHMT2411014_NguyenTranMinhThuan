const mongoose = require('mongoose');
const Task = require('../models/task.model');
const TaskShare = require('../models/taskShare.model');
const User = require('../models/user.model');
const { getTaskAccess } = require('../utils/taskPermissions');
const { resolvePrimaryAssignee } = require('../utils/assigneeRules');

const USER_FIELDS = 'fullName email avatarUrl';

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

function assigneeIdsOf(task) {
  return (task.assigneeIds || []).map((id) => id.toString());
}

function primaryIdOf(task) {
  return task.primaryAssigneeId ? task.primaryAssigneeId.toString() : null;
}

// Trả danh sách người được giao kèm thông tin người dùng đã populate
async function respondAssignees(res, task, message) {
  const populated = await Task.findById(task._id)
    .populate('assigneeIds', USER_FIELDS)
    .populate('primaryAssigneeId', USER_FIELDS);

  return res.status(200).json({
    ...(message ? { message } : {}),
    assignees: populated.assigneeIds,
    primaryAssigneeId: populated.primaryAssigneeId
      ? populated.primaryAssigneeId._id.toString()
      : null,
  });
}

// 1. Danh sách người được giao
exports.getAssignees = async (req, res) => {
  try {
    const loaded = await loadTaskAndAccess(req, res);
    if (!loaded) return;

    if (!loaded.access.canView) {
      return res.status(403).json({ message: 'Bạn không có quyền truy cập công việc này' });
    }

    return respondAssignees(res, loaded.task);
  } catch (error) {
    console.error('Lỗi lấy danh sách người được giao:', error);
    return res.status(500).json({ message: 'Lỗi server khi lấy danh sách người được giao' });
  }
};

// 2. Giao việc cho một hoặc nhiều người
exports.assignUsers = async (req, res) => {
  try {
    const loaded = await loadTaskAndAccess(req, res);
    if (!loaded) return;

    const { task, access } = loaded;
    if (!access.canAssign) {
      return res.status(403).json({ message: 'Bạn không có quyền giao việc cho công việc này' });
    }

    const { userIds, primaryAssigneeId } = req.body || {};
    if (!Array.isArray(userIds) || userIds.length === 0) {
      return res.status(400).json({ message: 'Danh sách người được giao không được để trống' });
    }

    const normalizedIds = [...new Set(userIds.map((id) => String(id)))];
    if (normalizedIds.some((id) => !isValidId(id))) {
      return res.status(400).json({ message: 'ID người dùng không hợp lệ' });
    }
    if (primaryAssigneeId && !isValidId(String(primaryAssigneeId))) {
      return res.status(400).json({ message: 'ID người phụ trách chính không hợp lệ' });
    }

    const users = await User.find({ _id: { $in: normalizedIds } }).select('_id');
    if (users.length !== normalizedIds.length) {
      return res.status(400).json({ message: 'Một hoặc nhiều người dùng không tồn tại' });
    }

    const mergedIds = [...new Set([...assigneeIdsOf(task), ...normalizedIds])];

    let primary;
    try {
      primary = resolvePrimaryAssignee(
        mergedIds,
        primaryIdOf(task),
        primaryAssigneeId ? String(primaryAssigneeId) : null
      );
    } catch (error) {
      return res.status(400).json({ message: error.message });
    }

    task.assigneeIds = mergedIds.map((id) => new mongoose.Types.ObjectId(id));
    task.primaryAssigneeId = primary ? new mongoose.Types.ObjectId(primary) : null;
    await task.save();

    return respondAssignees(res, task, 'Giao việc thành công');
  } catch (error) {
    console.error('Lỗi giao việc:', error);
    return res.status(500).json({ message: 'Lỗi server khi giao việc' });
  }
};

// 3. Đặt một người đang được giao làm người phụ trách chính
exports.setPrimaryAssignee = async (req, res) => {
  try {
    const loaded = await loadTaskAndAccess(req, res);
    if (!loaded) return;

    const { task, access } = loaded;
    if (!access.canAssign) {
      return res.status(403).json({ message: 'Bạn không có quyền thay đổi người phụ trách chính' });
    }

    const userId = req.params.userId;
    if (!isValidId(userId)) {
      return res.status(400).json({ message: 'ID người dùng không hợp lệ' });
    }

    const ids = assigneeIdsOf(task);
    if (!ids.includes(userId)) {
      return res.status(400).json({ message: 'Người này không nằm trong danh sách người được giao' });
    }

    const { primaryAssigneeId } = req.body || {};
    if (primaryAssigneeId && !isValidId(String(primaryAssigneeId))) {
      return res.status(400).json({ message: 'ID người phụ trách chính không hợp lệ' });
    }

    let primary;
    try {
      primary = resolvePrimaryAssignee(
        ids,
        primaryIdOf(task),
        primaryAssigneeId ? String(primaryAssigneeId) : userId
      );
    } catch (error) {
      return res.status(400).json({ message: error.message });
    }

    task.primaryAssigneeId = new mongoose.Types.ObjectId(primary);
    await task.save();

    return res.status(200).json({
      message: 'Cập nhật người phụ trách chính thành công',
      primaryAssigneeId: primary,
    });
  } catch (error) {
    console.error('Lỗi cập nhật người phụ trách chính:', error);
    return res.status(500).json({ message: 'Lỗi server khi cập nhật người phụ trách chính' });
  }
};

// 4. Hủy giao việc cho một người
exports.removeAssignee = async (req, res) => {
  try {
    const loaded = await loadTaskAndAccess(req, res);
    if (!loaded) return;

    const { task, access } = loaded;
    if (!access.canAssign) {
      return res.status(403).json({ message: 'Bạn không có quyền hủy giao việc' });
    }

    const userId = req.params.userId;
    if (!isValidId(userId)) {
      return res.status(400).json({ message: 'ID người dùng không hợp lệ' });
    }

    const ids = assigneeIdsOf(task);
    if (!ids.includes(userId)) {
      return res.status(400).json({ message: 'Người này không nằm trong danh sách người được giao' });
    }

    const remainingIds = ids.filter((id) => id !== userId);
    // Nếu người bị xóa là phụ trách chính, helper sẽ tự chọn người còn lại đầu tiên.
    const primary = resolvePrimaryAssignee(remainingIds, primaryIdOf(task), null);

    task.assigneeIds = remainingIds.map((id) => new mongoose.Types.ObjectId(id));
    task.primaryAssigneeId = primary ? new mongoose.Types.ObjectId(primary) : null;
    await task.save();

    return respondAssignees(res, task, 'Hủy giao việc thành công');
  } catch (error) {
    console.error('Lỗi hủy giao việc:', error);
    return res.status(500).json({ message: 'Lỗi server khi hủy giao việc' });
  }
};
