const express = require('express');
const router = express.Router();
const taskController = require('../controllers/task.controller');
const authMiddleware = require('../middleware/auth.middleware');

// Tất cả route đều yêu cầu xác thực
router.use(authMiddleware);

router.post('/', taskController.createTask);
router.get('/', taskController.getTasks);
router.get('/:id', taskController.getTaskById);
router.put('/:id', taskController.updateTask);
router.patch('/:id/status', taskController.updateTaskStatus);
router.delete('/:id', taskController.deleteTask);

module.exports = router;
