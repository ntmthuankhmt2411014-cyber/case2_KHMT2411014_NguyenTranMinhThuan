require('dotenv').config();
const express = require('express');
const mongoose = require('mongoose');

const app = express();
app.use(express.json());

const taskRoutes = require('./routes/task.routes');
app.use('/api/tasks', taskRoutes);


app.get('/', (req, res) => {
  res.json({ message: 'Server đang chạy' });
});


const PORT = process.env.PORT || 3000;

mongoose
  .connect(process.env.MONGODB_URI)
  .then(() => {
    console.log('MongoDB connected, database:', mongoose.connection.name);
    app.listen(PORT, () => console.log(`Server chạy tại http://localhost:${PORT}`));
  })
  .catch((err) => {
    console.error('Lỗi kết nối MongoDB:', err.message);
    process.exit(1);
  });