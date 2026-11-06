const test = require('node:test');
const assert = require('node:assert/strict');
const { scanAndRemind, startDeadlineReminderJob } = require('../src/jobs/deadlineReminder.job');

test('scanAndRemind là một async function', () => {
  assert.equal(typeof scanAndRemind, 'function');
});

test('startDeadlineReminderJob trả về null khi DISABLE_REMINDER_JOB là true', () => {
  process.env.DISABLE_REMINDER_JOB = 'true';
  const job = startDeadlineReminderJob();
  assert.equal(job, null);
  delete process.env.DISABLE_REMINDER_JOB;
});
