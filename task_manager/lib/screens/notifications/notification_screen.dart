import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/notification.dart';
import '../../services/notification_service.dart';
import '../tasks/task_detail_screen.dart';

// Nhãn hiển thị trên Badge ở AppBar.
// 0 → ẩn, tối đa hiển thị 99+ để badge không bị quá dài.
String notificationBadgeLabel(int count) {
  if (count <= 0) return '';
  if (count > 99) return '99+';
  return '$count';
}

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  final NotificationService _service = NotificationService();

  List<AppNotification> _notifications = [];
  bool _isLoading = true;
  String? _error;
  bool _isMarkingAll = false;

  int get _unreadCount => _notifications.where((item) => !item.isRead).length;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final notifications = await _service.getNotifications();
      if (!mounted) return;
      setState(() {
        _notifications = notifications;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  // Tạo bản sao với trạng thái đã đọc mới, vì model không có copyWith.
  AppNotification _withRead(AppNotification item, bool isRead) {
    return AppNotification(
      id: item.id,
      taskId: item.taskId,
      type: item.type,
      title: item.title,
      message: item.message,
      isRead: isRead,
      createdAt: item.createdAt,
    );
  }

  Future<void> _markAllRead() async {
    if (_isMarkingAll) return;

    setState(() => _isMarkingAll = true);
    try {
      await _service.markAllRead();
      if (!mounted) return;
      setState(() {
        _notifications = _notifications.map((item) => _withRead(item, true)).toList();
        _isMarkingAll = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đã đánh dấu tất cả là đã đọc'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isMarkingAll = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Không thể đánh dấu đã đọc: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _openNotification(AppNotification notification) async {
    // Đánh dấu đã đọc trước khi mở công việc; lỗi đánh dấu không chặn điều hướng.
    if (!notification.isRead) {
      final success = await _service.markRead(notification.id);
      if (!mounted) return;
      if (success) {
        setState(() {
          final index = _notifications.indexWhere((item) => item.id == notification.id);
          if (index != -1) {
            _notifications[index] = _withRead(_notifications[index], true);
          }
        });
      }
    }

    if (!mounted) return;

    final taskId = notification.taskId;
    if (taskId == null || taskId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Công việc liên quan không còn tồn tại')),
      );
      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => TaskDetailScreen(taskId: taskId)),
    );

    // Quay lại danh sách thì tải lại để phản ánh thay đổi mới nhất.
    if (!mounted) return;
    _load();
  }

  IconData _iconForType(String type) {
    switch (type) {
      case 'task_assigned':
        return Icons.assignment_ind_outlined;
      case 'task_shared':
        return Icons.share_outlined;
      case 'due_date_changed':
        return Icons.event_outlined;
      case 'task_completed':
        return Icons.check_circle_outline;
      case 'deadline_reminder':
        return Icons.alarm;
      default:
        return Icons.notifications_none;
    }
  }

  Color _colorForType(String type) {
    switch (type) {
      case 'task_assigned':
        return Colors.blue;
      case 'task_shared':
        return Colors.purple;
      case 'due_date_changed':
        return Colors.orange;
      case 'task_completed':
        return Colors.green;
      case 'deadline_reminder':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _formatRelativeTime(DateTime? time) {
    if (time == null) return '';

    final localTime = time.toLocal();
    final diff = DateTime.now().difference(localTime);

    if (diff.isNegative || diff.inMinutes < 1) return 'Vừa xong';
    if (diff.inMinutes < 60) return '${diff.inMinutes} phút trước';
    if (diff.inHours < 24) return '${diff.inHours} giờ trước';
    if (diff.inDays < 7) return '${diff.inDays} ngày trước';
    return DateFormat('dd/MM/yyyy HH:mm').format(localTime);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Thông báo'),
        actions: [
          if (_unreadCount > 0)
            _isMarkingAll
                ? const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : TextButton(
                    onPressed: _markAllRead,
                    child: const Text('Đọc tất cả'),
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
              Text('Không tải được thông báo.\n$_error', textAlign: TextAlign.center),
              const SizedBox(height: 12),
              ElevatedButton(onPressed: _load, child: const Text('Thử lại')),
            ],
          ),
        ),
      );
    }

    if (_notifications.isEmpty) {
      return const Center(child: Text('Chưa có thông báo'));
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        itemCount: _notifications.length,
        separatorBuilder: (context, index) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final notification = _notifications[index];
          final color = _colorForType(notification.type);

          return ListTile(
            tileColor: notification.isRead ? null : Colors.blue.shade50,
            leading: CircleAvatar(
              backgroundColor: color.withValues(alpha: 0.15),
              child: Icon(_iconForType(notification.type), color: color, size: 20),
            ),
            title: Text(
              notification.title,
              style: TextStyle(
                fontWeight: notification.isRead ? FontWeight.normal : FontWeight.bold,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 2),
                Text(notification.message),
                const SizedBox(height: 4),
                Text(
                  _formatRelativeTime(notification.createdAt),
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
            ),
            trailing: notification.isRead
                ? null
                : Container(
                    width: 10,
                    height: 10,
                    decoration: const BoxDecoration(
                      color: Colors.blue,
                      shape: BoxShape.circle,
                    ),
                  ),
            onTap: () => _openNotification(notification),
          );
        },
      ),
    );
  }
}
