import 'package:flutter_test/flutter_test.dart';
import 'package:task_manager/models/user.dart';
import 'package:task_manager/screens/tasks/task_assign_screen.dart';

void main() {
  group('filterAssignCandidates', () {
    User user(String id, String name) =>
        User(id: id, fullName: name, email: '$id@x.com');

    test('loại chính người đang đăng nhập khỏi kết quả tìm kiếm', () {
      final users = [user('me', 'Tôi'), user('other', 'Người khác')];

      final result = filterAssignCandidates(users: users, currentUserId: 'me');

      expect(result.map((u) => u.id), ['other']);
    });

    test('giữ nguyên thứ tự và không loại ai khác', () {
      final users = [user('c', 'C'), user('a', 'A'), user('b', 'B')];

      final result = filterAssignCandidates(users: users, currentUserId: 'me');

      expect(result.map((u) => u.id), ['c', 'a', 'b']);
    });

    test('chưa biết người đang đăng nhập thì giữ nguyên danh sách', () {
      final users = [user('me', 'Tôi'), user('other', 'Người khác')];

      final result = filterAssignCandidates(users: users, currentUserId: null);

      expect(result.map((u) => u.id), ['me', 'other']);
    });

    test('danh sách rỗng trả về rỗng', () {
      expect(
        filterAssignCandidates(users: [], currentUserId: 'me'),
        isEmpty,
      );
    });
  });

  group('buildAssigneeChange', () {
    test('thêm người mới, giữ nguyên phụ trách chính', () {
      final change = buildAssigneeChange(
        originalIds: {'B'},
        selectedIds: {'B', 'C'},
        originalPrimaryId: 'B',
        primaryId: 'B',
      );

      expect(change.added, {'C'});
      expect(change.removed, isEmpty);
      expect(change.primaryAssigneeId, 'B');
      expect(change.primaryInAdded, isFalse);
      expect(change.shouldSetPrimary, isFalse);
    });

    test('bỏ người được giao', () {
      final change = buildAssigneeChange(
        originalIds: {'B', 'C'},
        selectedIds: {'B'},
        originalPrimaryId: 'B',
        primaryId: 'B',
      );

      expect(change.added, isEmpty);
      expect(change.removed, {'C'});
      expect(change.shouldSetPrimary, isFalse);
    });

    test('phụ trách chính mới nằm trong danh sách thêm', () {
      final change = buildAssigneeChange(
        originalIds: {'B'},
        selectedIds: {'B', 'C'},
        originalPrimaryId: 'B',
        primaryId: 'C',
      );

      expect(change.added, {'C'});
      expect(change.primaryInAdded, isTrue);
      // assignUsers đã nhận primaryAssigneeId nên không cần gọi setPrimary nữa.
      expect(change.shouldSetPrimary, isFalse);
    });

    test('đổi phụ trách chính sang người đã được giao', () {
      final change = buildAssigneeChange(
        originalIds: {'B', 'C'},
        selectedIds: {'B', 'C'},
        originalPrimaryId: 'B',
        primaryId: 'C',
      );

      expect(change.added, isEmpty);
      expect(change.removed, isEmpty);
      expect(change.primaryAssigneeId, 'C');
      expect(change.primaryInAdded, isFalse);
      expect(change.shouldSetPrimary, isTrue);
    });

    test('bỏ người đang là phụ trách chính', () {
      final change = buildAssigneeChange(
        originalIds: {'B', 'C'},
        selectedIds: {'C'},
        originalPrimaryId: 'B',
        primaryId: 'C',
      );

      expect(change.removed, {'B'});
      expect(change.primaryAssigneeId, 'C');
      expect(change.shouldSetPrimary, isTrue);
    });

    test('bỏ hết người được giao thì phụ trách chính là null', () {
      final change = buildAssigneeChange(
        originalIds: {'B'},
        selectedIds: <String>{},
        originalPrimaryId: 'B',
        primaryId: null,
      );

      expect(change.removed, {'B'});
      expect(change.added, isEmpty);
      expect(change.primaryAssigneeId, isNull);
      expect(change.shouldSetPrimary, isFalse);
    });

    test('bỏ qua phụ trách chính không còn trong danh sách chọn', () {
      final change = buildAssigneeChange(
        originalIds: {'B', 'C'},
        selectedIds: {'B', 'C'},
        originalPrimaryId: 'B',
        primaryId: 'X',
      );

      expect(change.primaryAssigneeId, isNull);
      expect(change.shouldSetPrimary, isFalse);
    });
  });
}
