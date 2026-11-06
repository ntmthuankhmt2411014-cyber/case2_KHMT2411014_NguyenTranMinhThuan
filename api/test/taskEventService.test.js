const test = require('node:test');
const assert = require('node:assert/strict');
const taskEventService = require('../src/services/taskEvent.service');

test('emitForRecipients với danh sách người nhận rỗng trả về 0 và không lỗi', async () => {
  const result = await taskEventService.emitForRecipients({
    task: { title: 'Test Task' },
    recipientIds: [],
    eventType: 'task_assigned',
    actorName: 'Minh',
  });

  assert.deepEqual(result, {
    recipientCount: 0,
    notificationCount: 0,
    emailCount: 0,
  });
});
