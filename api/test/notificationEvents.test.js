const test = require('node:test');
const assert = require('node:assert/strict');
const {
  EVENT_TYPES,
  resolveRecipientIds,
  buildEventContent,
  hasDueDateChanged,
  isTransitionToCompleted,
  shouldRetryLog,
  isDueWithin,
} = require('../src/utils/notificationEvents');

const task = {
  createdBy: 'creator',
  assigneeIds: ['creator', 'primary', 'other'],
  shareUserIds: ['viewer', 'primary'],
};

test('giao việc chỉ gửi cho người mới, bỏ actor và gộp trùng', () => {
  const ids = resolveRecipientIds({
    ...task,
    actorId: 'creator',
    eventType: EVENT_TYPES.TASK_ASSIGNED,
    targetUserIds: ['new1', 'creator', 'new1'],
  });
  assert.deepEqual(ids, ['new1']);
});

test('đổi hạn gửi cho creator + assignee + share, gộp trùng, bỏ actor', () => {
  const ids = resolveRecipientIds({
    ...task,
    actorId: 'creator',
    eventType: EVENT_TYPES.DUE_DATE_CHANGED,
  });
  assert.deepEqual(ids.sort(), ['other', 'primary', 'viewer']);
});

test('nội dung email giao việc đúng tiếng Việt', () => {
  const content = buildEventContent({
    eventType: EVENT_TYPES.TASK_ASSIGNED,
    actorName: 'Minh',
    taskTitle: 'Báo cáo',
  });
  assert.equal(content.title, 'Bạn được giao công việc mới');
  assert.equal(content.message, 'Minh đã giao cho bạn công việc "Báo cáo".');
  assert.equal(content.subject, '[Task Manager] Bạn được giao công việc: Báo cáo');
});

test('phát hiện đổi hạn và chuyển sang Completed', () => {
  const iso = '2026-11-07T00:00:00.000Z';
  assert.equal(hasDueDateChanged(null, iso), true);
  assert.equal(hasDueDateChanged(iso, iso), false);
  assert.equal(hasDueDateChanged(iso, undefined), false);
  assert.equal(isTransitionToCompleted('Pending', 'Completed'), true);
  assert.equal(isTransitionToCompleted('Completed', 'Completed'), false);
});

test('chỉ retry log failed và attempts < 3', () => {
  assert.equal(shouldRetryLog({ status: 'failed', attempts: 2 }), true);
  assert.equal(shouldRetryLog({ status: 'failed', attempts: 3 }), false);
  assert.equal(shouldRetryLog({ status: 'sent', attempts: 0 }), false);
});

test('cửa sổ nhắc hạn 24 giờ', () => {
  const now = new Date('2026-11-06T00:00:00.000Z');
  assert.equal(
    isDueWithin({ status: 'Pending', dueDate: new Date('2026-11-06T12:00:00.000Z') }, now, 24),
    true
  );
  assert.equal(
    isDueWithin({ status: 'Pending', dueDate: new Date('2026-11-07T06:00:00.000Z') }, now, 24),
    false
  );
  assert.equal(
    isDueWithin({ status: 'Pending', dueDate: new Date('2026-11-05T23:00:00.000Z') }, now, 24),
    false
  );
  assert.equal(
    isDueWithin({ status: 'Completed', dueDate: new Date('2026-11-06T12:00:00.000Z') }, now, 24),
    false
  );
});
