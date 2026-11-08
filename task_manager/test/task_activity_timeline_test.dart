import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:task_manager/models/task_activity.dart';
import 'package:task_manager/widgets/task_activity_timeline.dart';

Widget wrap(Widget child) {
  return MaterialApp(
    home: Scaffold(
      body: SingleChildScrollView(child: child),
    ),
  );
}

void main() {
  testWidgets('hiển thị lịch sử hoạt động', (tester) async {
    await tester.pumpWidget(
      wrap(
        TaskActivityTimeline(
          activities: [
            TaskActivity(
              id: 'a1',
              taskId: 't1',
              userId: 'u1',
              userName: 'Minh',
              userEmail: 'minh@example.com',
              action: 'status_changed',
              details: const {'from': 'Pending', 'to': 'InProgress'},
              createdAt: '2026-11-07T08:30:00.000Z',
            ),
          ],
          isLoading: false,
          onRetry: () {},
        ),
      ),
    );

    expect(find.text('Lịch sử hoạt động'), findsOneWidget);
    expect(find.text('Đổi trạng thái'), findsOneWidget);
    expect(find.textContaining('Minh'), findsOneWidget);
    expect(find.textContaining('Pending'), findsOneWidget);
  });

  testWidgets('hiển thị trạng thái rỗng', (tester) async {
    await tester.pumpWidget(
      wrap(
        TaskActivityTimeline(
          activities: const [],
          isLoading: false,
          onRetry: () {},
        ),
      ),
    );

    expect(find.text('Lịch sử hoạt động'), findsOneWidget);
    expect(find.text('Chưa có hoạt động'), findsOneWidget);
  });

  testWidgets('hiển thị lỗi và nút thử lại', (tester) async {
    var retried = false;

    await tester.pumpWidget(
      wrap(
        TaskActivityTimeline(
          activities: const [],
          isLoading: false,
          error: 'Không tải được lịch sử',
          onRetry: () => retried = true,
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
        TaskActivityTimeline(
          activities: const [],
          isLoading: true,
          onRetry: () {},
        ),
      ),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}
