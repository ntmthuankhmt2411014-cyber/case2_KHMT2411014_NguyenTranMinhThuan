import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/task.dart';
import '../services/task_api_service.dart';
import 'profile/profile_screen.dart';
import 'tasks/task_create_screen.dart';

class TaskListScreen extends StatefulWidget {
  const TaskListScreen({super.key});

  @override
  State<TaskListScreen> createState() => _TaskListScreenState();
}

class _TaskListScreenState extends State<TaskListScreen> {
  final TaskApiService _apiService = TaskApiService();

  List<Task> _tasks = [];
  bool _isLoading = true;
  String? _error;

  // Bộ lọc hiện tại
  String? _filterStatus;
  String? _filterPriority;
  String _searchQuery = '';
  String _sortBy = 'createdAt';
  String _sortOrder = 'desc';

  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadTasks();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadTasks() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final tasks = await _apiService.getTasks(
        status: _filterStatus,
        priority: _filterPriority,
        q: _searchQuery.isNotEmpty ? _searchQuery : null,
        sortBy: _sortBy,
        order: _sortOrder,
      );
      setState(() {
        _tasks = tasks;
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
        return 'Cao';
      case 'Low':
        return 'Thấp';
      default:
        return 'TB';
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
        return 'Hoàn thành';
      case 'InProgress':
        return 'Đang làm';
      default:
        return 'Chờ xử lý';
    }
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return '';
    try {
      final date = DateTime.parse(dateStr);
      return DateFormat('dd/MM/yyyy').format(date);
    } catch (_) {
      return '';
    }
  }

  // Chuyển trạng thái nhanh
  Future<void> _quickUpdateStatus(Task task) async {
    String nextStatus;
    switch (task.status) {
      case 'Pending':
        nextStatus = 'InProgress';
        break;
      case 'InProgress':
        nextStatus = 'Completed';
        break;
      default:
        nextStatus = 'Pending';
    }

    final result = await _apiService.updateTaskStatus(task.id, nextStatus);
    if (!mounted) return;

    if (result['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Đã chuyển sang: ${_statusLabel(nextStatus)}'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 1),
        ),
      );
      _loadTasks();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message'] ?? 'Cập nhật thất bại'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Xóa công việc
  Future<void> _deleteTask(Task task) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xác nhận xóa'),
        content: Text('Bạn có chắc chắn muốn xóa công việc "${task.title}" không?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Hủy')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final result = await _apiService.deleteTask(task.id);
    if (!mounted) return;

