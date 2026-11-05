import 'package:flutter_test/flutter_test.dart';
import 'package:task_manager/models/task.dart';

void main() {
  test('parse shares và myPermission từ JSON', () {
    final task = Task.fromJson({
      '_id': 't1',
      'title': 'Họp nhóm',
      'createdBy': {'_id': 'u1', 'fullName': 'A', 'email': 'a@x.com'},
      'assigneeIds': [],
      'shares': [
        {
          '_id': 's1',
          'userId': {'_id': 'u2', 'fullName': 'B', 'email': 'b@x.com'},
          'permission': 'editor',
          'sharedBy': {'_id': 'u1', 'fullName': 'A'},
        }
      ],
      'myPermission': 'editor',
    });

    expect(task.shares, hasLength(1));
    expect(task.shares.first.permission, 'editor');
    expect(task.shares.first.userFullName, 'B');
    expect(task.shares.first.userEmail, 'b@x.com');
    expect(task.myPermission, 'editor');
  });

  test('dữ liệu cũ không có shares/myPermission vẫn parse được', () {
    final task = Task.fromJson({
      '_id': 't2',
      'title': 'Việc cũ',
    });

    expect(task.shares, isEmpty);
    expect(task.myPermission, isNull);
  });
}
