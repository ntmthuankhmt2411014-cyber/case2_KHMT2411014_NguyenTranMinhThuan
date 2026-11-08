import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/statistics.dart';
import '../utils/constants.dart';

/// Gọi 3 API thống kê của backend (mục E).
class StatisticsService {
  final http.Client _client;

  StatisticsService({http.Client? client}) : _client = client ?? http.Client();

  Future<Map<String, String>> _authHeaders() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(AppConstants.tokenKey);
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  Future<Map<String, dynamic>> _get(String path) async {
    final response = await _client
        .get(
          Uri.parse('${AppConstants.baseUrl}$path'),
          headers: await _authHeaders(),
        )
        .timeout(const Duration(seconds: 10));

    if (response.statusCode != 200) {
      throw Exception('Không thể tải thống kê (${response.statusCode})');
    }

    return jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
  }

  Future<TaskStatusStatistics> getTaskStatistics() async {
    return TaskStatusStatistics.fromJson(await _get('/statistics/tasks'));
  }

  Future<AssignmentStatistics> getAssignmentStatistics() async {
    return AssignmentStatistics.fromJson(await _get('/statistics/assignments'));
  }

  Future<DeadlineStatistics> getDeadlineStatistics() async {
    return DeadlineStatistics.fromJson(await _get('/statistics/deadlines'));
  }
}
