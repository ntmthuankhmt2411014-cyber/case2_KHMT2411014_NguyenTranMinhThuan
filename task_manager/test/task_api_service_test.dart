import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:task_manager/services/task_api_service.dart';
import 'package:task_manager/utils/constants.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('getTaskById ném TaskNotFoundException khi server trả 404', () async {
    final service = TaskApiService(
      client: MockClient(
        (request) async => http.Response(
          '{"message":"Không tìm thấy công việc"}',
          404,
          headers: {'content-type': 'application/json; charset=utf-8'},
        ),
      ),
    );

    expect(
      () => service.getTaskById('task-da-xoa'),
      throwsA(isA<TaskNotFoundException>()),
    );
  });

  test('TaskNotFoundException có thông báo thân thiện cho người dùng', () {
    final error = TaskNotFoundException();

    expect(error.message, contains('không còn tồn tại'));
    expect(error.toString(), error.message);
  });

  test('getTaskActivities parse danh sách hoạt động', () async {
    SharedPreferences.setMockInitialValues({AppConstants.tokenKey: 'token'});
    final service = TaskApiService(
      client: MockClient((request) async {
        expect(request.url.path, '/api/tasks/t1/activities');
        expect(request.headers['Authorization'], 'Bearer token');
        return http.Response(
          '{"activities":[{"_id":"a1","action":"created","details":{},"userId":{"fullName":"Minh"}}]}',
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );

    final activities = await service.getTaskActivities('t1');

    expect(activities.length, 1);
    expect(activities.first.action, 'created');
    expect(activities.first.userName, 'Minh');
  });

  test('getTaskActivities ném TaskNotFoundException khi server trả 404', () async {
    final service = TaskApiService(
      client: MockClient(
        (request) async => http.Response(
          '{"message":"Không tìm thấy công việc"}',
          404,
          headers: {'content-type': 'application/json; charset=utf-8'},
        ),
      ),
    );

    expect(
      () => service.getTaskActivities('task-da-xoa'),
      throwsA(isA<TaskNotFoundException>()),
    );
  });
}
