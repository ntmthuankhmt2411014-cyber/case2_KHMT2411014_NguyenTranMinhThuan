const express = require('express');
const router = express.Router();
const controller = require('../controllers/emailLog.controller');
const authMiddleware = require('../middleware/auth.middleware');

router.use(authMiddleware);

// Gửi lại email thất bại; controller kiểm tra quyền creator + giới hạn 3 lần.
router.post('/:id/retry', controller.retryEmailLog);

module.exports = router;
