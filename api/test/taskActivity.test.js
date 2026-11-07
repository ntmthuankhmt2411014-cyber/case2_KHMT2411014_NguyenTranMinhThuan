const test = require('node:test');
const assert = require('node:assert/strict');

const TaskActivity = require('../src/models/taskActivity.model');
const taskActivityService = require('../src/services/taskActivity.service');

test('task activity model có đủ trường theo SPEC', () => {
  for (const field of ['taskId', 'userId', 'action', 'details', 'createdAt']) {
    assert.ok(TaskActivity.schema.paths[field], `thiếu trường ${field}`);
  }
  assert.equal(TaskActivity.collection.collectionName, 'task_activities');
});

test('logActivity ghi đúng dữ liệu', async () => {
  const originalCreate = TaskActivity.create;
  let payload = null;
  TaskActivity.create = async (doc) => {
    payload = doc;
  };

  try {
    await taskActivityService.logActivity({
      taskId: 'task-1',
      userId: 'user-1',
      action: 'created',
      details: { title: 'Làm slide' },
    });
  } finally {
    TaskActivity.create = originalCreate;
  }

  assert.deepEqual(payload, {
    taskId: 'task-1',
    userId: 'user-1',
    action: 'created',
    details: { title: 'Làm slide' },
  });
});

test('logActivity không ném lỗi khi ghi DB thất bại', async () => {
  const originalCreate = TaskActivity.create;
  const originalError = console.error;
  TaskActivity.create = async () => {
    throw new Error('db down');
  };
  console.error = () => {};

  try {
    await assert.doesNotReject(() =>
      taskActivityService.logActivity({
        taskId: 'task-1',
        userId: 'user-1',
        action: 'updated',
      })
    );
  } finally {
    TaskActivity.create = originalCreate;
    console.error = originalError;
  }
});

test('logActivity mặc định details là object rỗng', async () => {
  const originalCreate = TaskActivity.create;
  let payload = null;
  TaskActivity.create = async (doc) => {
    payload = doc;
  };

  try {
    await taskActivityService.logActivity({
      taskId: 'task-1',
      userId: 'user-1',
      action: 'updated',
    });
  } finally {
    TaskActivity.create = originalCreate;
  }

  assert.deepEqual(payload.details, {});
});
