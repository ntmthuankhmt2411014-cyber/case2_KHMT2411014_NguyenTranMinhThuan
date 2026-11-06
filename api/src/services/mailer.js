const nodemailer = require('nodemailer');

// Chỉ coi là cấu hình đủ khi có đủ 4 giá trị. Không kiểm tra giá trị đúng/sai
// để tránh log bí mật; Mailtrap sẽ trả lỗi nếu thông tin không hợp lệ.
function isSmtpConfigured(env = process.env) {
  return Boolean(env.SMTP_HOST && env.SMTP_PORT && env.SMTP_USER && env.SMTP_PASS);
}

function createTransporter(env = process.env) {
  if (!isSmtpConfigured(env)) return null;

  const port = Number(env.SMTP_PORT);

  return nodemailer.createTransport({
    host: env.SMTP_HOST,
    port,
    secure: port === 465,
    auth: {
      user: env.SMTP_USER,
      pass: env.SMTP_PASS,
    },
    // Không để API treo lâu nếu SMTP không phản hồi.
    connectionTimeout: 10000,
    greetingTimeout: 10000,
    socketTimeout: 10000,
  });
}

// Tạo một lần rồi dùng lại để Nodemailer tái sử dụng kết nối.
let transporter;

function getTransporter() {
  if (transporter === undefined) {
    transporter = createTransporter();
  }
  return transporter;
}

async function sendMail({ to, subject, text, html }) {
  const client = getTransporter();
  if (!client) {
    throw new Error('Thiếu cấu hình SMTP');
  }

  return client.sendMail({
    from: process.env.MAIL_FROM || 'Task Manager <no-reply@taskmanager.local>',
    to,
    subject,
    text,
    html,
  });
}

module.exports = {
  isSmtpConfigured,
  createTransporter,
  sendMail,
};
