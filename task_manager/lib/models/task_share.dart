class TaskShare {
  final String id;
  final String userId;
  final String userFullName;
  final String userEmail;
  final String permission;
  final String sharedById;
  final String sharedByName;
  final String? createdAt;

  TaskShare({
    required this.id,
    required this.userId,
    required this.userFullName,
    required this.userEmail,
    required this.permission,
    this.sharedById = '',
    this.sharedByName = '',
    this.createdAt,
  });

  factory TaskShare.fromJson(Map<String, dynamic> json) {
    String userId = '';
    String userFullName = '';
    String userEmail = '';
    final user = json['userId'];
    if (user is Map<String, dynamic>) {
      userId = user['_id']?.toString() ?? '';
      userFullName = user['fullName']?.toString() ?? '';
      userEmail = user['email']?.toString() ?? '';
    } else if (user != null) {
      userId = user.toString();
    }

    String sharedById = '';
    String sharedByName = '';
    final sharedBy = json['sharedBy'];
    if (sharedBy is Map<String, dynamic>) {
      sharedById = sharedBy['_id']?.toString() ?? '';
      sharedByName = sharedBy['fullName']?.toString() ?? '';
    } else if (sharedBy != null) {
      sharedById = sharedBy.toString();
    }

    return TaskShare(
      id: json['_id']?.toString() ?? '',
      userId: userId,
      userFullName: userFullName,
      userEmail: userEmail,
      permission: json['permission']?.toString() ?? 'viewer',
      sharedById: sharedById,
      sharedByName: sharedByName,
      createdAt: json['createdAt']?.toString(),
    );
  }
}
