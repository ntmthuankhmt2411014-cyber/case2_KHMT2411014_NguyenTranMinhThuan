import 'package:flutter_test/flutter_test.dart';
import 'package:task_manager/models/task_activity.dart';

void main() {
  test('parse đầy đủ trường và map nhãn hành động', () {
    final activity = TaskActivity.fromJson({
      '_id': 'a1',
      'taskId': 't1',
      'userId': {
        '_id': 'u1',
        'fullName': 'Minh',
        'email': 'minh@example.com',
      },
      'action': 'status_changed',
      'details': {'from': 'Pending', 'to': 'InProgress'},
      'createdAt': '2026-11-07T08:30:00.000Z',
    });

    expect(activity.id, 'a1');
    expect(activity.taskId, 't1');
    expect(activity.userId, 'u1');
    expect(activity.userName, 'Minh');
    expect(activity.userEmail, 'minh@example.com');
    expect(activity.actionLabel, 'Đổi trạng thái');
    expect(activity.details['to'], 'InProgress');
    expect(activity.createdAt, '2026-11-07T08:30:00.000Z');
  });

  test('parse userId dạng chuỗi và details thiếu', () {
    final activity = TaskActivity.fromJson({
      '_id': 'a2',
      'userId': 'u2',
      'action': 'created',
    });

    expect(activity.userId, 'u2');
    expect(activity.userName, '');
    expect(activity.details, isEmpty);
    expect(activity.actionLabel, 'Tạo công việc');
  });

  test('nhãn hành động lạ giữ nguyên mã hành động', () {
    final activity = TaskActivity.fromJson({'action': 'custom_action'});

    expect(activity.actionLabel, 'custom_action');
  });
}
