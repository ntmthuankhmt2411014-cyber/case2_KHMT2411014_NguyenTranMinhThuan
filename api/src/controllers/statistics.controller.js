const statisticsService = require('../services/statistics.service');

// Bọc một hàm thống kê thành Express handler: luôn trả 200 hoặc 500,
// không để lỗi DB làm sập request.
function handle(methodName) {
  return async (req, res) => {
    try {
      const data = await statisticsService[methodName](req.user._id);
      return res.status(200).json(data);
    } catch (error) {
      console.error('Lỗi thống kê:', error);
      return res.status(500).json({ message: 'Lỗi server khi lấy thống kê' });
    }
  };
}

module.exports = {
  getTaskStatistics: handle('getTaskStatistics'),
  getAssignmentStatistics: handle('getAssignmentStatistics'),
  getDeadlineStatistics: handle('getDeadlineStatistics'),
};
