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

  group('effectivePermission khi server không trả myPermission', () {
    Task buildTask() => Task.fromJson({
          '_id': 't1',
          'title': 'Họp nhóm',
          'createdBy': 'creator-id',
          'primaryAssigneeId': {'_id': 'primary-id', 'fullName': 'P'},
          'assigneeIds': [
            {'_id': 'primary-id', 'fullName': 'P'},
            {'_id': 'assignee-id', 'fullName': 'A'},
          ],
          'shares': [
            {
              '_id': 's1',
              'userId': {'_id': 'editor-id', 'fullName': 'E'},
              'permission': 'editor',
            },
            {
              '_id': 's2',
              'userId': {'_id': 'viewer-id', 'fullName': 'V'},
              'permission': 'viewer',
            },
            {
              '_id': 's3',
              'userId': {'_id': 'both-id', 'fullName': 'B'},
              'permission': 'viewer',
            },
          ],
        });

    test('ưu tiên myPermission do server trả', () {
      final task = Task.fromJson({
        '_id': 't1',
        'title': 'Họp nhóm',
        'myPermission': 'viewer',
        'createdBy': 'creator-id',
      });
      expect(task.effectivePermission('creator-id'), 'viewer');
    });

    test('người tạo luôn là creator', () {
      expect(buildTask().effectivePermission('creator-id'), 'creator');
    });

    test('phụ trách chính là primary', () {
      expect(buildTask().effectivePermission('primary-id'), 'primary');
    });

    test('share editor thắng quyền assignee khi trùng', () {
      final task = Task.fromJson({
        '_id': 't1',
        'title': 'Họp nhóm',
        'assigneeIds': [
          {'_id': 'both-id', 'fullName': 'B'},
        ],
        'shares': [
          {
            '_id': 's1',
            'userId': {'_id': 'both-id', 'fullName': 'B'},
            'permission': 'editor',
          },
        ],
      });
      expect(task.effectivePermission('both-id'), 'editor');
    });

    test('người được giao khác là assignee', () {
      expect(buildTask().effectivePermission('assignee-id'), 'assignee');
    });

    test('share viewer là viewer', () {
      expect(buildTask().effectivePermission('viewer-id'), 'viewer');
    });

    test('người không liên quan mặc định là viewer', () {
      expect(buildTask().effectivePermission('stranger-id'), 'viewer');
    });

    test('không có người dùng hiện tại thì trả null', () {
      expect(buildTask().effectivePermission(null), isNull);
    });
  });
}
