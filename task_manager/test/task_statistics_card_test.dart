import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:task_manager/models/statistics.dart';
import 'package:task_manager/widgets/task_statistics_card.dart';

Widget wrap(Widget child) {
  return MaterialApp(
    home: Scaffold(
      body: SingleChildScrollView(child: child),
    ),
  );
}

void main() {
  testWidgets('hiển thị số liệu thống kê', (tester) async {
    await tester.pumpWidget(
      wrap(
        TaskStatisticsCard(
          isLoading: false,
          taskStats: TaskStatusStatistics(
            total: 6,
            pending: 2,
            inProgress: 3,
            completed: 1,
          ),
          assignmentStats: AssignmentStatistics(
            assignedCount: 4,
            primaryCount: 1,
          ),
          deadlineStats: DeadlineStatistics(
            upcomingCount: 2,
            overdueCount: 1,
          ),
          onRetry: () {},
          onOpenStatus: (_) {},
          onOpenDueFilter: (_) {},
        ),
      ),
    );

    expect(find.text('Thống kê công việc'), findsOneWidget);
    expect(find.text('6'), findsOneWidget);
    expect(find.text('Được giao'), findsOneWidget);
    expect(find.text('4'), findsOneWidget);
    expect(find.text('Đang phụ trách'), findsOneWidget);
    expect(find.text('Sắp đến hạn (7 ngày)'), findsOneWidget);
    expect(find.text('Quá hạn'), findsOneWidget);
  });

  testWidgets('hiển thị lỗi và nút thử lại', (tester) async {
    var retried = false;

    await tester.pumpWidget(
      wrap(
        TaskStatisticsCard(
          isLoading: false,
          error: 'Không tải được thống kê',
          onRetry: () => retried = true,
          onOpenStatus: (_) {},
          onOpenDueFilter: (_) {},
        ),
      ),
    );

    expect(find.textContaining('Không tải được'), findsOneWidget);
    expect(find.text('Thử lại'), findsOneWidget);

    await tester.tap(find.text('Thử lại'));
    expect(retried, isTrue);
  });

  testWidgets('hiển thị loading', (tester) async {
    await tester.pumpWidget(
      wrap(
        TaskStatisticsCard(
          isLoading: true,
          onRetry: () {},
          onOpenStatus: (_) {},
          onOpenDueFilter: (_) {},
        ),
      ),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('bấm ô trạng thái mở danh sách đã lọc', (tester) async {
    String? openedStatus = 'chưa gọi';

    await tester.pumpWidget(
      wrap(
        TaskStatisticsCard(
          isLoading: false,
          taskStats: TaskStatusStatistics(
            total: 3,
            pending: 1,
            inProgress: 1,
            completed: 1,
          ),
          onRetry: () {},
          onOpenStatus: (status) => openedStatus = status,
          onOpenDueFilter: (_) {},
        ),
      ),
    );

    await tester.tap(find.text('Chờ làm'));
    expect(openedStatus, 'Pending');
  });

  testWidgets('bấm ô quá hạn mở danh sách overdue', (tester) async {
    String? openedDueFilter;

    await tester.pumpWidget(
      wrap(
        TaskStatisticsCard(
          isLoading: false,
          deadlineStats: DeadlineStatistics(
            upcomingCount: 2,
            overdueCount: 1,
          ),
          onRetry: () {},
          onOpenStatus: (_) {},
          onOpenDueFilter: (filter) => openedDueFilter = filter,
        ),
      ),
    );

    await tester.tap(find.text('Quá hạn'));
    expect(openedDueFilter, 'overdue');

    await tester.tap(find.text('Sắp đến hạn (7 ngày)'));
    expect(openedDueFilter, 'next7');
  });
}
