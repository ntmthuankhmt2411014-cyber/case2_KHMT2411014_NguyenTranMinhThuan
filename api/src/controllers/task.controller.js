const mongoose = require('mongoose');
const Task = require('../models/task.model');
const TaskShare = require('../models/taskShare.model');
const Notification = require('../models/notification.model');
const EmailLog = require('../models/emailLog.model');
const { getTaskAccess } = require('../utils/taskPermissions');
const taskEventService = require('../services/taskEvent.service');
const {
  EVENT_TYPES,
  hasDueDateChanged,
  isTransitionToCompleted,
} = require('../utils/notificationEvents');

async function getSharedTaskIds(userId) {
  const shares = await TaskShare.find({ userId }).select('taskId');
  return shares.map((share) => share.taskId);
}

// Lấy bản ghi chia sẻ (nếu có) của một người trên một công việc
async function findUserShare(taskId, userId) {
  return TaskShare.findOne({ taskId, userId });
}

// Hạn hoàn thành phải sau ngày bắt đầu (so sánh cả giờ/phút).
// Bỏ qua khi thiếu một trong hai mốc hoặc chuỗi ngày không hợp lệ,
// vì trường hợp đó Mongoose sẽ báo lỗi cast riêng.
function isInvalidDateRange(startDate, dueDate) {
  if (!startDate || !dueDate) return false;

  const start = new Date(startDate).getTime();
  const due = new Date(dueDate).getTime();
  if (Number.isNaN(start) || Number.isNaN(due)) return false;

  return due <= start;
}

// 1. Tạo công việc mới
exports.createTask = async (req, res) => {
  try {
    const { title, description, category, priority, status, startDate, dueDate } = req.body;

    if (!title || !title.trim()) {
      return res.status(400).json({ message: 'Tiêu đề công việc không được để trống' });
    }

    if (isInvalidDateRange(startDate, dueDate)) {
      return res.status(400).json({ message: 'Hạn hoàn thành phải sau ngày bắt đầu' });
    }

    const newTask = await Task.create({
      title: title.trim(),
      description: description || '',
      category: category || 'Other',
      priority: priority || 'Medium',
      status: status || 'Pending',
      startDate: startDate || null,
      dueDate: dueDate || null,
      createdBy: req.user._id,
      assigneeIds: [],
    });

    const populated = await newTask.populate('createdBy', 'fullName email');

    return res.status(201).json({
      message: 'Tạo công việc thành công',
      task: populated,
    });
  } catch (error) {
    console.error('Lỗi tạo công việc:', error);
    return res.status(500).json({ message: 'Lỗi server khi tạo công việc' });
  }
};

