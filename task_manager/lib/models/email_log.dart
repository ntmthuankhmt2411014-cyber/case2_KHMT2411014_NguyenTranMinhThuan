class EmailLog {
  final String id;
  final String? taskId;
  final String recipientEmail;
  final String eventType;
  final String subject;
  final String status;
  final int attempts;
  final String errorMessage;
  final DateTime? sentAt;
  final DateTime? createdAt;

  EmailLog({
    required this.id,
    this.taskId,
    required this.recipientEmail,
    required this.eventType,
    required this.subject,
    required this.status,
    required this.attempts,
    required this.errorMessage,
    this.sentAt,
    this.createdAt,
  });

  factory EmailLog.fromJson(Map<String, dynamic> json) {
    return EmailLog(
      id: json['_id']?.toString() ?? '',
      taskId: json['taskId']?.toString(),
      recipientEmail: json['recipientEmail']?.toString() ?? '',
      eventType: json['eventType']?.toString() ?? '',
      subject: json['subject']?.toString() ?? '',
      status: json['status']?.toString() ?? 'pending',
      attempts: (json['attempts'] as num?)?.toInt() ?? 0,
      errorMessage: json['errorMessage']?.toString() ?? '',
      sentAt: json['sentAt'] != null
          ? DateTime.tryParse(json['sentAt'].toString())
          : null,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString())
          : null,
    );
  }
}

bool canRetryEmailLog(String status, int attempts) {
  return status == 'failed' && attempts < 3;
}

String emailStatusLabel(String status) {
  switch (status) {
    case 'sent':
      return 'Đã gửi';
    case 'failed':
      return 'Thất bại';
    case 'pending':
      return 'Đang gửi';
    default:
      return status;
  }
}

String emailEventLabel(String eventType) {
  switch (eventType) {
    case 'task_assigned':
      return 'Giao việc';
    case 'task_shared':
      return 'Chia sẻ';
    case 'due_date_changed':
      return 'Đổi hạn';
    case 'task_completed':
      return 'Hoàn thành';
    case 'deadline_reminder':
      return 'Nhắc hạn';
    default:
      return 'Thông báo';
  }
}
