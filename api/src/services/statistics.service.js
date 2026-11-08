const Task = require('../models/task.model');
const TaskShare = require('../models/taskShare.model');

const STATUSES = ['Pending', 'InProgress', 'Completed'];

// Công việc người dùng có quyền truy cập: tự tạo, được giao, hoặc được chia sẻ.
// Dùng chung cho các thống kê để con số khớp với danh sách công việc.
async function buildAccessibleFilter(userId) {
  const sharedTaskIds = await TaskShare.distinct('taskId', { userId });
  return {
    $or: [
      { createdBy: userId },
      { assigneeIds: userId },
      { _id: { $in: sharedTaskIds } },
    ],
  };
}

// Thống kê tổng số công việc và số lượng theo từng trạng thái.
async function getTaskStatistics(userId) {
  const base = await buildAccessibleFilter(userId);
  const counts = await Promise.all(
    STATUSES.map((status) => Task.countDocuments({ $and: [base, { status }] }))
  );

  return {
    total: counts.reduce((sum, value) => sum + value, 0),
    byStatus: {
      Pending: counts[0],
      InProgress: counts[1],
      Completed: counts[2],
    },
  };
}

// Việc được giao (nằm trong assigneeIds) và việc đang là phụ trách chính.
async function getAssignmentStatistics(userId) {
  const [assignedCount, primaryCount] = await Promise.all([
    Task.countDocuments({ assigneeIds: userId }),
    Task.countDocuments({ primaryAssigneeId: userId }),
  ]);
  return { assignedCount, primaryCount };
}

// Sắp đến hạn = trong 7 ngày tới (tính từ đầu hôm nay), chưa hoàn thành.
// Quá hạn = hạn đã qua và chưa hoàn thành. Cùng quy ước với dueFilter ở màn danh sách.
async function getDeadlineStatistics(userId, now = new Date()) {
  const base = await buildAccessibleFilter(userId);
  const startOfToday = new Date(now.getFullYear(), now.getMonth(), now.getDate());
  const startOfDayAfter7 = new Date(startOfToday);
  startOfDayAfter7.setDate(startOfDayAfter7.getDate() + 8);

  const [upcomingCount, overdueCount] = await Promise.all([
    Task.countDocuments({
      $and: [
        base,
        { status: { $ne: 'Completed' } },
        { dueDate: { $gte: startOfToday, $lt: startOfDayAfter7 } },
      ],
    }),
    Task.countDocuments({
      $and: [
        base,
        { status: { $ne: 'Completed' } },
        { dueDate: { $ne: null, $lt: now } },
      ],
    }),
  ]);

  return { upcomingCount, overdueCount };
}

module.exports = {
  buildAccessibleFilter,
  getTaskStatistics,
  getAssignmentStatistics,
  getDeadlineStatistics,
};