// 2. Lấy danh sách công việc (scope, lọc status/priority/assigneeId/createdBy/dueFilter, tìm kiếm q, sắp xếp)
exports.getTasks = async (req, res) => {
  try {
    const {
      scope,
      status,
      priority,
      category,
      q,
      sortBy,
      order,
      assigneeId,
      createdBy,
      dueFilter,
    } = req.query;
    const userId = req.user._id;
    const sharedTaskIds = await getSharedTaskIds(userId);
    const conditions = [];

    // Phân loại phạm vi: created | assigned | shared | mặc định (cả ba)
    if (scope === 'created') {
      conditions.push({ createdBy: userId });
    } else if (scope === 'assigned') {
      conditions.push({ assigneeIds: userId });
    } else if (scope === 'shared') {
      conditions.push({ _id: { $in: sharedTaskIds } });
    } else {
      conditions.push({
        $or: [
          { createdBy: userId },
          { assigneeIds: userId },
          { _id: { $in: sharedTaskIds } },
        ],
      });
    }

    if (status) {
      conditions.push({ status });
    }
    if (priority) {
      conditions.push({ priority });
    }
    if (category) {
      conditions.push({ category });
    }

    if (assigneeId) {
      if (!mongoose.Types.ObjectId.isValid(assigneeId)) {
        return res.status(400).json({ message: 'assigneeId không hợp lệ' });
      }
      const assigneeObjectId = new mongoose.Types.ObjectId(assigneeId);
      conditions.push({
        $or: [{ assigneeIds: assigneeObjectId }, { primaryAssigneeId: assigneeObjectId }],
      });
    }

    // Lọc theo người tạo công việc (dùng cho dropdown Người tạo ở Flutter)
    if (createdBy) {
      if (!mongoose.Types.ObjectId.isValid(createdBy)) {
        return res.status(400).json({ message: 'createdBy không hợp lệ' });
      }
      conditions.push({ createdBy: new mongoose.Types.ObjectId(createdBy) });
    }

    // Lọc theo hạn hoàn thành: overdue | today | next7 | next30
    if (dueFilter && dueFilter !== 'all') {
      const now = new Date();
      const startOfToday = new Date(now.getFullYear(), now.getMonth(), now.getDate());
      const addDays = (days) => {
        const d = new Date(startOfToday);
        d.setDate(d.getDate() + days);
        return d;
      };

      if (dueFilter === 'overdue') {
        // Quá hạn = có hạn, hạn đã qua và chưa hoàn thành
        conditions.push({ dueDate: { $ne: null, $lt: now } });
        conditions.push({ status: { $ne: 'Completed' } });
      } else if (dueFilter === 'today') {
        conditions.push({ dueDate: { $gte: startOfToday, $lt: addDays(1) } });
      } else if (dueFilter === 'next7') {
        conditions.push({ dueDate: { $gte: startOfToday, $lt: addDays(8) } });
      } else if (dueFilter === 'next30') {
        conditions.push({ dueDate: { $gte: startOfToday, $lt: addDays(31) } });
      } else {
        return res.status(400).json({ message: 'dueFilter không hợp lệ' });
      }
    }

    if (q && q.trim()) {
      const searchRegex = new RegExp(q.trim(), 'i');
      conditions.push({
        $or: [{ title: searchRegex }, { description: searchRegex }],
      });
    }

    const filter = conditions.length === 1 ? conditions[0] : { $and: conditions };

    // Xác định thứ tự sắp xếp
    const sortField = sortBy || 'createdAt';
    const sortOrder = order === 'asc' ? 1 : -1;

    let tasks = await Task.find(filter)
      .populate('createdBy', 'fullName email')
      .populate('assigneeIds', 'fullName email')
      .populate('primaryAssigneeId', 'fullName email')
      .sort({ [sortField]: sortOrder });

    // Xử lý sắp xếp theo mức độ ưu tiên hợp lý (High > Medium > Low)
    if (sortBy === 'priority') {
      const priorityWeights = { High: 3, Medium: 2, Low: 1 };
      tasks.sort((a, b) => {
        const weightA = priorityWeights[a.priority] || 0;
        const weightB = priorityWeights[b.priority] || 0;
        return order === 'asc' ? weightA - weightB : weightB - weightA;
      });
    }

    return res.status(200).json(tasks);
  } catch (error) {
    console.error('Lỗi lấy danh sách công việc:', error);
    return res.status(500).json({ message: 'Lỗi server khi lấy danh sách công việc' });
  }
};

// 3. Lấy chi tiết một công việc
exports.getTaskById = async (req, res) => {
  try {
    const task = await Task.findById(req.params.id)
      .populate('createdBy', 'fullName email avatarUrl')
      .populate('assigneeIds', 'fullName email avatarUrl')
      .populate('primaryAssigneeId', 'fullName email avatarUrl');

    if (!task) {
      return res.status(404).json({ message: 'Không tìm thấy công việc' });
    }

    const share = await findUserShare(task._id, req.user._id);
    const access = getTaskAccess(task, req.user._id, share);

    if (!access.canView) {
      return res.status(403).json({ message: 'Bạn không có quyền truy cập công việc này' });
    }

    const shares = await TaskShare.find({ taskId: task._id })
      .populate('userId', 'fullName email avatarUrl')
      .populate('sharedBy', 'fullName email');

    return res.status(200).json({
      ...task.toObject(),
      shares,
      myPermission: access.role,
    });
  } catch (error) {
    console.error('Lỗi lấy chi tiết công việc:', error);
    return res.status(500).json({ message: 'Lỗi server khi lấy chi tiết công việc' });
  }
};

