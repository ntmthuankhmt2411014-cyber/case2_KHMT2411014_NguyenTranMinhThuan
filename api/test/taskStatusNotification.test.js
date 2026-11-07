const test = require('node:test');
const assert = require('node:assert/strict');

const Task = require('../src/models/task.model');
const TaskShare = require('../src/models/taskShare.model');
const taskEventService = require('../src/services/taskEvent.service');
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

// Task giả đủ trường để controller và service xử lý mà không cần MongoDB.
function makeTask(status) {
  const task = {
    _id: 'task-1',
    title: 'Làm slide',
    status,
    createdBy: 'creator-1',
    assigneeIds: ['assignee-1'],
    primaryAssigneeId: null,
    async save() {},
    async populate() {
      return task;
    },
  };
  return task;
}

function stubTask(task) {
  Task.findById = async () => task;
  TaskShare.findOne = async () => null;
}

async function changeStatus(task, status) {
  const res = fakeRes();
  await taskController.updateTaskStatus(
    {
      params: { id: task._id },
      user: { _id: 'assignee-1', fullName: 'B' },
      body: { status },
    },
    res
  );
  return res;
}

test('InProgress → Completed phát đúng một sự kiện task_completed', async () => {
  const task = makeTask('InProgress');
  stubTask(task);

  const events = [];
  taskEventService.emitTaskEvent = async (payload) => {
    events.push(payload);
  };

  const res = await changeStatus(task, 'Completed');

  assert.equal(res.statusCode, 200);
  assert.equal(events.length, 1);
  assert.equal(events[0].eventType, 'task_completed');
  assert.equal(events[0].actorId, 'assignee-1');
  assert.equal(events[0].task, task);
});

test('bấm Hoàn thành khi đang Completed không phát lại thông báo', async () => {
  const task = makeTask('Completed');
  stubTask(task);

  const events = [];
  taskEventService.emitTaskEvent = async (payload) => {
    events.push(payload);
  };

  await changeStatus(task, 'Completed');
  await changeStatus(task, 'Completed');

  assert.equal(events.length, 0);
});

test('Completed → InProgress → Completed chỉ phát khi quay lại Completed', async () => {
  const task = makeTask('Completed');
  stubTask(task);

  const events = [];
  taskEventService.emitTaskEvent = async (payload) => {
    events.push(payload);
  };

  await changeStatus(task, 'InProgress');
  assert.equal(events.length, 0, 'mở lại công việc thì chưa phát hoàn thành');

  await changeStatus(task, 'Completed');
  assert.equal(events.length, 1, 'quay lại Completed thì phát một lần');

  await changeStatus(task, 'Completed');
  assert.equal(events.length, 1, 'bấm Hoàn thành lần nữa không phát thêm');
});

test('Completed → Pending không phát thông báo hoàn thành', async () => {
  const task = makeTask('Completed');
  stubTask(task);

  const events = [];
  taskEventService.emitTaskEvent = async (payload) => {
    events.push(payload);
  };

  await changeStatus(task, 'Pending');

  assert.equal(events.length, 0);
});
