import 'dart:async';

import 'package:flutter/material.dart';

import '../models/task.dart';
import '../services/auth_service.dart';
import '../services/notification_service.dart';
import '../services/task_api_service.dart';
import '../utils/date_time.dart';
import 'notifications/notification_screen.dart';
import 'tasks/task_create_screen.dart';
import 'tasks/task_detail_screen.dart';

class TaskListScreen extends StatefulWidget {
  const TaskListScreen({super.key});

  @override
  State<TaskListScreen> createState() => TaskListScreenState();
}

class TaskListScreenState extends State<TaskListScreen> {
  final TaskApiService _apiService = TaskApiService();
  final AuthService _authService = AuthService();
  final NotificationService _notificationService = NotificationService();

  List<Task> _tasks = [];
  bool _isLoading = true;
  String? _error;

  // Số thông báo chưa đọc trên chuông AppBar và timer polling 30 giây.
  int _unreadCount = 0;
  Timer? _notificationTimer;

  // Bộ lọc hiện tại (null = "Tất cả")
  String? _filterScope; // created, assigned, shared
  String? _filterCreatorId;
  String? _filterStatus;
  String? _filterPriority;
  String? _dueFilter; // overdue, today, next7, next30
  String _searchQuery = '';
  String _sortBy = 'createdAt';
  String _sortOrder = 'desc';

  // Người tạo gom được từ các task đã tải, dùng để đổ vào dropdown.
  final Map<String, String> _creatorOptions = {};
  String? _currentUserId;
  String? _currentUserName;

  final _searchController = TextEditingController();

