const test = require('node:test');
const assert = require('node:assert/strict');

const Task = require('../src/models/task.model');
const TaskShare = require('../src/models/taskShare.model');
const taskActivityService = require('../src/services/taskActivity.service');
const taskEventService = require('../src/services/taskEvent.service');
const taskController = require('../src/controllers/task.controller');

// Dựng response giả để không cần Express/DB thật.
function fakeRes() {
  return {
    statusCode: null,
    body: null,
    status(code) {
      this.statusCode = code;
      return this;
    },
    json(payload) {
      this.body = payload;
      return this;
    },
  };
}

// Thay service ghi lịch sử bằng hàm gom payload để kiểm tra.
function captureActivities() {
  const logged = [];
  taskActivityService.logActivity = async (payload) => {
    logged.push(payload);
  };
  return logged;
}

// Task giả dùng cho updateTask / updateTaskStatus.
function buildTask(overrides = {}) {
  const task = {
    _id: 'task-1',
    title: 'Tiêu đề cũ',
    description: '',
    category: 'Other',
    priority: 'Medium',
    status: 'Pending',
    startDate: null,
    dueDate: null,
    createdBy: 'creator-1',
    assigneeIds: [],
    primaryAssigneeId: null,
    async save() {},
    async populate() {
      return task;
    },
    ...overrides,
  };
  Task.findById = async () => task;
  TaskShare.findOne = async () => null;
  // Không chạy thật nghiệp vụ thông báo/email trong test này.
  taskEventService.emitTaskEvent = async () => ({
    recipientCount: 0,
    notificationCount: 0,
    emailCount: 0,
  });
  return task;
}

test('tạo công việc ghi hoạt động created', async () => {
  Task.create = async (payload) => ({
    ...payload,
    _id: 'task-new',
    populate: async () => ({ ...payload, _id: 'task-new' }),
  });
  const logged = captureActivities();

  const res = fakeRes();
  await taskController.createTask(
    { user: { _id: 'creator-1' }, body: { title: 'Làm slide' } },
    res
  );

  assert.equal(res.statusCode, 201);
  assert.equal(logged.length, 1);
  assert.equal(logged[0].taskId, 'task-new');
  assert.equal(logged[0].userId, 'creator-1');
  assert.equal(logged[0].action, 'created');
  assert.deepEqual(logged[0].details, { title: 'Làm slide' });
});

test('đổi trạng thái qua PATCH ghi hoạt động status_changed', async () => {
  buildTask({ status: 'Pending' });
  const logged = captureActivities();

  const res = fakeRes();
  await taskController.updateTaskStatus(
    {
      params: { id: 'task-1' },
      user: { _id: 'creator-1', fullName: 'A' },
      body: { status: 'InProgress' },
    },
    res
  );

  assert.equal(res.statusCode, 200);
  assert.equal(logged.length, 1);
  assert.equal(logged[0].action, 'status_changed');
  assert.deepEqual(logged[0].details, { from: 'Pending', to: 'InProgress' });
});

test('sửa tiêu đề qua PUT ghi hoạt động updated với changes', async () => {
  buildTask();
  const logged = captureActivities();

  const res = fakeRes();
  await taskController.updateTask(
    {
      params: { id: 'task-1' },
      user: { _id: 'creator-1', fullName: 'A' },
      body: { title: 'Tiêu đề mới' },
    },
    res
  );

  assert.equal(res.statusCode, 200);
  assert.equal(logged.length, 1);
  assert.equal(logged[0].action, 'updated');
  assert.deepEqual(logged[0].details.changes.title, {
    from: 'Tiêu đề cũ',
    to: 'Tiêu đề mới',
  });
});

test('đổi trạng thái qua PUT ghi status_changed kèm changes', async () => {
  buildTask({ status: 'Pending' });
  const logged = captureActivities();

  const res = fakeRes();
  await taskController.updateTask(
    {
      params: { id: 'task-1' },
      user: { _id: 'creator-1', fullName: 'A' },
      body: { status: 'InProgress' },
    },
    res
  );

  assert.equal(res.statusCode, 200);
  assert.equal(logged.length, 1);
  assert.equal(logged[0].action, 'status_changed');
  assert.equal(logged[0].details.from, 'Pending');
  assert.equal(logged[0].details.to, 'InProgress');
  assert.deepEqual(logged[0].details.changes.status, {
    from: 'Pending',
    to: 'InProgress',
  });
});

test('PUT không có thay đổi thì không ghi hoạt động', async () => {
  buildTask();
  const logged = captureActivities();

  const res = fakeRes();
  await taskController.updateTask(
    {
      params: { id: 'task-1' },
      user: { _id: 'creator-1', fullName: 'A' },
      body: {},
    },
    res
  );

  assert.equal(res.statusCode, 200);
  assert.equal(logged.length, 0);
});
