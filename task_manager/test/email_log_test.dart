import 'package:flutter_test/flutter_test.dart';
import 'package:task_manager/models/email_log.dart';

void main() {
  group('EmailLog Model', () {
    test('fromJson parse đầy đủ các trường của log thành công', () {
      final json = {
        '_id': 'log_1',
        'taskId': 'task_1',
        'recipientEmail': 'thuan@example.com',
        'eventType': 'task_assigned',
        'subject': '[Quản lý công việc] Bạn được giao việc: Báo cáo giữa kỳ',
        'status': 'sent',
        'attempts': 1,
        'errorMessage': '',
        'sentAt': '2026-11-06T10:05:00.000Z',
        'createdAt': '2026-11-06T10:00:00.000Z',
      };

      final log = EmailLog.fromJson(json);

      expect(log.id, 'log_1');
      expect(log.taskId, 'task_1');
      expect(log.recipientEmail, 'thuan@example.com');
      expect(log.eventType, 'task_assigned');
      expect(log.subject, '[Quản lý công việc] Bạn được giao việc: Báo cáo giữa kỳ');
      expect(log.status, 'sent');
      expect(log.attempts, 1);
      expect(log.errorMessage, '');
      expect(log.sentAt, DateTime.parse('2026-11-06T10:05:00.000Z'));
      expect(log.createdAt, DateTime.parse('2026-11-06T10:00:00.000Z'));
    });

    test('canRetryEmailLog kiểm tra đúng điều kiện được retry', () {
      expect(canRetryEmailLog('failed', 1), isTrue);
      expect(canRetryEmailLog('failed', 2), isTrue);
      expect(canRetryEmailLog('failed', 3), isFalse); // attempts >= 3 không cho retry
      expect(canRetryEmailLog('sent', 1), isFalse);
      expect(canRetryEmailLog('pending', 0), isFalse);
    });

    test('emailStatusLabel và emailEventLabel trả về nhãn tiếng Việt', () {
      expect(emailStatusLabel('sent'), 'Đã gửi');
      expect(emailStatusLabel('failed'), 'Thất bại');
      expect(emailStatusLabel('pending'), 'Đang gửi');

      expect(emailEventLabel('task_assigned'), 'Giao việc');
      expect(emailEventLabel('task_shared'), 'Chia sẻ');
      expect(emailEventLabel('due_date_changed'), 'Đổi hạn');
      expect(emailEventLabel('task_completed'), 'Hoàn thành');
      expect(emailEventLabel('deadline_reminder'), 'Nhắc hạn');
    });
  });
}
