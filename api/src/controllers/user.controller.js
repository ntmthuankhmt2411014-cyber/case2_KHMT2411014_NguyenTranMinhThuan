const User = require('../models/user.model');

// Tìm kiếm người dùng theo tên hoặc email
exports.searchUsers = async (req, res) => {
  try {
    const query = req.query.q ? req.query.q.trim() : '';
    if (!query) {
      return res.status(200).json([]);
    }

    const regex = new RegExp(query, 'i');
    const users = await User.find({
      $or: [{ fullName: regex }, { email: regex }],
    })
      .select('fullName email avatarUrl _id')
      .limit(20);

    return res.status(200).json(users);
  } catch (error) {
    console.error('Lỗi tìm kiếm người dùng:', error);
    return res.status(500).json({ message: 'Lỗi server khi tìm kiếm người dùng' });
  }
};

// Xem thông tin công khai của người dùng theo ID
exports.getUserById = async (req, res) => {
  try {
    const user = await User.findById(req.params.id).select('fullName email avatarUrl createdAt');
    if (!user) {
      return res.status(404).json({ message: 'Không tìm thấy người dùng' });
    }
    return res.status(200).json(user);
  } catch (error) {
    console.error('Lỗi lấy thông tin người dùng:', error);
    return res.status(500).json({ message: 'Lỗi server khi lấy thông tin người dùng' });
  }
};
