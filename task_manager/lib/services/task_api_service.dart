import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/task.dart';
import '../models/task_share.dart';
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

  // Dùng chung cho các API ghi: trả success + toàn bộ dữ liệu server trả về.
  Map<String, dynamic> _decodeMutation(http.Response response, String fallbackMessage) {
    final data = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    if (response.statusCode == 200) {
      return {'success': true, ...data};
    }
    return {'success': false, 'message': data['message'] ?? fallbackMessage};
  }

  // 1. Lấy danh sách công việc (có scope, filter, search, sort)
  Future<List<Task>> getTasks({
    String? scope,
    String? status,
    String? priority,
    String? category,
    String? q,
    String? sortBy,
    String? order,
    String? assigneeId,
    String? createdBy,
    String? dueFilter,
  }) async {
    final queryParams = <String, String>{};
    if (scope != null && scope.isNotEmpty) queryParams['scope'] = scope;
    if (status != null && status.isNotEmpty) queryParams['status'] = status;
    if (priority != null && priority.isNotEmpty) queryParams['priority'] = priority;
    if (category != null && category.isNotEmpty) queryParams['category'] = category;
    if (q != null && q.isNotEmpty) queryParams['q'] = q;
    if (sortBy != null && sortBy.isNotEmpty) queryParams['sortBy'] = sortBy;
    if (order != null && order.isNotEmpty) queryParams['order'] = order;
    if (assigneeId != null && assigneeId.isNotEmpty) queryParams['assigneeId'] = assigneeId;
    if (createdBy != null && createdBy.isNotEmpty) queryParams['createdBy'] = createdBy;
    if (dueFilter != null && dueFilter.isNotEmpty) queryParams['dueFilter'] = dueFilter;

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

  // 7. Lấy danh sách người được giao
  Future<List<TaskAssignee>> getAssignees(String taskId) async {
    final response = await http
        .get(
          Uri.parse('$baseUrl/tasks/$taskId/assignees'),
          headers: await _authHeaders(),
        )
        .timeout(const Duration(seconds: 10));

    if (response.statusCode != 200) {
      throw Exception('Không thể tải danh sách người được giao (${response.statusCode})');
    }

    final data = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    final List items = data['assignees'] as List? ?? [];
    return items.whereType<Map<String, dynamic>>().map(TaskAssignee.fromJson).toList();
  }

  // 8. Giao việc cho một hoặc nhiều người
  Future<Map<String, dynamic>> assignUsers(
    String taskId,
    List<String> userIds, {
    String? primaryAssigneeId,
  }) async {
    try {
      final body = <String, dynamic>{'userIds': userIds};
      if (primaryAssigneeId != null) {
        body['primaryAssigneeId'] = primaryAssigneeId;
      }

      final response = await http
          .post(
            Uri.parse('$baseUrl/tasks/$taskId/assignees'),
            headers: await _authHeaders(),
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 10));

      return _decodeMutation(response, 'Giao việc thất bại');
    } catch (e) {
      return {'success': false, 'message': 'Không thể kết nối máy chủ: $e'};
    }
  }

  // 9. Đặt người phụ trách chính
  Future<Map<String, dynamic>> setPrimaryAssignee(String taskId, String userId) async {
    try {
      final response = await http
          .patch(
            Uri.parse('$baseUrl/tasks/$taskId/assignees/$userId'),
            headers: await _authHeaders(),
            body: jsonEncode(<String, dynamic>{}),
          )
          .timeout(const Duration(seconds: 10));

      return _decodeMutation(response, 'Cập nhật người phụ trách chính thất bại');
    } catch (e) {
      return {'success': false, 'message': 'Không thể kết nối máy chủ: $e'};
    }
  }

  // 10. Hủy giao việc cho một người
  Future<Map<String, dynamic>> removeAssignee(String taskId, String userId) async {
    try {
      final response = await http
          .delete(
            Uri.parse('$baseUrl/tasks/$taskId/assignees/$userId'),
            headers: await _authHeaders(),
          )
          .timeout(const Duration(seconds: 10));

      return _decodeMutation(response, 'Hủy giao việc thất bại');
    } catch (e) {
      return {'success': false, 'message': 'Không thể kết nối máy chủ: $e'};
    }
  }

  // 11. Lấy danh sách người được chia sẻ
  Future<List<TaskShare>> getShares(String taskId) async {
    final response = await http
        .get(
          Uri.parse('$baseUrl/tasks/$taskId/shares'),
          headers: await _authHeaders(),
        )
        .timeout(const Duration(seconds: 10));

    if (response.statusCode != 200) {
      throw Exception('Không thể tải danh sách chia sẻ (${response.statusCode})');
    }

    final data = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    final List items = data['shares'] as List? ?? [];
    return items.whereType<Map<String, dynamic>>().map(TaskShare.fromJson).toList();
  }

  // 12. Chia sẻ công việc cho một hoặc nhiều người
  Future<Map<String, dynamic>> shareUsers(
    String taskId,
    List<String> userIds,
    String permission,
  ) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/tasks/$taskId/shares'),
            headers: await _authHeaders(),
            body: jsonEncode({
              'userIds': userIds,
              'permission': permission,
            }),
          )
          .timeout(const Duration(seconds: 10));

      return _decodeMutation(response, 'Chia sẻ công việc thất bại');
    } catch (e) {
      return {'success': false, 'message': 'Không thể kết nối máy chủ: $e'};
    }
  }

  // 13. Cập nhật quyền của một người được chia sẻ
  Future<Map<String, dynamic>> updateSharePermission(
    String taskId,
    String shareId,
    String permission,
  ) async {
    try {
      final response = await http
          .patch(
            Uri.parse('$baseUrl/tasks/$taskId/shares/$shareId'),
            headers: await _authHeaders(),
            body: jsonEncode({'permission': permission}),
          )
          .timeout(const Duration(seconds: 10));

      return _decodeMutation(response, 'Cập nhật quyền chia sẻ thất bại');
    } catch (e) {
      return {'success': false, 'message': 'Không thể kết nối máy chủ: $e'};
    }
  }

  // 14. Thu hồi quyền chia sẻ
  Future<Map<String, dynamic>> removeShare(String taskId, String shareId) async {
    try {
      final response = await http
          .delete(
            Uri.parse('$baseUrl/tasks/$taskId/shares/$shareId'),
            headers: await _authHeaders(),
          )
          .timeout(const Duration(seconds: 10));

      return _decodeMutation(response, 'Thu hồi quyền chia sẻ thất bại');
    } catch (e) {
      return {'success': false, 'message': 'Không thể kết nối máy chủ: $e'};
    }
  }
}
