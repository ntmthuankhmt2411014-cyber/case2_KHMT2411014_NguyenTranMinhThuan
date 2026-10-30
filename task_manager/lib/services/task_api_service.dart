import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/task.dart';
import '../utils/constants.dart';

class TaskApiService {
  String get baseUrl => AppConstants.baseUrl;

  Future<List<Task>> getTasks() async {
    final response = await http
        .get(Uri.parse('$baseUrl/tasks'))
        .timeout(const Duration(seconds: 10));

    if (response.statusCode != 200) {
      throw Exception('Không thể tải danh sách công việc (${response.statusCode})');
    }

    final List data = jsonDecode(response.body);

    return data
        .map((json) => Task.fromJson(json as Map<String, dynamic>))
        .toList();
  }
}
