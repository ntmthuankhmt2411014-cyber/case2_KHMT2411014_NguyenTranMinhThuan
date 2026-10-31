const Task = require('../models/task.model');

// 1. Tạo công việc mới
exports.createTask = async (req, res) => {
  try {
    const { title, description, category, priority, status, startDate, dueDate } = req.body;

    if (!title || !title.trim()) {
      return res.status(400).json({ message: 'Tiêu đề công việc không được để trống' });
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

// 2. Lấy danh sách công việc (có phân loại scope, lọc status/priority/category, tìm kiếm q, sắp xếp)
exports.getTasks = async (req, res) => {
  try {
    const { scope, status, priority, category, q, sortBy, order } = req.query;

    let filter = {};

    // Phân loại phạm vi công việc
    if (scope === 'created') {
      filter.createdBy = req.user._id;
    } else if (scope === 'assigned') {
      filter.assigneeIds = req.user._id;
    } else {
      // Mặc định: Việc tôi tạo HOẶC việc tôi được giao
      filter.$or = [
        { createdBy: req.user._id },
        { assigneeIds: req.user._id },
      ];
    }

    // Lọc theo trạng thái
    if (status) {
      filter.status = status;
    }

    // Lọc theo mức độ ưu tiên
    if (priority) {
      filter.priority = priority;
    }

    // Lọc theo danh mục
    if (category) {
      filter.category = category;
    }

    // Tìm kiếm theo tên hoặc mô tả
    if (q && q.trim()) {
      const searchRegex = new RegExp(q.trim(), 'i');
      if (filter.$or) {
        // Kết hợp điều kiện người dùng với tìm kiếm
        filter = {
          $and: [
            { $or: filter.$or },
            { $or: [{ title: searchRegex }, { description: searchRegex }] },
          ],
        };
      } else {
        filter.$or = [{ title: searchRegex }, { description: searchRegex }];
      }
    }

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
      .populate('createdBy', 'fullName email')
      .populate('assigneeIds', 'fullName email')
      .populate('primaryAssigneeId', 'fullName email');

    if (!task) {
      return res.status(404).json({ message: 'Không tìm thấy công việc' });
    }

    return res.status(200).json(task);
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

    // Chỉ người tạo mới có quyền sửa
    if (task.createdBy.toString() !== req.user._id.toString()) {
      return res.status(403).json({ message: 'Bạn không có quyền chỉnh sửa công việc này' });
    }

    const { title, description, category, priority, status, startDate, dueDate } = req.body;

    if (title !== undefined) task.title = title.trim();
    if (description !== undefined) task.description = description;
    if (category !== undefined) task.category = category;
    if (priority !== undefined) task.priority = priority;
    if (status !== undefined) task.status = status;
    if (startDate !== undefined) task.startDate = startDate;
    if (dueDate !== undefined) task.dueDate = dueDate;

    await task.save();
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

    // Người tạo hoặc người được giao có thể cập nhật trạng thái
    const isOwner = task.createdBy.toString() === req.user._id.toString();
    const isAssignee = task.assigneeIds && task.assigneeIds.some(id => id.toString() === req.user._id.toString());

    if (!isOwner && !isAssignee) {
      return res.status(403).json({ message: 'Bạn không có quyền thay đổi trạng thái công việc này' });
    }

    const { status } = req.body;
    if (!status || !['Pending', 'InProgress', 'Completed'].includes(status)) {
      return res.status(400).json({ message: 'Trạng thái không hợp lệ' });
    }

    task.status = status;
    await task.save();
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

    if (task.createdBy.toString() !== req.user._id.toString()) {
      return res.status(403).json({ message: 'Bạn không có quyền xóa công việc này' });
    }

    await Task.findByIdAndDelete(req.params.id);

    return res.status(200).json({ message: 'Xóa công việc thành công' });
  } catch (error) {
    console.error('Lỗi xóa công việc:', error);
    return res.status(500).json({ message: 'Lỗi server khi xóa công việc' });
  }
};
