import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/user.dart';
import '../utils/constants.dart';

class UserService {
  Future<Map<String, String>> _authHeaders() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(AppConstants.tokenKey);
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  // GET /users/search?q= — tìm theo tên hoặc email (dùng khi lọc người phụ trách)
  Future<List<User>> searchUsers(String q) async {
    final query = q.trim();
    if (query.isEmpty) return [];

    final uri = Uri.parse('${AppConstants.baseUrl}/users/search').replace(
      queryParameters: {'q': query},
    );

    final response = await http
        .get(uri, headers: await _authHeaders())
        .timeout(const Duration(seconds: 10));

    if (response.statusCode != 200) {
      throw Exception('Không thể tìm người dùng (${response.statusCode})');
    }

    final List data = jsonDecode(utf8.decode(response.bodyBytes));
    return data.map((json) => User.fromJson(json as Map<String, dynamic>)).toList();
  }
}
