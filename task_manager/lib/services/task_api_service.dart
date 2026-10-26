import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/task.dart';

class TaskApiService {
  // 10.0.2.2 = máy tính (host) nhìn từ Android Emulator.
  // Nếu chạy trên điện thoại thật, đổi thành IP máy tính, ví dụ 192.168.1.10
  static const String baseUrl = 'http://192.168.0.200:3000/api';

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