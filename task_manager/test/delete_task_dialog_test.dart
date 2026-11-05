import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:task_manager/widgets/delete_task_dialog.dart';

void main() {
  Future<ValueNotifier<bool?>> openDialog(
    WidgetTester tester, {
    String title = 'Họp nhóm',
  }) async {
    final result = ValueNotifier<bool?>(null);
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () async {
                  result.value = await showDeleteTaskDialog(context, title);
                },
                child: const Text('Mở'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Mở'));
    await tester.pumpAndSettle();
    return result;
  }

  testWidgets('hiển thị hộp thoại xác nhận kèm tên công việc', (tester) async {
    await openDialog(tester);

    expect(find.text('Xóa công việc'), findsOneWidget);
    expect(find.textContaining('Họp nhóm'), findsOneWidget);
  });

  testWidgets('bấm Hủy thì trả về false', (tester) async {
    final result = await openDialog(tester);

    await tester.tap(find.text('Hủy'));
    await tester.pumpAndSettle();

    expect(result.value, isFalse);
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('bấm Xóa thì trả về true', (tester) async {
    final result = await openDialog(tester);

    await tester.tap(find.text('Xóa'));
    await tester.pumpAndSettle();

    expect(result.value, isTrue);
    expect(find.byType(AlertDialog), findsNothing);
  });
}
