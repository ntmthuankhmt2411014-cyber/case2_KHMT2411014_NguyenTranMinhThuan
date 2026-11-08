const test = require('node:test');
const assert = require('node:assert/strict');

const Task = require('../src/models/task.model');
const TaskShare = require('../src/models/taskShare.model');
const statisticsService = require('../src/services/statistics.service');
const statisticsController = require('../src/controllers/statistics.controller');

const USER_ID = '507f1f77bcf86cd799439011';

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

test('thống kê trạng thái trả tổng và số lượng từng trạng thái', async () => {
  TaskShare.distinct = async () => ['shared-1'];
  Task.countDocuments = async (filter) => {
    const status = filter.$and[1].status;
    if (status === 'Pending') return 2;
    if (status === 'InProgress') return 3;
    return 1;
  };

  const result = await statisticsService.getTaskStatistics(USER_ID);

  assert.deepEqual(result, {
    total: 6,
    byStatus: { Pending: 2, InProgress: 3, Completed: 1 },
  });
});

test('thống kê trạng thái trả 0 khi người dùng chưa có công việc', async () => {
  TaskShare.distinct = async () => [];
  Task.countDocuments = async () => 0;

  const result = await statisticsService.getTaskStatistics(USER_ID);

  assert.deepEqual(result, {
    total: 0,
    byStatus: { Pending: 0, InProgress: 0, Completed: 0 },
  });
});

test('bộ lọc quyền truy cập gồm tạo, được giao và được chia sẻ', async () => {
  TaskShare.distinct = async (field, filter) => {
    assert.equal(field, 'taskId');
    assert.deepEqual(filter, { userId: USER_ID });
    return ['shared-1'];
  };

  const filter = await statisticsService.buildAccessibleFilter(USER_ID);

  assert.deepEqual(filter, {
    $or: [
      { createdBy: USER_ID },
      { assigneeIds: USER_ID },
      { _id: { $in: ['shared-1'] } },
    ],
  });
});

test('thống kê giao việc đếm assigned và primary', async () => {
  const filters = [];
  Task.countDocuments = async (filter) => {
    filters.push(filter);
    return filter.primaryAssigneeId ? 1 : 4;
  };

  const result = await statisticsService.getAssignmentStatistics(USER_ID);

  assert.deepEqual(result, { assignedCount: 4, primaryCount: 1 });
  assert.deepEqual(filters[0], { assigneeIds: USER_ID });
  assert.deepEqual(filters[1], { primaryAssigneeId: USER_ID });
});

test('thống kê hạn chót loại việc hoàn thành và trả đúng số lượng', async () => {
  TaskShare.distinct = async () => [];
  const filters = [];
  Task.countDocuments = async (filter) => {
    filters.push(filter);
    return filters.length === 1 ? 2 : 1;
  };

  const result = await statisticsService.getDeadlineStatistics(
    USER_ID,
    new Date('2026-11-07T10:00:00.000Z')
  );

  assert.deepEqual(result, { upcomingCount: 2, overdueCount: 1 });
  assert.equal(filters[0].$and[1].status.$ne, 'Completed');
  assert.equal(filters[1].$and[1].status.$ne, 'Completed');
});

test('controller trả 200 với dữ liệu thống kê', async () => {
  statisticsService.getTaskStatistics = async () => ({
    total: 1,
    byStatus: { Pending: 1, InProgress: 0, Completed: 0 },
  });

  const res = fakeRes();
  await statisticsController.getTaskStatistics({ user: { _id: USER_ID } }, res);

  assert.equal(res.statusCode, 200);
  assert.equal(res.body.total, 1);
});

test('controller trả 500 khi service lỗi', async () => {
  statisticsService.getDeadlineStatistics = async () => {
    throw new Error('db down');
  };
  const originalError = console.error;
  console.error = () => {};

  const res = fakeRes();
  try {
    await statisticsController.getDeadlineStatistics({ user: { _id: USER_ID } }, res);
  } finally {
    console.error = originalError;
  }

  assert.equal(res.statusCode, 500);
  assert.match(res.body.message, /Lỗi server/);
});
