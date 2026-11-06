class AppNotification {
  final String id;
  final String? taskId;
  final String type;
  final String title;
  final String message;
  final bool isRead;
  final DateTime? createdAt;

  AppNotification({
    required this.id,
    this.taskId,
    required this.type,
    required this.title,
    required this.message,
    this.isRead = false,
    this.createdAt,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json['_id']?.toString() ?? '',
      taskId: json['taskId']?.toString(),
      type: json['type']?.toString() ?? 'other',
      title: json['title']?.toString() ?? '',
      message: json['message']?.toString() ?? '',
      isRead: json['isRead'] as bool? ?? false,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString())
          : null,
    );
  }
}

String notificationTypeLabel(String type) {
  switch (type) {
    case 'task_assigned':
      return 'Giao việc';
    case 'task_shared':
      return 'Chia sẻ';
    case 'due_date_changed':
      return 'Đổi hạn';
    case 'task_completed':
      return 'Hoàn thành';
    case 'deadline_reminder':
      return 'Nhắc hạn';
    default:
      return 'Thông báo';
  }
}
