// Chỉ cho phép 2 mức quyền chia sẻ đúng theo SPEC.
function validateSharePermission(permission) {
  if (!['viewer', 'editor'].includes(permission)) {
    throw new Error('Quyền chia sẻ không hợp lệ');
  }
  return permission;
}

module.exports = { validateSharePermission };
