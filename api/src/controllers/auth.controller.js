const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const User = require('../models/user.model');

const generateToken = (user) => {
  return jwt.sign(
    { id: user._id, email: user.email },
    process.env.JWT_SECRET || 'case2_secret_key_KHMT2411014_2026',
    { expiresIn: '7d' }
  );
};

// 1. Đăng ký tài khoản
exports.register = async (req, res) => {
  try {
    const { fullName, email, password } = req.body;

    if (!fullName || !email || !password) {
      return res.status(400).json({ message: 'Vui lòng điền đầy đủ họ tên, email và mật khẩu' });
    }

    const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
    if (!emailRegex.test(email.trim())) {
      return res.status(400).json({ message: 'Email không đúng định dạng' });
    }

    if (password.length < 6) {
      return res.status(400).json({ message: 'Mật khẩu phải có ít nhất 6 ký tự' });
    }

    const normalizedEmail = email.toLowerCase().trim();
    const existingUser = await User.findOne({ email: normalizedEmail });
    if (existingUser) {
      return res.status(400).json({ message: 'Email đã được sử dụng bởi tài khoản khác' });
    }

    const salt = await bcrypt.genSalt(10);
    const passwordHash = await bcrypt.hash(password, salt);

    const newUser = await User.create({
      fullName: fullName.trim(),
      email: normalizedEmail,
      passwordHash,
      avatarUrl: '',
    });

    const token = generateToken(newUser);

    return res.status(201).json({
      message: 'Đăng ký tài khoản thành công',
      token,
      user: {
        id: newUser._id,
        fullName: newUser.fullName,
        email: newUser.email,
        avatarUrl: newUser.avatarUrl,
        createdAt: newUser.createdAt,
      },
    });
  } catch (error) {
    console.error('Lỗi đăng ký:', error);
    return res.status(500).json({ message: 'Lỗi server khi đăng ký tài khoản' });
  }
};

// 2. Đăng nhập
exports.login = async (req, res) => {
  try {
    const { email, password } = req.body;

    if (!email || !password) {
      return res.status(400).json({ message: 'Vui lòng nhập email và mật khẩu' });
    }

    const normalizedEmail = email.toLowerCase().trim();
    const user = await User.findOne({ email: normalizedEmail });
    if (!user) {
      return res.status(400).json({ message: 'Email hoặc mật khẩu không chính xác' });
    }

    const isMatch = await bcrypt.compare(password, user.passwordHash);
    if (!isMatch) {
      return res.status(400).json({ message: 'Email hoặc mật khẩu không chính xác' });
    }

    const token = generateToken(user);

    return res.status(200).json({
      message: 'Đăng nhập thành công',
      token,
      user: {
        id: user._id,
        fullName: user.fullName,
        email: user.email,
        avatarUrl: user.avatarUrl,
        createdAt: user.createdAt,
      },
    });
  } catch (error) {
    console.error('Lỗi đăng nhập:', error);
    return res.status(500).json({ message: 'Lỗi server khi đăng nhập' });
  }
};

// 3. Xem thông tin cá nhân (GET /auth/me)
exports.getMe = async (req, res) => {
  try {
    return res.status(200).json({
      user: {
        id: req.user._id,
        fullName: req.user.fullName,
        email: req.user.email,
        avatarUrl: req.user.avatarUrl,
        createdAt: req.user.createdAt,
        updatedAt: req.user.updatedAt,
      },
    });
  } catch (error) {
    console.error('Lỗi lấy thông tin cá nhân:', error);
    return res.status(500).json({ message: 'Lỗi server khi lấy thông tin cá nhân' });
  }
};

// 4. Cập nhật thông tin cá nhân (PUT /auth/me)
exports.updateMe = async (req, res) => {
  try {
    const { fullName, avatarUrl } = req.body;
    const updates = {};

    if (fullName && fullName.trim()) {
      updates.fullName = fullName.trim();
    }
    if (avatarUrl !== undefined) {
      updates.avatarUrl = avatarUrl.trim();
    }

    const updatedUser = await User.findByIdAndUpdate(
      req.user._id,
      { $set: updates },
      { new: true }
    ).select('-passwordHash');

    return res.status(200).json({
      message: 'Cập nhật thông tin thành công',
      user: {
        id: updatedUser._id,
        fullName: updatedUser.fullName,
        email: updatedUser.email,
        avatarUrl: updatedUser.avatarUrl,
        createdAt: updatedUser.createdAt,
        updatedAt: updatedUser.updatedAt,
      },
    });
  } catch (error) {
    console.error('Lỗi cập nhật thông tin:', error);
    return res.status(500).json({ message: 'Lỗi server khi cập nhật thông tin' });
  }
};

// 5. Đổi mật khẩu (PUT /auth/change-password)
exports.changePassword = async (req, res) => {
  try {
    const { oldPassword, newPassword } = req.body;

    if (!oldPassword || !newPassword) {
      return res.status(400).json({ message: 'Vui lòng nhập mật khẩu cũ và mật khẩu mới' });
    }

    if (newPassword.length < 6) {
      return res.status(400).json({ message: 'Mật khẩu mới phải có ít nhất 6 ký tự' });
    }

    const user = await User.findById(req.user._id);
    const isMatch = await bcrypt.compare(oldPassword, user.passwordHash);
    if (!isMatch) {
      return res.status(400).json({ message: 'Mật khẩu hiện tại không đúng' });
    }

    const salt = await bcrypt.genSalt(10);
    user.passwordHash = await bcrypt.hash(newPassword, salt);
    await user.save();

    return res.status(200).json({ message: 'Đổi mật khẩu thành công' });
  } catch (error) {
    console.error('Lỗi đổi mật khẩu:', error);
    return res.status(500).json({ message: 'Lỗi server khi đổi mật khẩu' });
  }
};
