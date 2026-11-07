const test = require('node:test');
const assert = require('node:assert/strict');

const Notification = require('../src/models/notification.model');
const User = require('../src/models/user.model');
const TaskShare = require('../src/models/taskShare.model');
const notificationService = require('../src/services/notification.service');
const emailService = require('../src/services/email.service');
const taskEventService = require('../src/services/taskEvent.service');

const TASK = {
  _id: 'task-1',
  title: 'Làm slide',
  createdBy: 'creator-1',
  assigneeIds: ['assignee-1'],
};

test('không phát lại task_completed nếu task đã từng gửi thông báo hoàn thành', async () => {
  Notification.exists = async () => ({ _id: 'notif-cu' });

  let shareQueried = false;
  TaskShare.find = () => {
    shareQueried = true;
    return { distinct: async () => [] };
  };
  User.find = () => ({ select: async () => [] });

  const result = await taskEventService.emitTaskEvent({
    task: TASK,
    actorId: 'assignee-1',
    actorName: 'B',
    eventType: 'task_completed',
  });

  assert.deepEqual(result, {
    recipientCount: 0,
    notificationCount: 0,
    emailCount: 0,
  });
  assert.equal(shareQueried, false, 'phải dừng trước khi truy vấn người nhận');
});

test('vẫn phát task_completed khi chưa từng gửi thông báo hoàn thành', async () => {
  Notification.exists = async () => null;
  TaskShare.find = () => ({ distinct: async () => [] });
  User.find = () => ({
    select: async () => [
      { _id: 'creator-1', fullName: 'A', email: 'a@example.com' },
    ],
  });

  const createdNotifications = [];
  notificationService.createNotifications = async (payload) => {
    createdNotifications.push(payload);
    return [];
  };
  emailService.queueAndSendEmail = async () => ({ status: 'sent' });

  const result = await taskEventService.emitTaskEvent({
    task: TASK,
    actorId: 'assignee-1',
    actorName: 'B',
    eventType: 'task_completed',
  });

  assert.equal(result.recipientCount, 1);
  assert.equal(result.notificationCount, 1);
  assert.equal(result.emailCount, 1);
  assert.equal(createdNotifications.length, 1);
  assert.equal(createdNotifications[0].type, 'task_completed');
});
