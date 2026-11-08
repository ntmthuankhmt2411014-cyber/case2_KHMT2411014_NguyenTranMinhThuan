import 'package:flutter_test/flutter_test.dart';
import 'package:task_manager/models/statistics.dart';

void main() {
  test('parse TaskStatusStatistics', () {
    final stats = TaskStatusStatistics.fromJson({
      'total': 6,
      'byStatus': {'Pending': 2, 'InProgress': 3, 'Completed': 1},
    });

    expect(stats.total, 6);
    expect(stats.pending, 2);
    expect(stats.inProgress, 3);
    expect(stats.completed, 1);
  });

  test('TaskStatusStatistics mặc định 0 khi thiếu dữ liệu', () {
    final stats = TaskStatusStatistics.fromJson({});

    expect(stats.total, 0);
    expect(stats.pending, 0);
    expect(stats.inProgress, 0);
    expect(stats.completed, 0);
  });

  test('parse AssignmentStatistics và DeadlineStatistics', () {
    final assignments = AssignmentStatistics.fromJson({
      'assignedCount': 4,
      'primaryCount': 1,
    });
    final deadlines = DeadlineStatistics.fromJson({
      'upcomingCount': 2,
      'overdueCount': 1,
    });

    expect(assignments.assignedCount, 4);
    expect(assignments.primaryCount, 1);
    expect(deadlines.upcomingCount, 2);
    expect(deadlines.overdueCount, 1);
  });
}
