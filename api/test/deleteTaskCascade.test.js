const test = require('node:test');
const assert = require('node:assert/strict');

const Task = require('../src/models/task.model');
const TaskShare = require('../src/models/taskShare.model');
const Notification = require('../src/models/notification.model');
const EmailLog = require('../src/models/emailLog.model');
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

test('xóa công việc cũng xóa notification và email log liên quan', async () => {
  const taskId = 'task-1';
  const userId = 'user-creator';

  // Giả lập task thuộc quyền creator và không có share.
  Task.findById = async () => ({
    _id: taskId,
    createdBy: userId,
    assigneeIds: [],
    primaryAssigneeId: null,
  });
  Task.findByIdAndDelete = async () => ({});
  TaskShare.findOne = async () => null;

  const deletedFilters = {};
  TaskShare.deleteMany = async (filter) => {
    deletedFilters.shares = filter;
  };
  Notification.deleteMany = async (filter) => {
    deletedFilters.notifications = filter;
  };
  EmailLog.deleteMany = async (filter) => {
    deletedFilters.emailLogs = filter;
  };

  const res = fakeRes();
  await taskController.deleteTask(
    { params: { id: taskId }, user: { _id: userId } },
    res
  );

  assert.equal(res.statusCode, 200);
  assert.deepEqual(deletedFilters.shares, { taskId });
  assert.deepEqual(deletedFilters.notifications, { taskId });
  assert.deepEqual(deletedFilters.emailLogs, { taskId });
});
