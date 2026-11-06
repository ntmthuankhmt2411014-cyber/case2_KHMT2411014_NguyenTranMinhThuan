import 'package:flutter_test/flutter_test.dart';
import 'package:task_manager/models/notification.dart';

void main() {
  group('AppNotification Model', () {
    test('fromJson parse đầy đủ các trường của notification', () {
      final json = {
        '_id': 'notif_1',
        'taskId': 'task_1',
        'type': 'task_assigned',
        'title': 'Bạn được giao một công việc mới',
        'message': 'Nguyen Van A đã giao "Làm slide" cho bạn',
        'isRead': false,
        'createdAt': '2026-11-06T10:00:00.000Z',
      };

      final notif = AppNotification.fromJson(json);

      expect(notif.id, 'notif_1');
      expect(notif.taskId, 'task_1');
      expect(notif.type, 'task_assigned');
      expect(notif.title, 'Bạn được giao một công việc mới');
      expect(notif.message, 'Nguyen Van A đã giao "Làm slide" cho bạn');
      expect(notif.isRead, false);
      expect(notif.createdAt, DateTime.parse('2026-11-06T10:00:00.000Z'));
    });

    test('fromJson xử lý giá trị mặc định khi thiếu trường', () {
      final json = {
        '_id': 'notif_2',
      };

      final notif = AppNotification.fromJson(json);

      expect(notif.id, 'notif_2');
      expect(notif.taskId, isNull);
      expect(notif.type, 'other');
      expect(notif.title, '');
      expect(notif.message, '');
      expect(notif.isRead, false);
      expect(notif.createdAt, isNull);
    });

    test('notificationTypeLabel trả về nhãn tiếng Việt tương ứng', () {
      expect(notificationTypeLabel('task_assigned'), 'Giao việc');
      expect(notificationTypeLabel('task_shared'), 'Chia sẻ');
      expect(notificationTypeLabel('due_date_changed'), 'Đổi hạn');
      expect(notificationTypeLabel('task_completed'), 'Hoàn thành');
      expect(notificationTypeLabel('deadline_reminder'), 'Nhắc hạn');
      expect(notificationTypeLabel('other'), 'Thông báo');
    });
  });
}
