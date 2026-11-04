import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/task.dart';
import '../../services/task_api_service.dart';

// Màn hình chỉnh sửa công việc.
// Nhận Task đã có dữ liệu để điền sẵn vào form, sau đó gọi PUT /tasks/:id.
class TaskEditScreen extends StatefulWidget {
  final Task task;

  const TaskEditScreen({super.key, required this.task});

  @override
  State<TaskEditScreen> createState() => _TaskEditScreenState();
}

class _TaskEditScreenState extends State<TaskEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final _apiService = TaskApiService();

  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _categoryController;

  late String _priority;
  late String _status;
  DateTime? _startDate;
  DateTime? _dueDate;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();

    final task = widget.task;
    _titleController = TextEditingController(text: task.title);
    _descriptionController = TextEditingController(text: task.description);
    _categoryController = TextEditingController(text: task.category);
    _priority = task.priority;
    _status = task.status;

    // API trả ngày dạng chuỗi ISO (ví dụ 2026-11-04T00:00:00.000Z).
    _startDate = _parseDate(task.startDate);
    _dueDate = _parseDate(task.dueDate);
  }

  DateTime? _parseDate(String? value) {
    if (value == null || value.isEmpty) return null;
    return DateTime.tryParse(value);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _categoryController.dispose();
    super.dispose();
  }

  Future<void> _pickDate({required bool isStart}) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: isStart ? (_startDate ?? now) : (_dueDate ?? now),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startDate = picked;
        } else {
          _dueDate = picked;
        }
      });
    }
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'Chưa chọn';
    return DateFormat('dd/MM/yyyy').format(date);
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    // Kiểm tra nhanh ở client; backend vẫn là nơi kiểm tra cuối cùng.
    if (_startDate != null && _dueDate != null && _dueDate!.isBefore(_startDate!)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Hạn hoàn thành không được trước ngày bắt đầu'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    final result = await _apiService.updateTask(widget.task.id, {
      'title': _titleController.text.trim(),
      'description': _descriptionController.text.trim(),
      'category': _categoryController.text.trim().isEmpty
          ? 'Other'
          : _categoryController.text.trim(),
      'priority': _priority,
      'status': _status,
      // Gửi null để xóa ngày nếu người dùng bấm nút xóa.
      'startDate': _startDate?.toIso8601String(),
      'dueDate': _dueDate?.toIso8601String(),
    });

    setState(() => _isLoading = false);

    if (!mounted) return;

    if (result['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message'] ?? 'Cập nhật công việc thành công'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context, true); // trả về true để màn chi tiết tải lại
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message'] ?? 'Cập nhật công việc thất bại'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chỉnh sửa công việc'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Tiêu đề
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Tiêu đề công việc *',
                  prefixIcon: Icon(Icons.title),
                  border: OutlineInputBorder(),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Vui lòng nhập tiêu đề công việc';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Mô tả
              TextFormField(
                controller: _descriptionController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Mô tả',
                  prefixIcon: Icon(Icons.description_outlined),
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 16),

              // Danh mục
              TextFormField(
                controller: _categoryController,
                decoration: const InputDecoration(
                  labelText: 'Danh mục',
                  hintText: 'VD: Công việc, Học tập, Cá nhân...',
                  prefixIcon: Icon(Icons.category_outlined),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),

              // Mức độ ưu tiên
              DropdownButtonFormField<String>(
                initialValue: _priority,
                decoration: const InputDecoration(
                  labelText: 'Mức độ ưu tiên',
                  prefixIcon: Icon(Icons.flag_outlined),
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'Low', child: Text('🟢 Thấp')),
                  DropdownMenuItem(value: 'Medium', child: Text('🟠 Trung bình')),
                  DropdownMenuItem(value: 'High', child: Text('🔴 Cao')),
                ],
                onChanged: (val) {
                  if (val != null) setState(() => _priority = val);
                },
              ),
              const SizedBox(height: 16),

              // Trạng thái
              DropdownButtonFormField<String>(
                initialValue: _status,
                decoration: const InputDecoration(
                  labelText: 'Trạng thái',
                  prefixIcon: Icon(Icons.info_outline),
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'Pending', child: Text('⏳ Chờ xử lý')),
                  DropdownMenuItem(value: 'InProgress', child: Text('🔄 Đang thực hiện')),
                  DropdownMenuItem(value: 'Completed', child: Text('✅ Hoàn thành')),
                ],
                onChanged: (val) {
                  if (val != null) setState(() => _status = val);
                },
              ),
              const SizedBox(height: 16),

              // Ngày bắt đầu
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.calendar_today, color: Colors.blue),
                title: const Text('Ngày bắt đầu'),
                subtitle: Text(_formatDate(_startDate)),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_startDate != null)
                      IconButton(
                        icon: const Icon(Icons.clear, size: 20),
                        onPressed: () => setState(() => _startDate = null),
                      ),
                    IconButton(
                      icon: const Icon(Icons.edit_calendar),
                      onPressed: () => _pickDate(isStart: true),
                    ),
                  ],
                ),
              ),

              // Hạn hoàn thành
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.event, color: Colors.orange),
                title: const Text('Hạn hoàn thành'),
                subtitle: Text(_formatDate(_dueDate)),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_dueDate != null)
                      IconButton(
                        icon: const Icon(Icons.clear, size: 20),
                        onPressed: () => setState(() => _dueDate = null),
                      ),
                    IconButton(
                      icon: const Icon(Icons.edit_calendar),
                      onPressed: () => _pickDate(isStart: false),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Nút lưu
              SizedBox(
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : _handleSave,
                  icon: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.save),
                  label: Text(
                    _isLoading ? 'Đang lưu...' : 'Lưu thay đổi',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
