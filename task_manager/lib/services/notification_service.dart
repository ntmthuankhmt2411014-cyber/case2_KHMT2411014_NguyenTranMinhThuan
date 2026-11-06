import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/notification.dart';
import '../models/email_log.dart';
import '../utils/constants.dart';

class NotificationService {
  String get baseUrl => AppConstants.baseUrl;

  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(AppConstants.tokenKey);
  }

  Future<Map<String, String>> _authHeaders() async {
    final token = await _getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  // 1. Lấy danh sách thông báo của người dùng
  Future<List<AppNotification>> getNotifications({int limit = 50}) async {
    final uri = Uri.parse('$baseUrl/notifications?limit=$limit');
    final response = await http
        .get(uri, headers: await _authHeaders())
        .timeout(const Duration(seconds: 10));

    if (response.statusCode != 200) {
      throw Exception('Không thể tải thông báo (${response.statusCode})');
    }

    final data = jsonDecode(utf8.decode(response.bodyBytes));
    final List list = data['notifications'] ?? [];
    return list
        .map((item) => AppNotification.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  // 2. Lấy số lượng thông báo chưa đọc
  Future<int> getUnreadCount() async {
    final uri = Uri.parse('$baseUrl/notifications/unread-count');
    final response = await http
        .get(uri, headers: await _authHeaders())
        .timeout(const Duration(seconds: 10));

    if (response.statusCode != 200) {
      throw Exception('Không thể lấy số thông báo chưa đọc (${response.statusCode})');
    }

    final data = jsonDecode(utf8.decode(response.bodyBytes));
    return (data['count'] as num?)?.toInt() ?? 0;
  }

  // 3. Đánh dấu một thông báo đã đọc
  Future<bool> markRead(String id) async {
    final uri = Uri.parse('$baseUrl/notifications/$id/read');
    final response = await http
        .patch(uri, headers: await _authHeaders())
        .timeout(const Duration(seconds: 10));

    return response.statusCode == 200;
  }

  // 4. Đánh dấu tất cả thông báo là đã đọc
  Future<int> markAllRead() async {
    final uri = Uri.parse('$baseUrl/notifications/read-all');
    final response = await http
        .patch(uri, headers: await _authHeaders())
        .timeout(const Duration(seconds: 10));

    if (response.statusCode != 200) {
      throw Exception('Không thể đánh dấu đã đọc tất cả (${response.statusCode})');
    }

    final data = jsonDecode(utf8.decode(response.bodyBytes));
    return (data['modifiedCount'] as num?)?.toInt() ?? 0;
  }

  // 5. Lấy lịch sử gửi email theo task
  Future<List<EmailLog>> getTaskEmailLogs(String taskId) async {
    final uri = Uri.parse('$baseUrl/tasks/$taskId/email-logs');
    final response = await http
        .get(uri, headers: await _authHeaders())
        .timeout(const Duration(seconds: 10));

    if (response.statusCode != 200) {
      throw Exception('Không thể tải lịch sử email (${response.statusCode})');
    }

    final data = jsonDecode(utf8.decode(response.bodyBytes));
    final List list = data['emailLogs'] ?? [];
    return list
        .map((item) => EmailLog.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  // 6. Gửi lại email thất bại (retry)
  Future<Map<String, dynamic>> retryEmailLog(String id) async {
    try {
      final uri = Uri.parse('$baseUrl/email-logs/$id/retry');
      final response = await http
          .post(uri, headers: await _authHeaders())
          .timeout(const Duration(seconds: 15));

      final data = jsonDecode(utf8.decode(response.bodyBytes));

      if (response.statusCode == 200) {
        return {
          'success': true,
          'message': data['message'] ?? 'Gửi lại thành công',
          'emailLog': EmailLog.fromJson(data['emailLog'] as Map<String, dynamic>),
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Gửi lại thất bại',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Không thể kết nối máy chủ: $e',
      };
    }
  }
}
