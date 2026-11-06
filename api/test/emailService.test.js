const test = require('node:test');
const assert = require('node:assert/strict');
const { isSmtpConfigured } = require('../src/services/mailer');
const {
  sanitizeErrorMessage,
  buildRetryText,
} = require('../src/services/email.service');

test('thiếu cấu hình SMTP trả false', () => {
  assert.equal(isSmtpConfigured({}), false);
  assert.equal(isSmtpConfigured({ SMTP_HOST: 'h', SMTP_PORT: '2525', SMTP_USER: 'u' }), false);
  assert.equal(
    isSmtpConfigured({
      SMTP_HOST: 'h',
      SMTP_PORT: '2525',
      SMTP_USER: 'u',
      SMTP_PASS: 'p',
    }),
    true
  );
});

test('errorMessage được rút gọn và bỏ xuống dòng', () => {
  const long = `Lỗi\nSMTP ${'x'.repeat(400)}`;
  const result = sanitizeErrorMessage(new Error(long));
  assert.equal(result.includes('\n'), false);
  assert.equal(result.length <= 300, true);
});

test('nội dung retry dùng tên công việc', () => {
  assert.equal(
    buildRetryText({ title: 'Báo cáo' }),
    'Công việc "Báo cáo" có cập nhật mới. Vui lòng mở ứng dụng Task Manager để xem chi tiết.'
  );
});