  int get _activeFilterCount {
    var count = 0;
    if (_filterScope != null) count++;
    if (_filterCreatorId != null) count++;
    if (_filterStatus != null) count++;
    if (_filterPriority != null) count++;
    if (_dueFilter != null) count++;
    return count;
  }

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
    _loadTasks();
    _loadUnreadCount();
    _notificationTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _loadUnreadCount(),
    );
  }

  // Lấy số thông báo chưa đọc; lỗi mạng thì bỏ qua im lặng.
  Future<void> _loadUnreadCount() async {
    try {
      final count = await _notificationService.getUnreadCount();
      if (!mounted) return;
      setState(() => _unreadCount = count);
    } catch (_) {
      // Không hiển thị lỗi để tránh làm phiền khi backend tạm ngắt.
    }
  }

  Future<void> _openNotifications() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const NotificationScreen()),
    );
    if (!mounted) return;
    // Quay lại thì cập nhật badge ngay, không chờ lần polling kế tiếp.
    _loadUnreadCount();
  }

  Future<void> _loadCurrentUser() async {
    final user = await _authService.getCurrentUser();
    if (!mounted) return;
    setState(() {
      _currentUserId = user?.id;
      _currentUserName = user?.fullName;
    });
  }

  @override
  void dispose() {
    _notificationTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  // Tải lại và bỏ toàn bộ bộ lọc (giữ từ khóa tìm kiếm).
  Future<void> _reloadWithoutFilters() async {
    setState(() {
      _filterScope = null;
      _filterCreatorId = null;
      _filterStatus = null;
      _filterPriority = null;
      _dueFilter = null;
    });
    await _loadTasks();
  }

  // Áp bộ lọc từ tab Thống kê. Xóa các filter khác để số dòng khớp số liệu.
  Future<void> applyFilters({String? status, String? dueFilter}) async {
    setState(() {
      _filterScope = null;
      _filterCreatorId = null;
      _filterStatus = status;
      _filterPriority = null;
      _dueFilter = dueFilter;
      _searchQuery = '';
    });
    _searchController.clear();
    await _loadTasks();
  }

  Future<void> _loadTasks() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final tasks = await _apiService.getTasks(
        scope: _filterScope,
        createdBy: _filterCreatorId,
        status: _filterStatus,
        priority: _filterPriority,
        dueFilter: _dueFilter,
        q: _searchQuery.isNotEmpty ? _searchQuery : null,
        sortBy: _sortBy,
        order: _sortOrder,
      );
      setState(() {
        _tasks = tasks;
        _isLoading = false;
        // Ghi nhớ người tạo để đổ vào dropdown lọc.
        for (final task in tasks) {
          if (task.createdBy != null && (task.createdByName ?? '').isNotEmpty) {
            _creatorOptions[task.createdBy!] = task.createdByName!;
          }
        }
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
    return formatDate(parseLocalDate(dateStr));
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

  // Mở modal bottom sheet chứa các bộ lọc.
  void _showFilterSheet() {
    // Biến tạm: chỉ áp dụng khi bấm "Xác nhận".
    String tempScope = _filterScope ?? 'all';
    String tempCreator = _filterCreatorId ?? 'all';
    String tempStatus = _filterStatus ?? 'all';
    String tempPriority = _filterPriority ?? 'all';
    String tempDue = _dueFilter ?? 'all';

    // Danh sách người tạo: Tất cả + Tôi + những người đã tạo task tôi thấy.
    final creatorItems = <DropdownMenuItem<String>>[
      const DropdownMenuItem(value: 'all', child: Text('Tất cả')),
      if (_currentUserId != null)
        DropdownMenuItem(
          value: _currentUserId,
          child: Text(
            _currentUserName == null || _currentUserName!.isEmpty
                ? 'Tôi'
                : 'Tôi ($_currentUserName)',
          ),
        ),
      ..._creatorOptions.entries
          .where((e) => e.key != _currentUserId && e.value.isNotEmpty)
          .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value))),
    ];

    // Nếu người tạo đang chọn không còn trong danh sách thì quay về "Tất cả".
    if (!creatorItems.any((item) => item.value == tempCreator)) {
      tempCreator = 'all';
    }

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Lọc công việc',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    _buildFilterDropdown(
                      label: 'Phạm vi',
                      icon: Icons.folder_outlined,
                      value: tempScope,
                      items: const [
                        DropdownMenuItem(value: 'all', child: Text('Tất cả')),
                        DropdownMenuItem(value: 'created', child: Text('Tôi tạo')),
                        DropdownMenuItem(value: 'assigned', child: Text('Được giao cho tôi')),
                        DropdownMenuItem(value: 'shared', child: Text('Được chia sẻ với tôi')),
                      ],
                      onChanged: (val) => setSheetState(() => tempScope = val!),
                    ),
                    _buildFilterDropdown(
                      label: 'Người tạo',
                      icon: Icons.person_outline,
                      value: tempCreator,
                      items: creatorItems,
                      onChanged: (val) => setSheetState(() => tempCreator = val!),
                    ),
                    _buildFilterDropdown(
                      label: 'Trạng thái',
                      icon: Icons.info_outline,
                      value: tempStatus,
                      items: const [
                        DropdownMenuItem(value: 'all', child: Text('Tất cả')),
                        DropdownMenuItem(value: 'Pending', child: Text('Chờ xử lý')),
                        DropdownMenuItem(value: 'InProgress', child: Text('Đang thực hiện')),
                        DropdownMenuItem(value: 'Completed', child: Text('Hoàn thành')),
                      ],
                      onChanged: (val) => setSheetState(() => tempStatus = val!),
                    ),
                    _buildFilterDropdown(
                      label: 'Mức độ ưu tiên',
                      icon: Icons.flag_outlined,
                      value: tempPriority,
                      items: const [
                        DropdownMenuItem(value: 'all', child: Text('Tất cả')),
                        DropdownMenuItem(value: 'High', child: Text('Cao')),
                        DropdownMenuItem(value: 'Medium', child: Text('Trung bình')),
                        DropdownMenuItem(value: 'Low', child: Text('Thấp')),
                      ],
                      onChanged: (val) => setSheetState(() => tempPriority = val!),
                    ),
                    _buildFilterDropdown(
                      label: 'Hạn hoàn thành',
                      icon: Icons.event_outlined,
                      value: tempDue,
                      items: const [
                        DropdownMenuItem(value: 'all', child: Text('Tất cả')),
                        DropdownMenuItem(value: 'overdue', child: Text('Quá hạn')),
                        DropdownMenuItem(value: 'today', child: Text('Hôm nay')),
                        DropdownMenuItem(value: 'next7', child: Text('7 ngày tới')),
                        DropdownMenuItem(value: 'next30', child: Text('30 ngày tới')),
                      ],
                      onChanged: (val) => setSheetState(() => tempDue = val!),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 48,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(ctx);
                          setState(() {
                            _filterScope = tempScope == 'all' ? null : tempScope;
                            _filterCreatorId = tempCreator == 'all' ? null : tempCreator;
                            _filterStatus = tempStatus == 'all' ? null : tempStatus;
                            _filterPriority = tempPriority == 'all' ? null : tempPriority;
                            _dueFilter = tempDue == 'all' ? null : tempDue;
                          });
                          _loadTasks();
                        },
                        icon: const Icon(Icons.check),
                        label: const Text('Xác nhận'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildFilterDropdown({
    required String label,
    required IconData icon,
    required String value,
    required List<DropdownMenuItem<String>> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: DropdownButtonFormField<String>(
        initialValue: value,
        isExpanded: true,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        ),
        items: items,
        onChanged: onChanged,
      ),
    );
  }

  // Hộp thoại Sắp xếp
  void _showSortDialog() {
    showDialog(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Sắp xếp theo'),
        children: [
          SimpleDialogOption(
            onPressed: () {
              setState(() {
                _sortBy = 'createdAt';
                _sortOrder = 'desc';
              });
              Navigator.pop(ctx);
              _loadTasks();
            },
            child: Row(
              children: [
                Icon(
                  Icons.schedule,
                  size: 20,
                  color: _sortBy == 'createdAt' && _sortOrder == 'desc' ? Colors.blue : Colors.grey,
                ),
                const SizedBox(width: 10),
                Text(
                  'Mới nhất (Mặc định)',
                  style: TextStyle(
                    fontWeight: _sortBy == 'createdAt' && _sortOrder == 'desc' ? FontWeight.bold : FontWeight.normal,
                    color: _sortBy == 'createdAt' && _sortOrder == 'desc' ? Colors.blue : null,
                  ),
                ),
              ],
            ),
          ),
          SimpleDialogOption(
            onPressed: () {
              setState(() {
                _sortBy = 'createdAt';
                _sortOrder = 'asc';
              });
              Navigator.pop(ctx);
              _loadTasks();
            },
            child: Row(
              children: [
                Icon(
                  Icons.history,
                  size: 20,
                  color: _sortBy == 'createdAt' && _sortOrder == 'asc' ? Colors.blue : Colors.grey,
                ),
                const SizedBox(width: 10),
                Text(
                  'Cũ nhất',
                  style: TextStyle(
                    fontWeight: _sortBy == 'createdAt' && _sortOrder == 'asc' ? FontWeight.bold : FontWeight.normal,
                    color: _sortBy == 'createdAt' && _sortOrder == 'asc' ? Colors.blue : null,
                  ),
                ),
              ],
            ),
          ),
          SimpleDialogOption(
            onPressed: () {
              setState(() {
                _sortBy = 'dueDate';
                _sortOrder = 'asc';
              });
              Navigator.pop(ctx);
              _loadTasks();
            },
            child: Row(
              children: [
                Icon(
                  Icons.event,
                  size: 20,
                  color: _sortBy == 'dueDate' ? Colors.blue : Colors.grey,
                ),
                const SizedBox(width: 10),
                Text(
                  'Hạn gần nhất',
                  style: TextStyle(
                    fontWeight: _sortBy == 'dueDate' ? FontWeight.bold : FontWeight.normal,
                    color: _sortBy == 'dueDate' ? Colors.blue : null,
                  ),
                ),
              ],
            ),
          ),
          SimpleDialogOption(
            onPressed: () {
              setState(() {
                _sortBy = 'priority';
                _sortOrder = 'desc';
              });
              Navigator.pop(ctx);
              _loadTasks();
            },
            child: Row(
              children: [
                Icon(
                  Icons.flag,
                  size: 20,
                  color: _sortBy == 'priority' ? Colors.blue : Colors.grey,
                ),
                const SizedBox(width: 10),
                Text(
                  'Ưu tiên cao nhất',
                  style: TextStyle(
                    fontWeight: _sortBy == 'priority' ? FontWeight.bold : FontWeight.normal,
                    color: _sortBy == 'priority' ? Colors.blue : null,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Danh sách công việc'),
        actions: [
          IconButton(
            tooltip: 'Thông báo',
            onPressed: _openNotifications,
            icon: Badge(
              isLabelVisible: _unreadCount > 0,
              label: Text(notificationBadgeLabel(_unreadCount)),
              child: const Icon(Icons.notifications_none),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.sort),
            tooltip: 'Sắp xếp',
            onPressed: _showSortDialog,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Tải lại & bỏ lọc',
            onPressed: () => _reloadWithoutFilters(),
          ),
        ],
      ),
      body: Column(
        children: [
          // Thanh tìm kiếm + nút mở bộ lọc
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Tìm kiếm theo tên hoặc mô tả...',
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
                const SizedBox(width: 8),
                // Nút lọc nằm bên phải thanh tìm kiếm, mở modal bottom sheet.
                IconButton(
                  tooltip: 'Lọc công việc',
                  onPressed: _showFilterSheet,
                  icon: Badge(
                    isLabelVisible: _activeFilterCount > 0,
                    label: Text('$_activeFilterCount'),
                    child: Icon(
                      Icons.filter_list,
                      color: _activeFilterCount > 0 ? Colors.blue : null,
                    ),
                  ),
                ),
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
        label: const Text('Thêm việc'),
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
              _activeFilterCount > 0 || _searchQuery.isNotEmpty
                  ? 'Không tìm thấy công việc phù hợp'
                  : 'Chưa có công việc nào.\nBấm + Thêm việc để bắt đầu!',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 15),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _reloadWithoutFilters,
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

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      elevation: 1.5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => TaskDetailScreen(taskId: task.id),
            ),
          );
          _loadTasks();
        },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icon trạng thái (bấm để chuyển đổi nhanh)
              GestureDetector(
                onTap: () => _quickUpdateStatus(task),
                child: Padding(
                  padding: const EdgeInsets.only(top: 2, right: 10),
                  child: Tooltip(
                    message: 'Nhấn để đổi trạng thái',
                    child: Icon(
                      _statusIcon(task.status),
                      color: _statusColor(task.status),
                      size: 28,
                    ),
                  ),
                ),
              ),

              // Nội dung công việc
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
                      const SizedBox(height: 4),
                      Text(
                        task.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
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
                            style: TextStyle(
                              fontSize: 11,
                              color: _statusColor(task.status),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),

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

              // Badge mức độ ưu tiên
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
    );
  }
}
