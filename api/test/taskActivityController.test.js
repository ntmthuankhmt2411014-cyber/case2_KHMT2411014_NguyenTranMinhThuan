const test = require('node:test');
const assert = require('node:assert/strict');

const Task = require('../src/models/task.model');
const TaskShare = require('../src/models/taskShare.model');
const taskActivityService = require('../src/services/taskActivity.service');
const taskActivityController = require('../src/controllers/taskActivity.controller');

const TASK_ID = '507f1f77bcf86cd799439011';
const CREATOR = '507f1f77bcf86cd799439012';
const OTHER_USER = '507f1f77bcf86cd799439013';

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

function buildTask(overrides = {}) {
  return {
    _id: TASK_ID,
    title: 'Làm slide',
    createdBy: CREATOR,
    assigneeIds: [],
    primaryAssigneeId: null,
    ...overrides,
  };
}

test('trả 400 khi id công việc không hợp lệ', async () => {
  const res = fakeRes();
  await taskActivityController.getTaskActivities(
    { params: { id: 'khong-hop-le' }, user: { _id: CREATOR } },
    res
  );

  assert.equal(res.statusCode, 400);
});

test('trả 404 khi công việc đã bị xóa', async () => {
  Task.findById = async () => null;
  const res = fakeRes();
  await taskActivityController.getTaskActivities(
    { params: { id: TASK_ID }, user: { _id: CREATOR } },
    res
  );

  assert.equal(res.statusCode, 404);
});

test('trả 403 khi người dùng không có quyền xem', async () => {
  Task.findById = async () => buildTask();
  TaskShare.findOne = async () => null;

  const res = fakeRes();
  await taskActivityController.getTaskActivities(
    { params: { id: TASK_ID }, user: { _id: OTHER_USER } },
    res
  );

  assert.equal(res.statusCode, 403);
});

test('trả danh sách hoạt động cho người tạo công việc', async () => {
  Task.findById = async () => buildTask();
  TaskShare.findOne = async () => null;
  taskActivityService.listTaskActivities = async () => [
    { _id: 'a1', action: 'created', details: { title: 'Làm slide' } },
  ];

  const res = fakeRes();
  await taskActivityController.getTaskActivities(
    { params: { id: TASK_ID }, user: { _id: CREATOR } },
    res
  );

  assert.equal(res.statusCode, 200);
  assert.equal(res.body.activities.length, 1);
  assert.equal(res.body.activities[0].action, 'created');
});

test('người chỉ được chia sẻ quyền viewer vẫn xem được hoạt động', async () => {
  Task.findById = async () => buildTask();
  TaskShare.findOne = async () => ({ permission: 'viewer' });
  taskActivityService.listTaskActivities = async () => [];

  const res = fakeRes();
  await taskActivityController.getTaskActivities(
    { params: { id: TASK_ID }, user: { _id: OTHER_USER } },
    res
  );

  assert.equal(res.statusCode, 200);
  assert.deepEqual(res.body.activities, []);
});

test('trả 500 khi service đọc lịch sử lỗi', async () => {
  Task.findById = async () => buildTask();
  TaskShare.findOne = async () => null;
  taskActivityService.listTaskActivities = async () => {
    throw new Error('db down');
  };
  const originalError = console.error;
  console.error = () => {};

  const res = fakeRes();
  try {
    await taskActivityController.getTaskActivities(
      { params: { id: TASK_ID }, user: { _id: CREATOR } },
      res
    );
  } finally {
    console.error = originalError;
  }

  assert.equal(res.statusCode, 500);
});
