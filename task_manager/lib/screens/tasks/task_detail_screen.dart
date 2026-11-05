import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/task.dart';
import '../../services/auth_service.dart';
import '../../services/task_api_service.dart';
import '../../widgets/delete_task_dialog.dart';
import 'task_edit_screen.dart';

class TaskDetailScreen extends StatefulWidget {
  final String taskId;

  const TaskDetailScreen({super.key, required this.taskId});

  @override
  State<TaskDetailScreen> createState() => _TaskDetailScreenState();
}

class _TaskDetailScreenState extends State<TaskDetailScreen> {
  final TaskApiService _apiService = TaskApiService();
  final AuthService _authService = AuthService();

  Task? _task;
  bool _isLoading = true;
  bool _isDeleting = false;
  String? _error;
  String? _currentUserId;

  // Chỉ người tạo mới thấy nút chỉnh sửa/xóa.
  // Backend vẫn kiểm tra lại quyền, UI chỉ hỗ trợ trải nghiệm.
  bool get _isCreator {
    final task = _task;
    return task != null &&
        _currentUserId != null &&
        task.createdBy == _currentUserId;
  }

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
    _fetchTask();
  }

  Future<void> _loadCurrentUser() async {
    final user = await _authService.getCurrentUser();
    if (!mounted) return;
    setState(() => _currentUserId = user?.id);
  }

  Future<void> _openEdit() async {
    final task = _task;
    if (task == null) return;

    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (context) => TaskEditScreen(task: task)),
    );

    if (changed == true) {
      _fetchTask();
    }
  }

  // Xác nhận rồi xóa công việc. Chỉ người tạo thấy nút, backend kiểm tra lại quyền.
  Future<void> _confirmDelete() async {
    final task = _task;
    if (task == null || _isDeleting) return;

    final confirmed = await showDeleteTaskDialog(context, task.title);
    if (!confirmed || !mounted) return;

    setState(() => _isDeleting = true);
    final result = await _apiService.deleteTask(task.id);
    if (!mounted) return;
    setState(() => _isDeleting = false);

    if (result['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message'] ?? 'Xóa công việc thành công'),
          backgroundColor: Colors.green,
        ),
      );
      // Trả true để màn danh sách biết vừa xóa và tải lại.
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message'] ?? 'Xóa công việc thất bại'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _fetchTask() async {    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final task = await _apiService.getTaskById(widget.taskId);
      setState(() {
        _task = task;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Color _priorityColor(String priority) {
    switch (priority) {
      case 'High':
        return Colors.red;
      case 'Low':
        return Colors.green;
      default:
        return Colors.orange;
    }
  }

  String _priorityLabel(String priority) {
    switch (priority) {
      case 'High':
        return 'Ưu tiên Cao';
      case 'Low':
        return 'Ưu tiên Thấp';
      default:
        return 'Ưu tiên Trung bình';
    }
  }

  IconData _statusIcon(String status) {
    switch (status) {
      case 'Completed':
        return Icons.check_circle;
      case 'InProgress':
        return Icons.timelapse;
      default:
        return Icons.radio_button_unchecked;
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'Completed':
        return Colors.green;
      case 'InProgress':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'Completed':
        return 'Đã hoàn thành';
      case 'InProgress':
        return 'Đang thực hiện';
      default:
        return 'Chờ xử lý';
    }
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return 'Chưa thiết lập';
    try {
      final date = DateTime.parse(dateStr);
      return DateFormat('dd/MM/yyyy').format(date);
    } catch (_) {
      return dateStr;
    }
  }

  Future<void> _updateStatus(String newStatus) async {
    if (_task == null) return;

    final result = await _apiService.updateTaskStatus(_task!.id, newStatus);
    if (!mounted) return;

    if (result['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Đã cập nhật trạng thái: ${_statusLabel(newStatus)}'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 1),
        ),
      );
      _fetchTask();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message'] ?? 'Cập nhật thất bại'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chi tiết công việc'),
        actions: [
          if (_isCreator) ...[
            IconButton(
              icon: const Icon(Icons.edit),
              tooltip: 'Chỉnh sửa công việc',
              onPressed: _openEdit,
            ),
            IconButton(
              icon: _isDeleting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.delete_outline, color: Colors.red),
              tooltip: 'Xóa công việc',
              onPressed: _isDeleting ? null : _confirmDelete,
            ),
          ],
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Tải lại',
            onPressed: _fetchTask,
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 12),
              Text(
                'Không thể tải chi tiết công việc.\n$_error',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: _fetchTask,
                child: const Text('Thử lại'),
              ),
            ],
          ),
        ),
      );
    }

    if (_task == null) {
      return const Center(child: Text('Không tìm thấy công việc'));
    }

    final task = _task!;
    final bool isOverdue = task.dueDate != null &&
        DateTime.tryParse(task.dueDate!)?.isBefore(DateTime.now()) == true &&
        task.status != 'Completed';

    return RefreshIndicator(
      onRefresh: _fetchTask,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Card 1: Tiêu đề & Các Badge
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.title,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        // Trạng thái badge
                        Chip(
                          avatar: Icon(_statusIcon(task.status), size: 16, color: _statusColor(task.status)),
                          label: Text(
                            _statusLabel(task.status),
                            style: TextStyle(color: _statusColor(task.status), fontWeight: FontWeight.bold, fontSize: 12),
                          ),
                          backgroundColor: _statusColor(task.status).withValues(alpha: 0.15),
                          side: BorderSide.none,
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        // Ưu tiên badge
                        Chip(
                          avatar: const Icon(Icons.flag, size: 16, color: Colors.white),
                          label: Text(
                            _priorityLabel(task.priority),
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                          ),
                          backgroundColor: _priorityColor(task.priority),
                          side: BorderSide.none,
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        // Danh mục badge
                        if (task.category.isNotEmpty)
                          Chip(
                            avatar: const Icon(Icons.category, size: 16, color: Colors.purple),
                            label: Text(
                              task.category,
                              style: const TextStyle(color: Colors.purple, fontSize: 12),
                            ),
                            backgroundColor: Colors.purple.withValues(alpha: 0.1),
                            side: BorderSide.none,
                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),

            // Card 2: Cập nhật nhanh trạng thái
            Card(
              elevation: 1,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Cập nhật trạng thái công việc',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              backgroundColor: task.status == 'Pending' ? Colors.grey.shade200 : null,
                              side: BorderSide(color: task.status == 'Pending' ? Colors.black87 : Colors.grey.shade300),
                            ),
                            onPressed: () => _updateStatus('Pending'),
                            child: const Text('Chờ xử lý', style: TextStyle(fontSize: 12)),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              backgroundColor: task.status == 'InProgress' ? Colors.blue.shade50 : null,
                              side: BorderSide(color: task.status == 'InProgress' ? Colors.blue : Colors.grey.shade300),
                            ),
                            onPressed: () => _updateStatus('InProgress'),
                            child: const Text('Đang làm', style: TextStyle(fontSize: 12)),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              backgroundColor: task.status == 'Completed' ? Colors.green.shade50 : null,
                              side: BorderSide(color: task.status == 'Completed' ? Colors.green : Colors.grey.shade300),
                            ),
                            onPressed: () => _updateStatus('Completed'),
                            child: const Text('Hoàn thành', style: TextStyle(fontSize: 12)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),

            // Card 3: Mô tả công việc
            Card(
              elevation: 1,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.description_outlined, size: 20, color: Colors.blue),
                        SizedBox(width: 8),
                        Text(
                          'Mô tả chi tiết',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                      ],
                    ),
                    const Divider(height: 20),
                    Text(
                      task.description.isNotEmpty ? task.description : 'Không có mô tả chi tiết.',
                      style: TextStyle(
                        fontSize: 14,
                        color: task.description.isNotEmpty ? Colors.black87 : Colors.grey,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),

            // Card 4: Thời gian & Tiến độ
            Card(
              elevation: 1,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.access_time, size: 20, color: Colors.orange),
                        SizedBox(width: 8),
                        Text(
                          'Thời gian & Thời hạn',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                      ],
                    ),
                    const Divider(height: 20),
                    _buildInfoRow('Ngày bắt đầu:', _formatDate(task.startDate)),
                    const SizedBox(height: 8),
                    _buildInfoRow(
                      'Hạn hoàn thành:',
                      _formatDate(task.dueDate),
                      valueColor: isOverdue ? Colors.red : null,
                      badge: isOverdue
                          ? Container(
                              margin: const EdgeInsets.only(left: 8),
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(4)),
                              child: const Text('Quá hạn', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                            )
                          : null,
                    ),
                    const SizedBox(height: 8),
                    _buildInfoRow('Ngày tạo:', _formatDate(task.createdAt)),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),

            // Card 5: Người liên quan
            Card(
              elevation: 1,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.people_outline, size: 20, color: Colors.teal),
                        SizedBox(width: 8),
                        Text(
                          'Người liên quan',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                      ],
                    ),
                    const Divider(height: 20),

                    // Người tạo
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        backgroundColor: Colors.blue.shade100,
                        child: Text(
                          (task.createdByName != null && task.createdByName!.isNotEmpty)
                              ? task.createdByName![0].toUpperCase()
                              : 'U',
                          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue),
                        ),
                      ),
                      title: Text(task.createdByName ?? 'Không rõ'),
                      subtitle: Text(task.createdByEmail ?? 'Người tạo'),
                      trailing: const Chip(
                        label: Text('Người tạo', style: TextStyle(fontSize: 10)),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),

                    // Người phụ trách chính (nếu có)
                    if (task.primaryAssigneeName != null && task.primaryAssigneeName!.isNotEmpty) ...[
                      const Divider(height: 12),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(
                          backgroundColor: Colors.amber.shade100,
                          child: const Icon(Icons.star, color: Colors.orange, size: 20),
                        ),
                        title: Text(task.primaryAssigneeName!),
                        subtitle: const Text('Người phụ trách chính'),
                      ),
                    ],

                    // Danh sách người được giao
                    if (task.assignees.isNotEmpty) ...[
                      const Divider(height: 12),
                      const Text(
                        'Người được giao:',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.grey),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: task.assignees.map((assignee) {
                          return Chip(
                            avatar: CircleAvatar(
                              backgroundColor: Colors.teal.shade100,
                              child: Text(
                                assignee.fullName.isNotEmpty ? assignee.fullName[0].toUpperCase() : 'A',
                                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                              ),
                            ),
                            label: Text(assignee.fullName, style: const TextStyle(fontSize: 12)),
                          );
                        }).toList(),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {Color? valueColor, Widget? badge}) {
    return Row(
      children: [
        SizedBox(
          width: 130,
          child: Text(
            label,
            style: const TextStyle(color: Colors.grey, fontSize: 13),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 13,
            color: valueColor ?? Colors.black87,
          ),
        ),
        if (badge != null) badge,
      ],
    );
  }
}
