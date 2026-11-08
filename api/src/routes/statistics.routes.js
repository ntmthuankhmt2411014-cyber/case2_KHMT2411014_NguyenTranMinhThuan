const express = require('express');
const router = express.Router();
const authMiddleware = require('../middleware/auth.middleware');
const statisticsController = require('../controllers/statistics.controller');

// Tất cả API thống kê đều yêu cầu xác thực.
router.use(authMiddleware);

router.get('/tasks', statisticsController.getTaskStatistics);
router.get('/assignments', statisticsController.getAssignmentStatistics);
router.get('/deadlines', statisticsController.getDeadlineStatistics);

module.exports = router;
