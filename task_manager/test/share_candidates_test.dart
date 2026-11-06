import 'package:flutter_test/flutter_test.dart';
import 'package:task_manager/models/user.dart';
import 'package:task_manager/screens/tasks/task_share_screen.dart';

void main() {
  User user(String id, String name) =>
      User(id: id, fullName: name, email: '$id@x.com');

  group('filterShareCandidates', () {
    test('loại chính mình, người đã chia sẻ và người tạo', () {
      final users = [
        user('me', 'Tôi'),
        user('shared', 'Đã chia sẻ'),
        user('creator', 'Người tạo'),
        user('ok', 'Hợp lệ'),
      ];

      final result = filterShareCandidates(
        users: users,
        excludedIds: {'me', 'shared', 'creator'},
      );

      expect(result.map((u) => u.id), ['ok']);
    });

    test('giữ nguyên thứ tự kết quả tìm kiếm', () {
      final users = [user('c', 'C'), user('a', 'A'), user('b', 'B')];

      final result = filterShareCandidates(users: users, excludedIds: {'z'});

      expect(result.map((u) => u.id), ['c', 'a', 'b']);
    });

    test('danh sách rỗng trả về rỗng', () {
      expect(filterShareCandidates(users: [], excludedIds: {'a'}), isEmpty);
    });
  });

  group('sharePermissionLabel', () {
    test('editor hiển thị Chỉnh sửa', () {
      expect(sharePermissionLabel('editor'), 'Chỉnh sửa');
    });

    test('viewer hiển thị Chỉ xem', () {
      expect(sharePermissionLabel('viewer'), 'Chỉ xem');
    });
  });
}
