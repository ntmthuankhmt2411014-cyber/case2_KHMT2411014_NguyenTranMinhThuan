const test = require('node:test');
const assert = require('node:assert/strict');
const { parseLimit } = require('../src/controllers/notification.controller');

test('parseLimit mặc định 50 khi thiếu hoặc sai', () => {
  assert.equal(parseLimit(undefined), 50);
  assert.equal(parseLimit(''), 50);
  assert.equal(parseLimit('abc'), 50);
});

test('parseLimit kẹp trong khoảng 1..100', () => {
  assert.equal(parseLimit('0'), 1);
  assert.equal(parseLimit('-5'), 1);
  assert.equal(parseLimit('20'), 20);
  assert.equal(parseLimit('500'), 100);
});
