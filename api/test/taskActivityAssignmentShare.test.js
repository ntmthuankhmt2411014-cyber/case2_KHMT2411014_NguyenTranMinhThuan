const test = require('node:test');
const assert = require('node:assert/strict');

const Task = require('../src/models/task.model');
const TaskShare = require('../src/models/taskShare.model');
const User = require('../src/models/user.model');
const taskActivityService = require('../src/services/taskActivity.service');
const taskEventService = require('../src/services/taskEvent.service');
const assigneeController = require('../src/controllers/assignee.controller');
const shareController = require('../src/controllers/share.controller');

// ObjectId hợp lệ để đi qua isValidId.
const TASK_ID = '507f1f77bcf86cd799439011';
const CREATOR = '507f1f77bcf86cd799439012';
const USER_1 = '507f1f77bcf86cd799439013';
const USER_2 = '507f1f77bcf86cd799439014';
const SHARE_ID = '507f1f77bcf86cd799439015';

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

// Không chạy thật thông báo/email và trả về kết quả rỗng.
function stubEvents() {
  taskEventService.emitTaskEvent = async () => ({
    recipientCount: 0,
    notificationCount: 0,
    emailCount: 0,
  });
}

// Task giả cho các thao tác giao việc.
function buildAssigneeTask(overrides = {}) {
  const task = {
    _id: TASK_ID,
    title: 'Làm slide',
    createdBy: CREATOR,
    assigneeIds: [],
    primaryAssigneeId: null,
    async save() {},
    ...overrides,
  };
  return task;
}

// Khi giao việc, controller gọi Task.findById lần hai để populate danh sách trả về.
// Lần hai phải trả về object có .populate() đồng bộ (giống query của Mongoose).
function stubFindByIdSequence(task, populated) {
  let calls = 0;
  Task.findById = () => {
    calls += 1;
    if (calls === 1) return task;

    const chain = {
      assigneeIds: populated.assigneeIds,
      primaryAssigneeId: populated.primaryAssigneeId,
      populate() {
        return chain;
      },
    };
    return chain;
  };
  return () => calls;
}

test('giao việc ghi hoạt động assigned cho người mới', async () => {
  const task = buildAssigneeTask();
  stubFindByIdSequence(task, {
    assigneeIds: [{ _id: USER_2 }],
    primaryAssigneeId: { _id: USER_2 },
  });
  TaskShare.findOne = async () => null;
  User.find = () => ({ select: async () => [{ _id: USER_2 }] });
  stubEvents();
  const logged = captureActivities();

  const res = fakeRes();
  await assigneeController.assignUsers(
    {
      params: { id: TASK_ID },
      user: { _id: CREATOR, fullName: 'A' },
      body: { userIds: [USER_2] },
    },
    res
  );

  assert.equal(res.statusCode, 200);
  assert.equal(logged.length, 1);
  assert.equal(logged[0].action, 'assigned');
  assert.deepEqual(logged[0].details, {
    userIds: [USER_2],
    primaryAssigneeId: USER_2,
  });
});

test('giao lại người đã có sẵn thì không ghi hoạt động', async () => {
  const task = buildAssigneeTask({
    assigneeIds: [USER_1],
    primaryAssigneeId: USER_1,
  });
  stubFindByIdSequence(task, {
    assigneeIds: [{ _id: USER_1 }],
    primaryAssigneeId: { _id: USER_1 },
  });
  TaskShare.findOne = async () => null;
  User.find = () => ({ select: async () => [{ _id: USER_1 }] });
  stubEvents();
  const logged = captureActivities();

  const res = fakeRes();
  await assigneeController.assignUsers(
    {
      params: { id: TASK_ID },
      user: { _id: CREATOR, fullName: 'A' },
      body: { userIds: [USER_1] },
    },
    res
  );

  assert.equal(res.statusCode, 200);
  assert.equal(logged.length, 0);
});

test('đổi người phụ trách chính ghi primary_changed với from/to', async () => {
  const task = buildAssigneeTask({
    assigneeIds: [USER_1, USER_2],
    primaryAssigneeId: USER_1,
  });
  Task.findById = async () => task;
  TaskShare.findOne = async () => null;
  stubEvents();
  const logged = captureActivities();

  const res = fakeRes();
  await assigneeController.setPrimaryAssignee(
    {
      params: { id: TASK_ID, userId: USER_2 },
      user: { _id: CREATOR, fullName: 'A' },
      body: {},
    },
    res
  );

  assert.equal(res.statusCode, 200);
  assert.equal(logged.length, 1);
  assert.equal(logged[0].action, 'primary_changed');
  assert.deepEqual(logged[0].details, { from: USER_1, to: USER_2 });
});

