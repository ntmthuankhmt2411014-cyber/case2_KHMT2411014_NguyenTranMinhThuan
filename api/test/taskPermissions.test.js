const test = require('node:test');
const assert = require('node:assert/strict');
const { getTaskAccess } = require('../src/utils/taskPermissions');

const task = {
  createdBy: 'creator-id',
  assigneeIds: ['primary-id', 'assignee-id'],
  primaryAssigneeId: 'primary-id',
};

test('người tạo có toàn quyền', () => {
  const access = getTaskAccess(task, 'creator-id', null);
  assert.equal(access.role, 'creator');
  assert.equal(access.canEdit, true);
  assert.equal(access.canChangeStatus, true);
  assert.equal(access.canDelete, true);
  assert.equal(access.canAssign, true);
  assert.equal(access.canManageShares, true);
});

test('phụ trách chính được sửa nhưng không được xóa/giao/chia sẻ', () => {
  const access = getTaskAccess(task, 'primary-id', null);
  assert.equal(access.role, 'primary');
  assert.equal(access.canEdit, true);
  assert.equal(access.canChangeStatus, true);
  assert.equal(access.canDelete, false);
});

test('người được giao khác chỉ đổi trạng thái', () => {
  const access = getTaskAccess(task, 'assignee-id', null);
  assert.equal(access.role, 'assignee');
  assert.equal(access.canEdit, false);
  assert.equal(access.canChangeStatus, true);
});

test('editor được sửa và đổi trạng thái', () => {
  const access = getTaskAccess(task, 'editor-id', { permission: 'editor' });
  assert.equal(access.role, 'editor');
  assert.equal(access.canEdit, true);
  assert.equal(access.canChangeStatus, true);
  assert.equal(access.canManageShares, false);
});

test('viewer chỉ xem', () => {
  const access = getTaskAccess(task, 'viewer-id', { permission: 'viewer' });
  assert.equal(access.role, 'viewer');
  assert.equal(access.canView, true);
  assert.equal(access.canEdit, false);
  assert.equal(access.canChangeStatus, false);
});

test('người vừa được giao vừa được chia sẻ viewer lấy quyền assignee', () => {
  const access = getTaskAccess(task, 'assignee-id', { permission: 'viewer' });
  assert.equal(access.role, 'assignee');
  assert.equal(access.canChangeStatus, true);
  assert.equal(access.canEdit, false);
});

test('editor thắng quyền assignee khi trùng', () => {
  const access = getTaskAccess(task, 'assignee-id', { permission: 'editor' });
  assert.equal(access.role, 'editor');
  assert.equal(access.canEdit, true);
});

test('người không liên quan không có quyền xem', () => {
  const access = getTaskAccess(task, 'stranger-id', null);
  assert.equal(access.role, null);
  assert.equal(access.canView, false);
});
