require('dotenv').config();
const express = require('express');
const mongoose = require('mongoose');

const app = express();
app.use(express.json());

app.get('/', (req, res) => {
  res.json({ message: 'Server đang chạy' });
});

// Hai route dưới đây chỉ để thử kết nối, không cần schema
app.post('/test', async (req, res) => {
  const result = await mongoose.connection.db
    .collection('test')
    .insertOne(req.body);
  res.json(result);
});

app.get('/test', async (req, res) => {
  const docs = await mongoose.connection.db
    .collection('test')
    .find()
    .toArray();
  res.json(docs);
});

const PORT = process.env.PORT || 3000;

mongoose
  .connect(process.env.MONGODB_URI)
  .then(() => {
    console.log('Đã kết nối MongoDB Atlas');
    app.listen(PORT, () => console.log(`Server chạy tại http://localhost:${PORT}`));
  })
  .catch((err) => {
    console.error('Lỗi kết nối MongoDB:', err.message);
    process.exit(1);
  });