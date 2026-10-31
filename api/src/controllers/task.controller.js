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

// 2. Lấy danh sách công việc (có lọc, tìm kiếm, sắp xếp)
exports.getTasks = async (req, res) => {
  try {
    const { status, priority, category, q, sortBy, order } = req.query;

    const filter = { createdBy: req.user._id };

    if (status) filter.status = status;
    if (priority) filter.priority = priority;
    if (category) filter.category = category;

    // Tìm kiếm theo tiêu đề hoặc mô tả
    if (q && q.trim()) {
      const regex = new RegExp(q.trim(), 'i');
      filter.$or = [{ title: regex }, { description: regex }];
    }

    // Sắp xếp: mặc định theo ngày tạo mới nhất
    const sortField = sortBy || 'createdAt';
    const sortOrder = order === 'asc' ? 1 : -1;

    const tasks = await Task.find(filter)
      .populate('createdBy', 'fullName email')
      .sort({ [sortField]: sortOrder });

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
      .populate('createdBy', 'fullName email');

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

    if (task.createdBy.toString() !== req.user._id.toString()) {
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
