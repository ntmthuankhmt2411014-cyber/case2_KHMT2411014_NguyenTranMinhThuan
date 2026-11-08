import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:task_manager/services/statistics_service.dart';
import 'package:task_manager/utils/constants.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({AppConstants.tokenKey: 'token'});
  });

  test('getTaskStatistics gọi đúng endpoint và parse dữ liệu', () async {
    final client = MockClient((request) async {
      expect(request.url.path, '/api/statistics/tasks');
      expect(request.headers['Authorization'], 'Bearer token');
      return http.Response(
        '{"total":1,"byStatus":{"Pending":1,"InProgress":0,"Completed":0}}',
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    });

    final stats = await StatisticsService(client: client).getTaskStatistics();

    expect(stats.total, 1);
    expect(stats.pending, 1);
  });

  test('getAssignmentStatistics parse dữ liệu', () async {
    final client = MockClient((request) async {
      expect(request.url.path, '/api/statistics/assignments');
      return http.Response(
        '{"assignedCount":4,"primaryCount":1}',
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    });

    final stats = await StatisticsService(client: client).getAssignmentStatistics();

    expect(stats.assignedCount, 4);
    expect(stats.primaryCount, 1);
  });

  test('getDeadlineStatistics parse dữ liệu', () async {
    final client = MockClient((request) async {
      expect(request.url.path, '/api/statistics/deadlines');
      return http.Response(
        '{"upcomingCount":2,"overdueCount":1}',
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    });

    final stats = await StatisticsService(client: client).getDeadlineStatistics();

    expect(stats.upcomingCount, 2);
    expect(stats.overdueCount, 1);
  });

  test('ném lỗi khi server trả mã khác 200', () async {
    final client = MockClient(
      (request) async => http.Response(
        '{"message":"Lỗi server"}',
        500,
        headers: {'content-type': 'application/json; charset=utf-8'},
      ),
    );

    expect(
      () => StatisticsService(client: client).getTaskStatistics(),
      throwsA(isA<Exception>()),
    );
  });
}
