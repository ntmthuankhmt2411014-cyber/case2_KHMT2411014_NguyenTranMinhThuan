import 'task_share.dart';

class TaskAssignee {
  final String id;
  final String fullName;
  final String email;

  TaskAssignee({
    required this.id,
    required this.fullName,
    required this.email,
  });

  factory TaskAssignee.fromJson(Map<String, dynamic> json) {
    return TaskAssignee(
      id: json['_id']?.toString() ?? '',
      fullName: json['fullName'] ?? '',
      email: json['email'] ?? '',
    );
  }
}

class Task {
  final String id;
  final String title;
  final String description;
  final String category;
  final String priority;
  final String status;
  final String? startDate;
  final String? dueDate;
  final String? createdBy;
  final String? createdByName;
  final String? createdByEmail;
  final String? primaryAssigneeId;
  final String? primaryAssigneeName;
  final List<TaskAssignee> assignees;
  final List<TaskShare> shares;
  final String? myPermission;
  final String? createdAt;
  final String? updatedAt;

  Task({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.priority,
    required this.status,
    this.startDate,
    this.dueDate,
    this.createdBy,
    this.createdByName,
    this.createdByEmail,
    this.primaryAssigneeId,
    this.primaryAssigneeName,
    this.assignees = const [],
    this.shares = const [],
    this.myPermission,
    this.createdAt,
    this.updatedAt,
  });

  factory Task.fromJson(Map<String, dynamic> json) {
    String? createdById;
    String? createdByName;
    String? createdByEmail;

    final cb = json['createdBy'];
    if (cb is Map<String, dynamic>) {
      createdById = cb['_id']?.toString();
      createdByName = cb['fullName']?.toString();
      createdByEmail = cb['email']?.toString();
    } else if (cb is String) {
      createdById = cb;
    }

    String? primaryAssigneeId;
    String? primaryAssigneeName;
    final pa = json['primaryAssigneeId'];
    if (pa is Map<String, dynamic>) {
      primaryAssigneeId = pa['_id']?.toString();
      primaryAssigneeName = pa['fullName']?.toString();
    } else if (pa is String) {
      primaryAssigneeId = pa;
    }

    List<TaskAssignee> assigneesList = [];
    if (json['assigneeIds'] is List) {
      for (var item in json['assigneeIds']) {
        if (item is Map<String, dynamic>) {
          assigneesList.add(TaskAssignee.fromJson(item));
        }
      }
    }

    List<TaskShare> sharesList = [];
    if (json['shares'] is List) {
      for (var item in json['shares']) {
        if (item is Map<String, dynamic>) {
          sharesList.add(TaskShare.fromJson(item));
        }
      }
    }

    return Task(
      id: json['_id']?.toString() ?? '',
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      category: json['category'] ?? 'Other',
      priority: json['priority'] ?? 'Medium',
      status: json['status'] ?? 'Pending',
      startDate: json['startDate']?.toString(),
      dueDate: json['dueDate']?.toString(),
      createdBy: createdById,
      createdByName: createdByName,
      createdByEmail: createdByEmail,
      primaryAssigneeId: primaryAssigneeId,
      primaryAssigneeName: primaryAssigneeName,
      assignees: assigneesList,
      shares: sharesList,
      myPermission: json['myPermission']?.toString(),
      createdAt: json['createdAt']?.toString(),
      updatedAt: json['updatedAt']?.toString(),
    );
  }

  // Server đã trả myPermission; nếu không (dữ liệu cũ) thì tự suy ra theo
  // thứ tự ưu tiên: creator > primary > editor > assignee > viewer.
  String? effectivePermission(String? currentUserId) {
    if (myPermission != null) return myPermission;
    if (currentUserId == null) return null;

    if (createdBy == currentUserId) return 'creator';
    if (primaryAssigneeId == currentUserId) return 'primary';

    String? sharePermission;
    for (final share in shares) {
      if (share.userId == currentUserId) {
        sharePermission = share.permission;
        break;
      }
    }

    if (sharePermission == 'editor') return 'editor';
    if (assignees.any((assignee) => assignee.id == currentUserId)) {
      return 'assignee';
    }
    if (sharePermission == 'viewer') return 'viewer';
    return 'viewer';
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'description': description,
      'category': category,
      'priority': priority,
      'status': status,
      if (startDate != null) 'startDate': startDate,
      if (dueDate != null) 'dueDate': dueDate,
    };
  }
}
