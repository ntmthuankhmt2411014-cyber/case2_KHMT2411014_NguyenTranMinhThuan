import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:task_manager/utils/date_time.dart';

void main() {
  group('parseLocalDate', () {
    test('trả null với giá trị rỗng hoặc không hợp lệ', () {
      expect(parseLocalDate(null), isNull);
      expect(parseLocalDate(''), isNull);
      expect(parseLocalDate('khong-phai-ngay'), isNull);
    });

    test('giữ nguyên thời điểm khi parse chuỗi UTC', () {
      final parsed = parseLocalDate('2026-11-06T17:00:00.000Z');

      expect(parsed, isNotNull);
      expect(parsed!.toUtc(), DateTime.utc(2026, 11, 6, 17));
    });
  });

  group('formatDate', () {
    test('định dạng ngày theo giờ địa phương', () {
      expect(formatDate(DateTime(2026, 11, 7)), '07/11/2026');
    });

    test('trả emptyText khi giá trị null', () {
      expect(formatDate(null, emptyText: 'Chưa chọn'), 'Chưa chọn');
    });

    test('chuyển UTC sang local trước khi định dạng', () {
      // Trên máy UTC+0 hai cách format trùng nhau nên chỉ kiểm tra khi có lệch múi giờ.
      if (DateTime.now().timeZoneOffset == Duration.zero) return;

      final utcDate = DateTime.utc(2026, 11, 6, 17);

      expect(
        formatDate(utcDate),
        isNot(DateFormat('dd/MM/yyyy').format(utcDate)),
      );
    });
  });

  group('formatDateTime', () {
    test('định dạng đủ ngày và giờ theo giờ địa phương', () {
      expect(
        formatDateTime(DateTime(2026, 11, 7, 8, 30)),
        '07/11/2026 08:30',
      );
    });

    test('trả emptyText khi giá trị null', () {
      expect(formatDateTime(null, emptyText: 'Chưa thiết lập'), 'Chưa thiết lập');
    });
  });

  group('toUtcIsoString', () {
    test('trả null khi giá trị null', () {
      expect(toUtcIsoString(null), isNull);
    });

    test('luôn gửi chuỗi UTC có hậu tố Z', () {
      final iso = toUtcIsoString(DateTime(2026, 11, 7, 0, 0));

      expect(iso, isNotNull);
      expect(iso, endsWith('Z'));
      expect(DateTime.parse(iso!).isAtSameMomentAs(DateTime(2026, 11, 7)), isTrue);
    });
  });

  group('combineDateAndTime', () {
    test('giữ nguyên ngày và gắn giờ/phút được chọn', () {
      final result = combineDateAndTime(DateTime(2026, 11, 7, 15, 30), 8, 5);

      expect(result, DateTime(2026, 11, 7, 8, 5));
    });

    test('giữ đúng ngày khi giờ là 23:59', () {
      final result = combineDateAndTime(DateTime(2026, 11, 7), 23, 59);

      expect(result, DateTime(2026, 11, 7, 23, 59));
    });
  });

  group('isDueAfterStart', () {
    test('trả true khi thiếu một trong hai mốc', () {
      expect(isDueAfterStart(null, DateTime(2026, 11, 7)), isTrue);
      expect(isDueAfterStart(DateTime(2026, 11, 7), null), isTrue);
      expect(isDueAfterStart(null, null), isTrue);
    });

    test('trả true khi hạn sau ngày bắt đầu', () {
      expect(
        isDueAfterStart(DateTime(2026, 11, 7, 8), DateTime(2026, 11, 7, 9)),
        isTrue,
      );
    });

    test('trả false khi hạn trùng hoặc trước ngày bắt đầu', () {
      expect(
        isDueAfterStart(DateTime(2026, 11, 7, 8), DateTime(2026, 11, 7, 8)),
        isFalse,
      );
      expect(
        isDueAfterStart(DateTime(2026, 11, 7, 9), DateTime(2026, 11, 7, 8)),
        isFalse,
      );
    });
  });
}