    if (result['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã xóa công việc'), backgroundColor: Colors.green),
      );
      _loadTasks();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result['message'] ?? 'Xóa thất bại'), backgroundColor: Colors.red),
      );
    }
  }

  void _showSortDialog() {
    showDialog(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Sắp xếp theo'),
        children: [
          SimpleDialogOption(
            onPressed: () {
              setState(() { _sortBy = 'createdAt'; _sortOrder = 'desc'; });
              Navigator.pop(ctx);
              _loadTasks();
            },
            child: Text('Mới nhất', style: TextStyle(fontWeight: _sortBy == 'createdAt' && _sortOrder == 'desc' ? FontWeight.bold : FontWeight.normal)),
          ),
          SimpleDialogOption(
            onPressed: () {
              setState(() { _sortBy = 'createdAt'; _sortOrder = 'asc'; });
              Navigator.pop(ctx);
              _loadTasks();
            },
            child: Text('Cũ nhất', style: TextStyle(fontWeight: _sortBy == 'createdAt' && _sortOrder == 'asc' ? FontWeight.bold : FontWeight.normal)),
          ),
          SimpleDialogOption(
            onPressed: () {
              setState(() { _sortBy = 'dueDate'; _sortOrder = 'asc'; });
              Navigator.pop(ctx);
              _loadTasks();
            },
            child: Text('Hạn gần nhất', style: TextStyle(fontWeight: _sortBy == 'dueDate' ? FontWeight.bold : FontWeight.normal)),
          ),
          SimpleDialogOption(
            onPressed: () {
              setState(() { _sortBy = 'priority'; _sortOrder = 'desc'; });
              Navigator.pop(ctx);
              _loadTasks();
            },
            child: Text('Ưu tiên cao nhất', style: TextStyle(fontWeight: _sortBy == 'priority' ? FontWeight.bold : FontWeight.normal)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Công việc của tôi'),
        actions: [
          IconButton(
            icon: const Icon(Icons.sort),
            tooltip: 'Sắp xếp',
            onPressed: _showSortDialog,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Tải lại',
            onPressed: _loadTasks,
          ),
          IconButton(
            icon: const Icon(Icons.person_outline),
            tooltip: 'Cá nhân & Tài khoản',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ProfileScreen()),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Thanh tìm kiếm
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Tìm kiếm công việc...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                          _loadTasks();
                        },
                      )
                    : null,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
              ),
              onSubmitted: (val) {
                setState(() => _searchQuery = val.trim());
                _loadTasks();
              },
            ),
          ),

          // Chip lọc trạng thái & ưu tiên
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Row(
              children: [
                // Lọc trạng thái
                _buildFilterChip('Tất cả', _filterStatus == null, () {
                  setState(() => _filterStatus = null);
                  _loadTasks();
                }),
                const SizedBox(width: 6),
                _buildFilterChip('Chờ xử lý', _filterStatus == 'Pending', () {
                  setState(() => _filterStatus = _filterStatus == 'Pending' ? null : 'Pending');
                  _loadTasks();
                }, color: Colors.grey),
                const SizedBox(width: 6),
                _buildFilterChip('Đang làm', _filterStatus == 'InProgress', () {
                  setState(() => _filterStatus = _filterStatus == 'InProgress' ? null : 'InProgress');
                  _loadTasks();
                }, color: Colors.blue),
                const SizedBox(width: 6),
                _buildFilterChip('Hoàn thành', _filterStatus == 'Completed', () {
                  setState(() => _filterStatus = _filterStatus == 'Completed' ? null : 'Completed');
                  _loadTasks();
                }, color: Colors.green),
                const SizedBox(width: 12),
                // Lọc ưu tiên
                Container(width: 1, height: 24, color: Colors.grey.shade300),
                const SizedBox(width: 12),
                _buildFilterChip('🔴 Cao', _filterPriority == 'High', () {
                  setState(() => _filterPriority = _filterPriority == 'High' ? null : 'High');
                  _loadTasks();
                }, color: Colors.red),
                const SizedBox(width: 6),
                _buildFilterChip('🟠 TB', _filterPriority == 'Medium', () {
                  setState(() => _filterPriority = _filterPriority == 'Medium' ? null : 'Medium');
                  _loadTasks();
                }, color: Colors.orange),
                const SizedBox(width: 6),
                _buildFilterChip('🟢 Thấp', _filterPriority == 'Low', () {
                  setState(() => _filterPriority = _filterPriority == 'Low' ? null : 'Low');
                  _loadTasks();
                }, color: Colors.green),
              ],
            ),
          ),

          const Divider(height: 1),

          // Danh sách công việc
          Expanded(child: _buildBody()),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const TaskCreateScreen()),
          );
          if (result == true) _loadTasks();
        },
        icon: const Icon(Icons.add),
        label: const Text('Thêm'),
      ),
    );
  }

  Widget _buildFilterChip(String label, bool selected, VoidCallback onTap, {Color? color}) {
    return GestureDetector(
      onTap: onTap,
      child: Chip(
        label: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : (color ?? Colors.black87),
            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
            fontSize: 12,
          ),
        ),
        backgroundColor: selected ? (color ?? Colors.blue) : Colors.grey.shade100,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.compact,
      ),
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
              Text('Không kết nối được server.\n$_error', textAlign: TextAlign.center),
              const SizedBox(height: 12),
              ElevatedButton(onPressed: _loadTasks, child: const Text('Thử lại')),
            ],
          ),
        ),
      );
    }

    if (_tasks.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.inbox_outlined, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            Text(
              _filterStatus != null || _filterPriority != null || _searchQuery.isNotEmpty
                  ? 'Không tìm thấy công việc phù hợp'
                  : 'Chưa có công việc nào.\nBấm + để tạo công việc mới!',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 15),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadTasks,
      child: ListView.builder(
        padding: const EdgeInsets.only(bottom: 80),
        itemCount: _tasks.length,
        itemBuilder: (context, index) {
          final task = _tasks[index];
          return _buildTaskCard(task);
        },
      ),
    );
  }

  Widget _buildTaskCard(Task task) {
    final dueDateStr = _formatDate(task.dueDate);
    final bool isOverdue = task.dueDate != null &&
        DateTime.tryParse(task.dueDate!)?.isBefore(DateTime.now()) == true &&
        task.status != 'Completed';

    return Dismissible(
      key: Key(task.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: Colors.red,
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      confirmDismiss: (direction) async {
        _deleteTask(task);
        return false; // Xóa qua dialog xác nhận, không dùng dismiss thật
      },
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        elevation: 1.5,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () {
            // Sẽ mở TaskDetailScreen ở bước sau
          },
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Icon trạng thái (bấm để chuyển nhanh)
                GestureDetector(
                  onTap: () => _quickUpdateStatus(task),
                  child: Padding(
                    padding: const EdgeInsets.only(top: 2, right: 10),
                    child: Icon(
                      _statusIcon(task.status),
                      color: _statusColor(task.status),
                      size: 28,
                    ),
                  ),
                ),

                // Nội dung
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        task.title,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          decoration: task.status == 'Completed' ? TextDecoration.lineThrough : null,
                          color: task.status == 'Completed' ? Colors.grey : null,
                        ),
                      ),
                      if (task.description.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          task.description,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                        ),
                      ],
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          // Badge trạng thái
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: _statusColor(task.status).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              _statusLabel(task.status),
                              style: TextStyle(fontSize: 11, color: _statusColor(task.status), fontWeight: FontWeight.w600),
                            ),
                          ),
                          const SizedBox(width: 6),
                          // Badge danh mục
                          if (task.category.isNotEmpty && task.category != 'Other')
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.purple.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                task.category,
                                style: const TextStyle(fontSize: 11, color: Colors.purple),
                              ),
                            ),
                          const Spacer(),
                          // Hạn hoàn thành
                          if (dueDateStr.isNotEmpty)
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.event,
                                  size: 14,
                                  color: isOverdue ? Colors.red : Colors.grey,
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  dueDateStr,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: isOverdue ? Colors.red : Colors.grey,
                                    fontWeight: isOverdue ? FontWeight.bold : FontWeight.normal,
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Badge ưu tiên
                Container(
                  margin: const EdgeInsets.only(left: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _priorityColor(task.priority).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _priorityLabel(task.priority),
                    style: TextStyle(
                      fontSize: 11,
                      color: _priorityColor(task.priority),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
