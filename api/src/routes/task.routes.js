const express = require('express');
const router = express.Router();
const taskController = require('../controllers/task.controller');
const assigneeController = require('../controllers/assignee.controller');
const shareController = require('../controllers/share.controller');
const emailLogController = require('../controllers/emailLog.controller');
const taskActivityController = require('../controllers/taskActivity.controller');
const authMiddleware = require('../middleware/auth.middleware');

// Tất cả route đều yêu cầu xác thực
router.use(authMiddleware);

router.post('/', taskController.createTask);
router.get('/', taskController.getTasks);
router.get('/:id', taskController.getTaskById);
router.put('/:id', taskController.updateTask);
router.patch('/:id/status', taskController.updateTaskStatus);
router.delete('/:id', taskController.deleteTask);

// Giao việc
router.get('/:id/assignees', assigneeController.getAssignees);
router.post('/:id/assignees', assigneeController.assignUsers);
router.patch('/:id/assignees/:userId', assigneeController.setPrimaryAssignee);
router.delete('/:id/assignees/:userId', assigneeController.removeAssignee);

// Chia sẻ
router.get('/:id/shares', shareController.getShares);
router.post('/:id/shares', shareController.shareUsers);
router.patch('/:id/shares/:shareId', shareController.updateSharePermission);
router.delete('/:id/shares/:shareId', shareController.removeShare);

// Lịch sử gửi email của công việc (chỉ người tạo)
router.get('/:id/email-logs', emailLogController.getTaskEmailLogs);

// Lịch sử hoạt động của công việc
router.get('/:id/activities', taskActivityController.getTaskActivities);

module.exports = router;
