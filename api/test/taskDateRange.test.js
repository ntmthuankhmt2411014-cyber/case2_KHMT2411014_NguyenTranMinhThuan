const test = require('node:test');
const assert = require('node:assert/strict');

const Task = require('../src/models/task.model');
const TaskShare = require('../src/models/taskShare.model');
const taskController = require('../src/controllers/task.controller');

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

function stubCreate() {
  let createdPayload = null;
  Task.create = async (payload) => {
    createdPayload = payload;
    return {
      ...payload,
      _id: 'task-new',
      populate: async () => ({ ...payload, _id: 'task-new' }),
    };
  };
  return () => createdPayload;
}

function stubTaskForUpdate(task) {
  Task.findById = async () => task;
  TaskShare.findOne = async () => null;
}

test('tạo công việc trả 400 khi hạn hoàn thành trước ngày bắt đầu', async () => {
  const getPayload = stubCreate();
  const res = fakeRes();

  await taskController.createTask(
    {
      user: { _id: 'creator-1' },
      body: {
        title: 'Làm slide',
        startDate: '2026-11-08T09:00:00.000Z',
        dueDate: '2026-11-08T08:00:00.000Z',
      },
    },
    res
  );

  assert.equal(res.statusCode, 400);
  assert.match(res.body.message, /sau ngày bắt đầu/);
  assert.equal(getPayload(), null, 'không được tạo task khi ngày giờ không hợp lệ');
});

test('tạo công việc trả 400 khi hạn trùng đúng thời điểm bắt đầu', async () => {
  stubCreate();
  const res = fakeRes();

  await taskController.createTask(
    {
      user: { _id: 'creator-1' },
      body: {
        title: 'Làm slide',
        startDate: '2026-11-08T09:00:00.000Z',
        dueDate: '2026-11-08T09:00:00.000Z',
      },
    },
    res
  );

  assert.equal(res.statusCode, 400);
});

test('tạo công việc thành công khi hạn sau ngày bắt đầu', async () => {
  const getPayload = stubCreate();
  const res = fakeRes();

  await taskController.createTask(
    {
      user: { _id: 'creator-1' },
      body: {
        title: 'Làm slide',
        startDate: '2026-11-08T08:00:00.000Z',
        dueDate: '2026-11-08T09:00:00.000Z',
      },
    },
    res
  );

  assert.equal(res.statusCode, 201);
  assert.equal(getPayload().startDate, '2026-11-08T08:00:00.000Z');
});

test('cập nhật công việc trả 400 khi hạn mới không sau ngày bắt đầu hiện tại', async () => {
  let saved = false;
  const task = {
    _id: 'task-1',
    title: 'Làm slide',
    status: 'Pending',
    createdBy: 'creator-1',
    assigneeIds: [],
    primaryAssigneeId: null,
    startDate: new Date('2026-11-08T08:00:00.000Z'),
    dueDate: new Date('2026-11-08T09:00:00.000Z'),
    async save() {
      saved = true;
    },
    async populate() {
      return task;
    },
  };
  stubTaskForUpdate(task);
  const res = fakeRes();

  await taskController.updateTask(
    {
      params: { id: 'task-1' },
      user: { _id: 'creator-1', fullName: 'A' },
      body: { dueDate: '2026-11-08T07:00:00.000Z' },
    },
    res
  );

  assert.equal(res.statusCode, 400);
  assert.equal(saved, false, 'không được lưu khi ngày giờ không hợp lệ');
});
