/// Một dòng lịch sử hoạt động của công việc (collection task_activities).
class TaskActivity {
  final String id;
  final String taskId;
  final String userId;
  final String userName;
  final String userEmail;
  final String action;
  final Map<String, dynamic> details;
  final String? createdAt;

  TaskActivity({
    required this.id,
    required this.taskId,
    required this.userId,
    required this.userName,
    required this.userEmail,
    required this.action,
    this.details = const {},
    this.createdAt,
  });

  factory TaskActivity.fromJson(Map<String, dynamic> json) {
    final user = json['userId'];
    final userMap = user is Map ? user : null;

    return TaskActivity(
      id: json['_id']?.toString() ?? '',
      taskId: json['taskId']?.toString() ?? '',
      userId: userMap != null
          ? userMap['_id']?.toString() ?? ''
          : user?.toString() ?? '',
      userName: userMap != null ? userMap['fullName']?.toString() ?? '' : '',
      userEmail: userMap != null ? userMap['email']?.toString() ?? '' : '',
      action: json['action']?.toString() ?? '',
      details: json['details'] is Map
          ? Map<String, dynamic>.from(json['details'] as Map)
          : const {},
      createdAt: json['createdAt']?.toString(),
    );
  }

  /// Nhãn tiếng Việt hiển thị trên timeline.
  String get actionLabel {
    switch (action) {
      case 'created':
        return 'Tạo công việc';
      case 'updated':
        return 'Cập nhật công việc';
      case 'status_changed':
        return 'Đổi trạng thái';
      case 'assigned':
        return 'Giao việc';
      case 'primary_changed':
        return 'Đổi người phụ trách chính';
      case 'assignee_removed':
        return 'Hủy giao việc';
      case 'shared':
        return 'Chia sẻ công việc';
      case 'permission_changed':
        return 'Đổi quyền chia sẻ';
      case 'share_removed':
        return 'Thu hồi quyền chia sẻ';
      default:
        return action;
    }
  }
}
