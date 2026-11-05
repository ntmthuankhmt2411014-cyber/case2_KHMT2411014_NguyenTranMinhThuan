import 'package:flutter_test/flutter_test.dart';
import 'package:task_manager/utils/task_permissions.dart';

void main() {
  test('creator/primary/editor được sửa', () {
    expect(TaskPermissions.canEdit('creator'), isTrue);
    expect(TaskPermissions.canEdit('primary'), isTrue);
    expect(TaskPermissions.canEdit('editor'), isTrue);
    expect(TaskPermissions.canEdit('assignee'), isFalse);
    expect(TaskPermissions.canEdit('viewer'), isFalse);
    expect(TaskPermissions.canEdit(null), isFalse);
  });

  test('assignee được đổi trạng thái', () {
    expect(TaskPermissions.canChangeStatus('creator'), isTrue);
    expect(TaskPermissions.canChangeStatus('primary'), isTrue);
    expect(TaskPermissions.canChangeStatus('editor'), isTrue);
    expect(TaskPermissions.canChangeStatus('assignee'), isTrue);
    expect(TaskPermissions.canChangeStatus('viewer'), isFalse);
    expect(TaskPermissions.canChangeStatus(null), isFalse);
  });

  test('chỉ creator được quản lý giao việc/chia sẻ', () {
    expect(TaskPermissions.canManage('creator'), isTrue);
    expect(TaskPermissions.canManage('primary'), isFalse);
    expect(TaskPermissions.canManage('editor'), isFalse);
    expect(TaskPermissions.canManage('assignee'), isFalse);
    expect(TaskPermissions.canManage('viewer'), isFalse);
    expect(TaskPermissions.canManage(null), isFalse);
  });
}
