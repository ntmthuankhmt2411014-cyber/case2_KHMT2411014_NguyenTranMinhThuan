/// Số liệu thống kê công việc theo trạng thái.
class TaskStatusStatistics {
  final int total;
  final int pending;
  final int inProgress;
  final int completed;

  TaskStatusStatistics({
    required this.total,
    required this.pending,
    required this.inProgress,
    required this.completed,
  });

  factory TaskStatusStatistics.fromJson(Map<String, dynamic> json) {
    final byStatus = json['byStatus'] is Map
        ? Map<String, dynamic>.from(json['byStatus'] as Map)
        : const <String, dynamic>{};

    return TaskStatusStatistics(
      total: json['total'] ?? 0,
      pending: byStatus['Pending'] ?? 0,
      inProgress: byStatus['InProgress'] ?? 0,
      completed: byStatus['Completed'] ?? 0,
    );
  }
}

/// Số việc được giao và số việc đang là người phụ trách chính.
class AssignmentStatistics {
  final int assignedCount;
  final int primaryCount;

  AssignmentStatistics({
    required this.assignedCount,
    required this.primaryCount,
  });

  factory AssignmentStatistics.fromJson(Map<String, dynamic> json) {
    return AssignmentStatistics(
      assignedCount: json['assignedCount'] ?? 0,
      primaryCount: json['primaryCount'] ?? 0,
    );
  }
}

/// Số việc sắp đến hạn (7 ngày tới) và đã quá hạn.
class DeadlineStatistics {
  final int upcomingCount;
  final int overdueCount;

  DeadlineStatistics({
    required this.upcomingCount,
    required this.overdueCount,
  });

  factory DeadlineStatistics.fromJson(Map<String, dynamic> json) {
    return DeadlineStatistics(
      upcomingCount: json['upcomingCount'] ?? 0,
      overdueCount: json['overdueCount'] ?? 0,
    );
  }
}
