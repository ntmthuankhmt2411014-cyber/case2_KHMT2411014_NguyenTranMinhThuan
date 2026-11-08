import 'package:flutter/material.dart';

import '../models/statistics.dart';

/// Card hiển thị số liệu thống kê (mục E) trong màn Cá nhân.
/// Bấm vào ô trạng thái/hạn chót sẽ mở danh sách công việc đã lọc sẵn.
class TaskStatisticsCard extends StatelessWidget {
  final bool isLoading;
  final String? error;
  final TaskStatusStatistics? taskStats;
  final AssignmentStatistics? assignmentStats;
  final DeadlineStatistics? deadlineStats;
  final VoidCallback onRetry;
  final ValueChanged<String?> onOpenStatus;
  final ValueChanged<String> onOpenDueFilter;

  const TaskStatisticsCard({
    super.key,
    required this.isLoading,
    this.error,
    this.taskStats,
    this.assignmentStats,
    this.deadlineStats,
    required this.onRetry,
    required this.onOpenStatus,
    required this.onOpenDueFilter,
  });

  static const _sectionStyle = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w600,
    color: Colors.black54,
  );

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.insights, color: Colors.indigo, size: 20),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Thống kê công việc',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
                if (!isLoading && error == null && taskStats != null)
                  _TotalBadge(total: taskStats!.total),
              ],
            ),
            const SizedBox(height: 12),
            if (isLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (error != null)
              _buildError()
            else
              ..._buildSections(),
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
            const Icon(Icons.error_outline, color: Colors.red, size: 18),
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

  List<Widget> _buildSections() {
    return [
      if (taskStats != null) ...[
        const Text('Theo trạng thái', style: _sectionStyle),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _StatTile(
                label: 'Chờ làm',
                count: taskStats!.pending,
                color: Colors.orange,
                onTap: () => onOpenStatus('Pending'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _StatTile(
                label: 'Đang làm',
                count: taskStats!.inProgress,
                color: Colors.blue,
                onTap: () => onOpenStatus('InProgress'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _StatTile(
                label: 'Hoàn thành',
                count: taskStats!.completed,
                color: Colors.green,
                onTap: () => onOpenStatus('Completed'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
      ],
      if (assignmentStats != null) ...[
        const Divider(height: 1),
        const SizedBox(height: 12),
        const Text('Giao việc', style: _sectionStyle),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _StatTile(
                label: 'Được giao',
                count: assignmentStats!.assignedCount,
                color: Colors.indigo,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _StatTile(
                label: 'Đang phụ trách',
                count: assignmentStats!.primaryCount,
                color: Colors.purple,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
      ],
      if (deadlineStats != null) ...[
        const Divider(height: 1),
        const SizedBox(height: 12),
        const Text('Hạn chót', style: _sectionStyle),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _StatTile(
                label: 'Sắp đến hạn (7 ngày)',
                count: deadlineStats!.upcomingCount,
                color: Colors.orange,
                onTap: () => onOpenDueFilter('next7'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _StatTile(
                label: 'Quá hạn',
                count: deadlineStats!.overdueCount,
                color: Colors.red,
                onTap: () => onOpenDueFilter('overdue'),
              ),
            ),
          ],
        ),
      ],
    ];
  }
}

/// Badge tổng số công việc ở góc phải tiêu đề.
class _TotalBadge extends StatelessWidget {
  final int total;

  const _TotalBadge({required this.total});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.indigo.withAlpha(20),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$total',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.indigo,
            ),
          ),
          const Text(
            'Tổng',
            style: TextStyle(fontSize: 10, color: Colors.indigo),
          ),
        ],
      ),
    );
  }
}

/// Một ô số liệu: số lớn ở trên, nhãn ở dưới. Có onTap thì bấm được.
class _StatTile extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  final VoidCallback? onTap;

  const _StatTile({
    required this.label,
    required this.count,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withAlpha(20),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$count',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