test('hủy giao việc ghi assignee_removed', async () => {
  const task = buildAssigneeTask({
    assigneeIds: [USER_1, USER_2],
    primaryAssigneeId: USER_1,
  });
  stubFindByIdSequence(task, {
    assigneeIds: [{ _id: USER_2 }],
    primaryAssigneeId: { _id: USER_2 },
  });
  TaskShare.findOne = async () => null;
  stubEvents();
  const logged = captureActivities();

  const res = fakeRes();
  await assigneeController.removeAssignee(
    {
      params: { id: TASK_ID, userId: USER_1 },
      user: { _id: CREATOR, fullName: 'A' },
    },
    res
  );

  assert.equal(res.statusCode, 200);
  assert.equal(logged.length, 1);
  assert.equal(logged[0].action, 'assignee_removed');
  assert.deepEqual(logged[0].details, { userId: USER_1 });
});

// Chain giả cho TaskShare.find: dùng được cả .select() và .populate().sort().
function stubShareFind(existing = [], shares = []) {
  TaskShare.find = () => {
    const chain = {
      select: async () => existing,
      populate() {
        return chain;
      },
      sort: async () => shares,
    };
    return chain;
  };
}

test('chia sẻ người mới ghi shared với permission', async () => {
  const task = buildAssigneeTask();
  Task.findById = async () => task;
  TaskShare.findOne = async () => null;
  stubShareFind([], []);
  TaskShare.findOneAndUpdate = async () => ({});
  User.find = () => ({ select: async () => [{ _id: USER_2 }] });
  stubEvents();
  const logged = captureActivities();

  const res = fakeRes();
  await shareController.shareUsers(
    {
      params: { id: TASK_ID },
      user: { _id: CREATOR, fullName: 'A' },
      body: { userIds: [USER_2], permission: 'viewer' },
    },
    res
  );

  assert.equal(res.statusCode, 200);
  assert.equal(logged.length, 1);
  assert.equal(logged[0].action, 'shared');
  assert.deepEqual(logged[0].details, { userIds: [USER_2], permission: 'viewer' });
});

test('đổi quyền chia sẻ ghi permission_changed với from/to', async () => {
  const task = buildAssigneeTask();
  Task.findById = async () => task;
  TaskShare.findOne = async () => null;

  const share = {
    userId: USER_2,
    permission: 'viewer',
    async save() {},
    async populate() {
      return share;
    },
  };
  TaskShare.findOne = async (filter) => {
    // Lần đầu là kiểm tra quyền của người thao tác, lần sau là bản ghi chia sẻ.
    if (filter && filter._id) return share;
    return null;
  };
  stubEvents();
  const logged = captureActivities();

  const res = fakeRes();
  await shareController.updateSharePermission(
    {
      params: { id: TASK_ID, shareId: SHARE_ID },
      user: { _id: CREATOR, fullName: 'A' },
      body: { permission: 'editor' },
    },
    res
  );

  assert.equal(res.statusCode, 200);
  assert.equal(logged.length, 1);
  assert.equal(logged[0].action, 'permission_changed');
  assert.deepEqual(logged[0].details, {
    userId: USER_2,
    from: 'viewer',
    to: 'editor',
  });
});

test('thu hồi quyền chia sẻ ghi share_removed', async () => {
  const task = buildAssigneeTask();
  Task.findById = async () => task;
  TaskShare.findOne = async () => null;
  TaskShare.findOneAndDelete = async () => ({
    userId: USER_2,
    permission: 'editor',
  });
  stubEvents();
  const logged = captureActivities();

  const res = fakeRes();
  await shareController.removeShare(
    {
      params: { id: TASK_ID, shareId: SHARE_ID },
      user: { _id: CREATOR, fullName: 'A' },
    },
    res
  );

  assert.equal(res.statusCode, 200);
  assert.equal(logged.length, 1);
  assert.equal(logged[0].action, 'share_removed');
  assert.deepEqual(logged[0].details, { userId: USER_2, permission: 'editor' });
});
