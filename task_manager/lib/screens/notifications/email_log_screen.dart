import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/email_log.dart';
import '../../services/notification_service.dart';

class EmailLogScreen extends StatefulWidget {
  final String taskId;
  final String taskTitle;

  const EmailLogScreen({
    super.key,
    required this.taskId,
    required this.taskTitle,
  });

  @override
  State<EmailLogScreen> createState() => _EmailLogScreenState();
}

class _EmailLogScreenState extends State<EmailLogScreen> {
  final NotificationService _service = NotificationService();

  List<EmailLog> _logs = [];
  bool _isLoading = true;
  String? _error;
  String? _retryingId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final logs = await _service.getTaskEmailLogs(widget.taskId);
      if (!mounted) return;
      setState(() {
        _logs = logs;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _retry(EmailLog log) async {
    if (_retryingId != null) return;

    setState(() => _retryingId = log.id);
    final result = await _service.retryEmailLog(log.id);
    if (!mounted) return;

    setState(() => _retryingId = null);
    final success = result['success'] == true;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result['message']?.toString() ??
              (success ? 'Gửi lại email thành công' : 'Gửi lại email thất bại'),
        ),
        backgroundColor: success ? Colors.green : Colors.red,
      ),
    );

    if (success) {
      final updated = result['emailLog'];
      if (updated is EmailLog) {
        // Cập nhật đúng bản ghi tại chỗ, không cần tải lại cả danh sách.
        setState(() {
          final index = _logs.indexWhere((item) => item.id == updated.id);
          if (index != -1) {
            _logs[index] = updated;
          }
        });
      } else {
        _load();
      }
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'sent':
        return Colors.green;
      case 'failed':
        return Colors.red;
      default:
        return Colors.orange;
    }
  }

  String _formatTime(DateTime? time) {
    if (time == null) return 'Chưa có thời gian';
    return DateFormat('dd/MM/yyyy HH:mm').format(time.toLocal());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Lịch sử email')),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 12),
              Text('Không tải được lịch sử email.\n$_error', textAlign: TextAlign.center),
              const SizedBox(height: 12),
              ElevatedButton(onPressed: _load, child: const Text('Thử lại')),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        if (widget.taskTitle.isNotEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            color: Colors.grey.shade100,
            child: Text(
              'Công việc: ${widget.taskTitle}',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        Expanded(
          child: _logs.isEmpty
              ? const Center(child: Text('Chưa có email nào được gửi cho công việc này.'))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    itemCount: _logs.length,
                    itemBuilder: (context, index) => _buildLogItem(_logs[index]),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildLogItem(EmailLog log) {
    final color = _statusColor(log.status);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    log.recipientEmail,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    emailStatusLabel(log.status),
                    style: TextStyle(
                      color: color,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '${emailEventLabel(log.eventType)} • Lần thử: ${log.attempts}',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
            ),
            if (log.subject.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                log.subject,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13),
              ),
            ],
            if (log.errorMessage.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                log.errorMessage,
                style: TextStyle(fontSize: 12, color: Colors.red.shade700),
              ),
            ],
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(Icons.schedule, size: 14, color: Colors.grey.shade600),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    _formatTime(log.sentAt ?? log.createdAt),
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ),
                if (canRetryEmailLog(log.status, log.attempts))
                  _retryingId == log.id
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : TextButton.icon(
                          onPressed: () => _retry(log),
                          icon: const Icon(Icons.refresh, size: 18),
                          label: const Text('Gửi lại'),
                        ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
