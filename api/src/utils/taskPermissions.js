// Xác định vai trò và quyền của một người dùng trên một công việc.
// task có thể là plain object hoặc Mongoose document; các trường id có thể là
// ObjectId, string, hoặc object đã populate (có _id).
function idOf(value) {
  if (!value) return null;
  if (typeof value === 'string') return value;
  if (value._id) return value._id.toString();
  return value.toString();
}

function getTaskAccess(task, userId, share) {
  const uid = userId.toString();
  const isCreator = idOf(task.createdBy) === uid;
  const isPrimary = idOf(task.primaryAssigneeId) === uid;
  const isAssignee = (task.assigneeIds || []).some((id) => idOf(id) === uid);
  const sharePermission = share ? share.permission : null;

  // Thứ tự ưu tiên: creator > primary > editor > assignee > viewer.
  let role = null;
  if (isCreator) role = 'creator';
  else if (isPrimary) role = 'primary';
  else if (sharePermission === 'editor') role = 'editor';
  else if (isAssignee) role = 'assignee';
  else if (sharePermission === 'viewer') role = 'viewer';

  return {
    role,
    canView: role !== null,
    canEdit: ['creator', 'primary', 'editor'].includes(role),
    canChangeStatus: ['creator', 'primary', 'editor', 'assignee'].includes(role),
    canDelete: role === 'creator',
    canAssign: role === 'creator',
    canManageShares: role === 'creator',
  };
}

module.exports = { getTaskAccess };
