import 'package:intl/intl.dart';

// Các hàm dùng chung để tránh lệch múi giờ giữa Flutter và backend.
// - Backend lưu Date theo UTC và trả chuỗi ISO có hậu tố Z.
// - Flutter phải đổi về local trước khi hiển thị và đổi về UTC trước khi gửi.

/// Parse chuỗi ngày giờ từ API và chuyển về múi giờ thiết bị.
DateTime? parseLocalDate(String? value) {
  if (value == null || value.isEmpty) return null;

  final parsed = DateTime.tryParse(value);
  return parsed?.toLocal();
}

/// Hiển thị ngày dạng dd/MM/yyyy theo múi giờ thiết bị.
String formatDate(DateTime? date, {String emptyText = ''}) {
  if (date == null) return emptyText;
  return DateFormat('dd/MM/yyyy').format(date.toLocal());
}

/// Hiển thị ngày giờ dạng dd/MM/yyyy HH:mm theo múi giờ thiết bị.
String formatDateTime(DateTime? date, {String emptyText = ''}) {
  if (date == null) return emptyText;
  return DateFormat('dd/MM/yyyy HH:mm').format(date.toLocal());
}

/// Chuyển DateTime local sang chuỗi UTC có hậu tố Z để gửi backend.
/// Gửi kèm múi giờ giúp server hiểu đúng thời điểm, không bị lệch ngày.
String? toUtcIsoString(DateTime? date) {
  return date?.toUtc().toIso8601String();
}

/// Ghép phần ngày của [date] với giờ/phút người dùng chọn ở TimePicker.
/// Giữ nguyên năm/tháng/ngày, chỉ thay giờ và phút.
DateTime combineDateAndTime(DateTime date, int hour, int minute) {
  return DateTime(date.year, date.month, date.day, hour, minute);
}

/// Hạn hoàn thành phải sau ngày bắt đầu (so sánh cả giờ/phút).
/// Thiếu một trong hai mốc thì chưa cần kiểm tra nên trả true.
bool isDueAfterStart(DateTime? start, DateTime? due) {
  if (start == null || due == null) return true;
  return due.isAfter(start);
}
