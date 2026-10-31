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
  final String? createdAt;

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
    this.createdAt,
  });

  factory Task.fromJson(Map<String, dynamic> json) {
    String? createdById;
    String? createdByName;

    final cb = json['createdBy'];
    if (cb is Map<String, dynamic>) {
      createdById = cb['_id']?.toString();
      createdByName = cb['fullName']?.toString();
    } else if (cb is String) {
      createdById = cb;
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
      createdAt: json['createdAt']?.toString(),
    );
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
