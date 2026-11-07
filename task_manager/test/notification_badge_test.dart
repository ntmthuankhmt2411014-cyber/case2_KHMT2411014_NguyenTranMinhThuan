import 'package:flutter_test/flutter_test.dart';
import 'package:task_manager/screens/notifications/notification_screen.dart';

void main() {
  test('badge hiển thị đúng', () {
    expect(notificationBadgeLabel(0), '');
    expect(notificationBadgeLabel(5), '5');
    expect(notificationBadgeLabel(120), '99+');
  });
}
