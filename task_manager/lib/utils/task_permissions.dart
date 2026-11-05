class TaskPermissions {
  // Thứ tự quyền phía server: creator > primary > editor > assignee > viewer.
  static const _editRoles = {'creator', 'primary', 'editor'};
  static const _statusRoles = {'creator', 'primary', 'editor', 'assignee'};

  static bool canEdit(String? role) => _editRoles.contains(role);

  static bool canChangeStatus(String? role) => _statusRoles.contains(role);

  // Chỉ người tạo được giao việc, chia sẻ và xóa.
  static bool canManage(String? role) => role == 'creator';
}
