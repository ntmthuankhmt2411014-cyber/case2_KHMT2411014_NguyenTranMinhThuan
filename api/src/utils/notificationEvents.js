// Các loại sự kiện tạo thông báo trong app và email.
// Dùng chung cho notification.model, emailLog.model và taskEvent.service.
const EVENT_TYPES = Object.freeze({
  TASK_ASSIGNED: 'task_assigned',
  TASK_SHARED: 'task_shared',
  DUE_DATE_CHANGED: 'due_date_changed',
  TASK_COMPLETED: 'task_completed',
  DEADLINE_REMINDER: 'deadline_reminder',
});

const ALL_EVENT_TYPES = Object.values(EVENT_TYPES);

function toId(value) {
  if (value === null || value === undefined) return null;
  if (typeof value === 'object' && value._id) return String(value._id);
  return String(value);
}

// Tính danh sách người nhận cho một sự kiện.
// - Giao việc / chia sẻ: chỉ người vừa được thêm.
// - Các sự kiện còn lại: creator + mọi người được giao + mọi người được chia sẻ.
// Luôn bỏ người thực hiện thao tác và gộp trùng theo userId.
function resolveRecipientIds({
  createdBy,
  assigneeIds = [],
  shareUserIds = [],
  actorId,
  eventType,
  targetUserIds = [],
}) {
  const onlyTargets =
    eventType === EVENT_TYPES.TASK_ASSIGNED || eventType === EVENT_TYPES.TASK_SHARED;

  const source = onlyTargets ? targetUserIds : [createdBy, ...assigneeIds, ...shareUserIds];
  const actor = toId(actorId);
  const seen = new Set();
  const result = [];

  for (const raw of source) {
    const id = toId(raw);
    if (!id || id === actor || seen.has(id)) continue;
    seen.add(id);
    result.push(id);
  }

  return result;
}

function pad(value) {
  return String(value).padStart(2, '0');
}

// Giờ địa phương dạng dd/MM/yyyy HH:mm, dùng trong nội dung email.
function formatDateTime(date) {
  const value = new Date(date);
  if (Number.isNaN(value.getTime())) return '';
  return `${pad(value.getDate())}/${pad(value.getMonth() + 1)}/${value.getFullYear()} ${pad(
    value.getHours()
  )}:${pad(value.getMinutes())}`;
}

function buildEventContent({
  eventType,
  actorName = 'Một thành viên',
  taskTitle = '',
  dueDate,
  permission,
}) {
  let title;
  let message;
  let subject;

  switch (eventType) {
    case EVENT_TYPES.TASK_ASSIGNED:
      title = 'Bạn được giao công việc mới';
      message = `${actorName} đã giao cho bạn công việc "${taskTitle}".`;
      subject = `[Task Manager] Bạn được giao công việc: ${taskTitle}`;
      break;
    case EVENT_TYPES.TASK_SHARED:
      title = 'Công việc được chia sẻ với bạn';
      message = `${actorName} đã chia sẻ công việc "${taskTitle}" với bạn (${
        permission === 'editor' ? 'Chỉnh sửa' : 'Chỉ xem'
      }).`;
      subject = `[Task Manager] Công việc được chia sẻ: ${taskTitle}`;
      break;
    case EVENT_TYPES.DUE_DATE_CHANGED:
      title = 'Hạn hoàn thành đã thay đổi';
      message = `${actorName} đã đổi hạn công việc "${taskTitle}" thành ${formatDateTime(
        dueDate
      )}.`;
      subject = `[Task Manager] Hạn hoàn thành đã thay đổi: ${taskTitle}`;
      break;
    case EVENT_TYPES.TASK_COMPLETED:
      title = 'Công việc đã hoàn thành';
      message = `${actorName} đã đánh dấu công việc "${taskTitle}" là hoàn thành.`;
      subject = `[Task Manager] Công việc đã hoàn thành: ${taskTitle}`;
      break;
    case EVENT_TYPES.DEADLINE_REMINDER:
      title = 'Công việc sắp đến hạn';
      message = `Công việc "${taskTitle}" sẽ đến hạn vào ${formatDateTime(dueDate)}.`;
      subject = `[Task Manager] Sắp đến hạn: ${taskTitle}`;
      break;
    default:
      throw new Error(`Loại sự kiện không hợp lệ: ${eventType}`);
  }

  return {
    title,
    message,
    subject,
    text: `${message}\n\nXem chi tiết trong ứng dụng Task Manager.`,
  };
}

// Chỉ báo đổi hạn khi client thực sự gửi hạn mới và giá trị khác hạn cũ.
function hasDueDateChanged(oldDueDate, newDueDate) {
  if (newDueDate === undefined || newDueDate === null || newDueDate === '') return false;

  const newTime = new Date(newDueDate).getTime();
  if (Number.isNaN(newTime)) return false;

  if (oldDueDate === undefined || oldDueDate === null || oldDueDate === '') return true;

  const oldTime = new Date(oldDueDate).getTime();
  return oldTime !== newTime;
}

function isTransitionToCompleted(oldStatus, newStatus) {
  return newStatus === 'Completed' && oldStatus !== 'Completed';
}

// Chỉ gửi lại email đã thất bại và chưa quá 3 lần thử.
function shouldRetryLog({ status, attempts }) {
  return status === 'failed' && Number(attempts) < 3;
}

// Task đến hạn trong khoảng (now, now + hours], chưa hoàn thành.
function isDueWithin(task, now = new Date(), hours = 24) {
  if (!task || task.status === 'Completed' || !task.dueDate) return false;

  const dueTime = new Date(task.dueDate).getTime();
  const nowTime = new Date(now).getTime();
  if (Number.isNaN(dueTime) || Number.isNaN(nowTime)) return false;

  return dueTime > nowTime && dueTime <= nowTime + hours * 60 * 60 * 1000;
}

module.exports = {
  EVENT_TYPES,
  ALL_EVENT_TYPES,
  resolveRecipientIds,
  buildEventContent,
  hasDueDateChanged,
  isTransitionToCompleted,
  shouldRetryLog,
  isDueWithin,
  formatDateTime,
};
