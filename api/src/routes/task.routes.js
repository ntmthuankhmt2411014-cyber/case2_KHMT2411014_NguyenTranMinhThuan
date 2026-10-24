const express = require('express');
const Task = require('../models/task.model');

const router = express.Router();

router.get('/', async (req, res) => {
  try {
    const tasks = await Task.find();
    res.status(200).json(tasks);
  } catch (error) {
    console.error(error);
    res.status(500).json({ message: 'Không thể lấy danh sách công việc' });
  }
});

module.exports = router;