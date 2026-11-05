// Chọn người phụ trách chính cho công việc.
// - Nếu có yêu cầu mới: người đó bắt buộc phải nằm trong danh sách được giao.
// - Nếu không: giữ người phụ trách chính hiện tại nếu còn trong danh sách.
// - Nếu không còn: lấy người đầu tiên, hoặc null khi danh sách rỗng.
function resolvePrimaryAssignee(assigneeIds, currentPrimaryId, requestedPrimaryId) {
  if (requestedPrimaryId) {
    if (!assigneeIds.includes(requestedPrimaryId)) {
      throw new Error('Người phụ trách chính phải nằm trong danh sách người được giao');
    }
    return requestedPrimaryId;
  }

  if (currentPrimaryId && assigneeIds.includes(currentPrimaryId)) {
    return currentPrimaryId;
  }

  return assigneeIds.length > 0 ? assigneeIds[0] : null;
}

module.exports = { resolvePrimaryAssignee };
