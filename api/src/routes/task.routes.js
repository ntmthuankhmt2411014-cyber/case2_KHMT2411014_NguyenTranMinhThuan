const express = require('express');
const router = express.Router();
const taskController = require('../controllers/task.controller');
const assigneeController = require('../controllers/assignee.controller');
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

module.exports = router;
