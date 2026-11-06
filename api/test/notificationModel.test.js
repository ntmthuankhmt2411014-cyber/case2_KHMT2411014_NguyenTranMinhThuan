const test = require('node:test');
const assert = require('node:assert/strict');
const Notification = require('../src/models/notification.model');
const EmailLog = require('../src/models/emailLog.model');

const EVENT_TYPES = [
  'task_assigned',
  'task_shared',
  'due_date_changed',
  'task_completed',
  'deadline_reminder',
];

test('notification model có đủ trường theo SPEC', () => {
  const paths = Notification.schema.paths;
  for (const field of ['userId', 'taskId', 'type', 'title', 'message', 'isRead', 'createdAt']) {
    assert.ok(paths[field], `thiếu trường ${field}`);
  }
  assert.equal(paths.isRead.defaultValue, false);
  assert.deepEqual(paths.type.enumValues, EVENT_TYPES);
  assert.equal(typeof paths.createdAt.defaultValue, 'function');
});

test('email log model có đủ trường và mặc định đúng', () => {
  const paths = EmailLog.schema.paths;
  for (const field of [
    'taskId',
    'recipientEmail',
    'eventType',
    'subject',
    'status',
    'attempts',
    'errorMessage',
    'sentAt',
    'createdAt',
  ]) {
    assert.ok(paths[field], `thiếu trường ${field}`);
  }
  assert.equal(paths.status.defaultValue, 'pending');
  assert.deepEqual(paths.status.enumValues, ['pending', 'sent', 'failed']);
  assert.equal(paths.attempts.defaultValue, 0);
  assert.equal(paths.errorMessage.defaultValue, '');
  assert.equal(paths.sentAt.defaultValue, null);
  assert.deepEqual(paths.eventType.enumValues, EVENT_TYPES);
  assert.equal(typeof paths.createdAt.defaultValue, 'function');
});