// 4. Cập nhật công việc
exports.updateTask = async (req, res) => {
  try {
    const task = await Task.findById(req.params.id);

    if (!task) {
      return res.status(404).json({ message: 'Không tìm thấy công việc' });
    }

    // Người tạo, phụ trách chính hoặc editor được sửa
    const share = await findUserShare(task._id, req.user._id);
    const access = getTaskAccess(task, req.user._id, share);

    if (!access.canEdit) {
      return res.status(403).json({ message: 'Bạn không có quyền chỉnh sửa công việc này' });
    }

    const { title, description, category, priority, status, startDate, dueDate } = req.body;

    // So sánh trên giá trị hiệu lực: nếu client chỉ đổi một mốc thì lấy mốc còn lại từ task.
    const nextStartDate = startDate !== undefined ? startDate : task.startDate;
    const nextDueDate = dueDate !== undefined ? dueDate : task.dueDate;
    if (isInvalidDateRange(nextStartDate, nextDueDate)) {
      return res.status(400).json({ message: 'Hạn hoàn thành phải sau ngày bắt đầu' });
    }

    // Lưu giá trị cũ để biết có phát sinh sự kiện đổi hạn / hoàn thành không.
    const oldDueDate = task.dueDate;
    const oldStatus = task.status;

    if (title !== undefined) task.title = title.trim();
    if (description !== undefined) task.description = description;
    if (category !== undefined) task.category = category;
    if (priority !== undefined) task.priority = priority;
    if (status !== undefined) task.status = status;
    if (startDate !== undefined) task.startDate = startDate;
    if (dueDate !== undefined) task.dueDate = dueDate;

    await task.save();

    // Mỗi sự kiện trong try/catch riêng: lỗi email không chặn sự kiện còn lại
    // và không làm hỏng response cập nhật công việc.
    if (hasDueDateChanged(oldDueDate, task.dueDate)) {
      try {
        await taskEventService.emitTaskEvent({
          task,
          actorId: req.user._id,
          actorName: req.user.fullName,
          eventType: EVENT_TYPES.DUE_DATE_CHANGED,
        });
      } catch (error) {
        console.error('Lỗi gửi thông báo đổi hạn:', error);
      }
    }

    if (isTransitionToCompleted(oldStatus, task.status)) {
      try {
        await taskEventService.emitTaskEvent({
          task,
          actorId: req.user._id,
          actorName: req.user.fullName,
          eventType: EVENT_TYPES.TASK_COMPLETED,
        });
      } catch (error) {
        console.error('Lỗi gửi thông báo hoàn thành:', error);
      }
    }

    const populated = await task.populate('createdBy', 'fullName email');

    return res.status(200).json({
      message: 'Cập nhật công việc thành công',
      task: populated,
    });
  } catch (error) {
    console.error('Lỗi cập nhật công việc:', error);
    return res.status(500).json({ message: 'Lỗi server khi cập nhật công việc' });
  }
};

// 5. Cập nhật nhanh trạng thái
exports.updateTaskStatus = async (req, res) => {
  try {
    const task = await Task.findById(req.params.id);

    if (!task) {
      return res.status(404).json({ message: 'Không tìm thấy công việc' });
    }

    // Người tạo, phụ trách chính, editor hoặc người được giao được đổi trạng thái
    const share = await findUserShare(task._id, req.user._id);
    const access = getTaskAccess(task, req.user._id, share);

    if (!access.canChangeStatus) {
      return res.status(403).json({ message: 'Bạn không có quyền thay đổi trạng thái công việc này' });
    }

    const { status } = req.body;
    if (!status || !['Pending', 'InProgress', 'Completed'].includes(status)) {
      return res.status(400).json({ message: 'Trạng thái không hợp lệ' });
    }

    const oldStatus = task.status;
    task.status = status;
    await task.save();

    // Phát sự kiện hoàn thành giống endpoint PUT, để nút "Hoàn thành"
    // ở màn chi tiết và màn danh sách đều gửi thông báo/email.
    // Chỉ phát khi thực sự chuyển sang Completed, không phát khi bấm lặp.
    if (isTransitionToCompleted(oldStatus, task.status)) {
      try {
        await taskEventService.emitTaskEvent({
          task,
          actorId: req.user._id,
          actorName: req.user.fullName,
          eventType: EVENT_TYPES.TASK_COMPLETED,
        });
      } catch (error) {
        console.error('Lỗi gửi thông báo hoàn thành:', error);
      }
    }

    const populated = await task.populate('createdBy', 'fullName email');

    return res.status(200).json({
      message: 'Cập nhật trạng thái thành công',
      task: populated,
    });
  } catch (error) {
    console.error('Lỗi cập nhật trạng thái:', error);
    return res.status(500).json({ message: 'Lỗi server khi cập nhật trạng thái' });
  }
};

// 6. Xóa công việc
exports.deleteTask = async (req, res) => {
  try {
    const task = await Task.findById(req.params.id);

    if (!task) {
      return res.status(404).json({ message: 'Không tìm thấy công việc' });
    }

    const share = await findUserShare(task._id, req.user._id);
    const access = getTaskAccess(task, req.user._id, share);

    if (!access.canDelete) {
      return res.status(403).json({ message: 'Bạn không có quyền xóa công việc này' });
    }

    await Task.findByIdAndDelete(req.params.id);
    // Dọn toàn bộ dữ liệu liên quan của công việc vừa xóa để tránh bản ghi mồ côi.
    // Notification còn sót sẽ dẫn tới màn chi tiết 404 khi người dùng bấm vào.
    await Promise.all([
      TaskShare.deleteMany({ taskId: task._id }),
      Notification.deleteMany({ taskId: task._id }),
      EmailLog.deleteMany({ taskId: task._id }),
    ]);

    return res.status(200).json({ message: 'Xóa công việc thành công' });
  } catch (error) {
    console.error('Lỗi xóa công việc:', error);
    return res.status(500).json({ message: 'Lỗi server khi xóa công việc' });
  }
};
