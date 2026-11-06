const express = require('express');
const router = express.Router();
const controller = require('../controllers/notification.controller');
const authMiddleware = require('../middleware/auth.middleware');

// Tất cả API thông báo đều yêu cầu đăng nhập.
router.use(authMiddleware);

router.get('/', controller.getNotifications);
router.get('/unread-count', controller.getUnreadCount);
router.patch('/read-all', controller.markAllRead);
router.patch('/:id/read', controller.markRead);

module.exports = router;
