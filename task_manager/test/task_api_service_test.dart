import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:task_manager/services/task_api_service.dart';

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
}
