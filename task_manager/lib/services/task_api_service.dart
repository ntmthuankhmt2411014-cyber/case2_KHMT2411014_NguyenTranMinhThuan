import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/task.dart';
import '../utils/constants.dart';

class TaskApiService {
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

  // 1. Lấy danh sách công việc (có filter, search, sort)
  Future<List<Task>> getTasks({
    String? status,
    String? priority,
    String? category,
    String? q,
    String? sortBy,
    String? order,
  }) async {
    final queryParams = <String, String>{};
    if (status != null && status.isNotEmpty) queryParams['status'] = status;
    if (priority != null && priority.isNotEmpty) queryParams['priority'] = priority;
    if (category != null && category.isNotEmpty) queryParams['category'] = category;
    if (q != null && q.isNotEmpty) queryParams['q'] = q;
    if (sortBy != null && sortBy.isNotEmpty) queryParams['sortBy'] = sortBy;
    if (order != null && order.isNotEmpty) queryParams['order'] = order;

    final uri = Uri.parse('$baseUrl/tasks').replace(queryParameters: queryParams.isNotEmpty ? queryParams : null);

    final response = await http
        .get(uri, headers: await _authHeaders())
        .timeout(const Duration(seconds: 10));

    if (response.statusCode != 200) {
      throw Exception('Không thể tải danh sách công việc (${response.statusCode})');
    }

    final List data = jsonDecode(utf8.decode(response.bodyBytes));
    return data.map((json) => Task.fromJson(json as Map<String, dynamic>)).toList();
  }

  // 2. Tạo công việc mới
  Future<Map<String, dynamic>> createTask({
    required String title,
    String? description,
    String? category,
    String? priority,
    String? status,
    String? startDate,
    String? dueDate,
  }) async {
    try {
      final body = <String, dynamic>{
        'title': title,
      };
      if (description != null) body['description'] = description;
      if (category != null) body['category'] = category;
      if (priority != null) body['priority'] = priority;
      if (status != null) body['status'] = status;
      if (startDate != null) body['startDate'] = startDate;
      if (dueDate != null) body['dueDate'] = dueDate;

      final response = await http
          .post(
            Uri.parse('$baseUrl/tasks'),
            headers: await _authHeaders(),
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 10));

      final data = jsonDecode(utf8.decode(response.bodyBytes));

      if (response.statusCode == 201) {
        return {'success': true, 'message': data['message'], 'task': data['task']};
      } else {
        return {'success': false, 'message': data['message'] ?? 'Tạo công việc thất bại'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Không thể kết nối máy chủ: $e'};
    }
  }

  // 3. Lấy chi tiết công việc
  Future<Task> getTaskById(String id) async {
    final response = await http
        .get(Uri.parse('$baseUrl/tasks/$id'), headers: await _authHeaders())
        .timeout(const Duration(seconds: 10));

    if (response.statusCode != 200) {
      throw Exception('Không thể tải chi tiết công việc (${response.statusCode})');
    }

    final data = jsonDecode(utf8.decode(response.bodyBytes));
    return Task.fromJson(data as Map<String, dynamic>);
  }

  // 4. Cập nhật công việc
  Future<Map<String, dynamic>> updateTask(String id, Map<String, dynamic> updates) async {
    try {
      final response = await http
          .put(
            Uri.parse('$baseUrl/tasks/$id'),
            headers: await _authHeaders(),
            body: jsonEncode(updates),
          )
          .timeout(const Duration(seconds: 10));

      final data = jsonDecode(utf8.decode(response.bodyBytes));

      if (response.statusCode == 200) {
        return {'success': true, 'message': data['message'], 'task': data['task']};
      } else {
        return {'success': false, 'message': data['message'] ?? 'Cập nhật thất bại'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Không thể kết nối máy chủ: $e'};
    }
  }

  // 5. Cập nhật nhanh trạng thái
  Future<Map<String, dynamic>> updateTaskStatus(String id, String status) async {
    try {
      final response = await http
          .patch(
            Uri.parse('$baseUrl/tasks/$id/status'),
            headers: await _authHeaders(),
            body: jsonEncode({'status': status}),
          )
          .timeout(const Duration(seconds: 10));

      final data = jsonDecode(utf8.decode(response.bodyBytes));

      if (response.statusCode == 200) {
        return {'success': true, 'message': data['message']};
      } else {
        return {'success': false, 'message': data['message'] ?? 'Cập nhật trạng thái thất bại'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Không thể kết nối máy chủ: $e'};
    }
  }

  // 6. Xóa công việc
  Future<Map<String, dynamic>> deleteTask(String id) async {
    try {
      final response = await http
          .delete(Uri.parse('$baseUrl/tasks/$id'), headers: await _authHeaders())
          .timeout(const Duration(seconds: 10));

      final data = jsonDecode(utf8.decode(response.bodyBytes));

      if (response.statusCode == 200) {
        return {'success': true, 'message': data['message']};
      } else {
        return {'success': false, 'message': data['message'] ?? 'Xóa công việc thất bại'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Không thể kết nối máy chủ: $e'};
    }
  }
}
