const test = require('node:test');
const assert = require('node:assert/strict');
const { resolvePrimaryAssignee } = require('../src/utils/assigneeRules');

test('người phụ trách chính được yêu cầu thắng nếu còn trong danh sách', () => {
  assert.equal(resolvePrimaryAssignee(['a', 'b'], 'a', 'b'), 'b');
});

test('giữ nguyên phụ trách chính hiện tại nếu không có yêu cầu mới', () => {
  assert.equal(resolvePrimaryAssignee(['a', 'b'], 'b', null), 'b');
});

test('chọn người đầu tiên nếu chưa có phụ trách chính', () => {
  assert.equal(resolvePrimaryAssignee(['a', 'b'], null, null), 'a');
});

test('trả null nếu danh sách rỗng', () => {
  assert.equal(resolvePrimaryAssignee([], 'a', null), null);
});

test('báo lỗi nếu phụ trách chính không nằm trong danh sách', () => {
  assert.throws(
    () => resolvePrimaryAssignee(['a', 'b'], null, 'c'),
    /phụ trách chính/i
  );
});
