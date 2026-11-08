import 'package:flutter/material.dart';

import '../models/task_activity.dart';
import '../utils/date_time.dart';

/// Card hiển thị lịch sử hoạt động của công việc trong màn Chi tiết.
class TaskActivityTimeline extends StatelessWidget {
  final List<TaskActivity> activities;
  final bool isLoading;
  final String? error;
  final VoidCallback onRetry;

  const TaskActivityTimeline({
    super.key,
    required this.activities,
    required this.isLoading,
    this.error,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: const [
                Icon(Icons.history, size: 20, color: Colors.blueGrey),
                SizedBox(width: 8),
                Text(
                  'Lịch sử hoạt động',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (isLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              )
            else if (error != null)
              _buildError()
            else if (activities.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'Chưa có hoạt động',
                  style: TextStyle(color: Colors.grey),
                ),
              )
            else
              ...activities.asMap().entries.map((entry) {
                final isLast = entry.key == activities.length - 1;
                return Column(
                  children: [
                    _ActivityRow(activity: entry.value),
                    if (!isLast) const Divider(height: 16),
                  ],
                );
              }),
          ],
        ),
      ),
    );
  }

  Widget _buildError() {
    return Column(
      children: [
        Row(
          children: [
            const Icon(Icons.error_outline, size: 18, color: Colors.red),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                error!,
                style: TextStyle(color: Colors.red.shade700),
              ),
            ),
          ],
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: onRetry,
            child: const Text('Thử lại'),
          ),
        ),
      ],
    );
  }
}

/// Một dòng hoạt động: icon theo loại hành động, người thực hiện, thời gian, tóm tắt.
class _ActivityRow extends StatelessWidget {
  final TaskActivity activity;

  const _ActivityRow({required this.activity});

  @override
  Widget build(BuildContext context) {
    final time = formatDateTime(parseLocalDate(activity.createdAt));
    final userLine = [
      activity.userName,
      time,
    ].where((part) => part.isNotEmpty).join(' · ');

    final summary = _buildSummary();
    final (icon, color) = _iconForAction(activity.action);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 16,
          backgroundColor: color.withAlpha(25),
          child: Icon(icon, size: 18, color: color),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                activity.actionLabel,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              if (userLine.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  userLine,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
              if (summary != null) ...[
                const SizedBox(height: 2),
                Text(summary, style: const TextStyle(fontSize: 12)),
              ],
            ],
          ),
        ),
      ],
    );
  }

  // Tóm tắt ngắn nội dung thay đổi; loại hành động khác không cần tóm tắt.
  String? _buildSummary() {
    final details = activity.details;
    switch (activity.action) {
      case 'status_changed':
        return '${details['from'] ?? '?'} → ${details['to'] ?? '?'}';
      case 'primary_changed':
        return '${details['from'] ?? 'Chưa có'} → ${details['to'] ?? '?'}';
      case 'assigned':
        final userIds = details['userIds'];
        final count = userIds is List ? userIds.length : 0;
        return 'Giao cho $count người';
      case 'shared':
        final userIds = details['userIds'];
        final count = userIds is List ? userIds.length : 0;
        return 'Chia sẻ $count người (${details['permission'] ?? '?'})';
      default:
        return null;
    }
  }

  (IconData, Color) _iconForAction(String action) {
    switch (action) {
      case 'created':
        return (Icons.add_circle_outline, Colors.green);
      case 'updated':
        return (Icons.edit_outlined, Colors.blue);
      case 'status_changed':
        return (Icons.swap_horiz, Colors.orange);
      case 'assigned':
        return (Icons.person_add_alt_1, Colors.indigo);
      case 'primary_changed':
        return (Icons.star_outline, Colors.purple);
      case 'assignee_removed':
        return (Icons.person_remove_outlined, Colors.red);
      case 'shared':
        return (Icons.share_outlined, Colors.teal);
      case 'permission_changed':
        return (Icons.admin_panel_settings_outlined, Colors.brown);
      case 'share_removed':
        return (Icons.link_off, Colors.red);
      default:
        return (Icons.history, Colors.blueGrey);
    }
  }
}
