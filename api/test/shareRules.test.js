const test = require('node:test');
const assert = require('node:assert/strict');
const { validateSharePermission } = require('../src/utils/shareRules');

test('chấp nhận quyền viewer', () => {
  assert.equal(validateSharePermission('viewer'), 'viewer');
});

test('chấp nhận quyền editor', () => {
  assert.equal(validateSharePermission('editor'), 'editor');
});

test('từ chối quyền khác', () => {
  assert.throws(() => validateSharePermission('owner'), /quyền/i);
});

test('từ chối giá trị rỗng', () => {
  assert.throws(() => validateSharePermission(undefined), /quyền/i);
});
