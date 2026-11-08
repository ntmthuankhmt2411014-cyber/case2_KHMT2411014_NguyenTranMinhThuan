import 'package:flutter/material.dart';

import '../../models/statistics.dart';
import '../../services/statistics_service.dart';
import '../../widgets/task_statistics_card.dart';

/// Tab Thống kê: tải 3 API thống kê và hiển thị trong TaskStatisticsCard.
class StatisticsScreen extends StatefulWidget {
  // Callback do MainScreen truyền vào để chuyển sang tab Danh sách kèm bộ lọc.
  final ValueChanged<String?> onOpenStatus;
  final ValueChanged<String> onOpenDueFilter;

  const StatisticsScreen({
    super.key,
    required this.onOpenStatus,
    required this.onOpenDueFilter,
  });

  @override
  State<StatisticsScreen> createState() => StatisticsScreenState();
}

class StatisticsScreenState extends State<StatisticsScreen> {
  final _statisticsService = StatisticsService();

  TaskStatusStatistics? _taskStats;
  AssignmentStatistics? _assignmentStats;
  DeadlineStatistics? _deadlineStats;
  bool _statsLoading = true;
  String? _statsError;

  @override
  void initState() {
    super.initState();
    refresh();
  }

  // Public để MainScreen gọi lại mỗi khi người dùng chọn tab Thống kê.
  Future<void> refresh() async {
    setState(() {
      _statsLoading = true;
      _statsError = null;
    });

    try {
      // Gọi 3 API song song để giảm thời gian chờ.
      final results = await Future.wait<Object>([
        _statisticsService.getTaskStatistics(),
        _statisticsService.getAssignmentStatistics(),
        _statisticsService.getDeadlineStatistics(),
      ]);
      if (!mounted) return;
      setState(() {
        _taskStats = results[0] as TaskStatusStatistics;
        _assignmentStats = results[1] as AssignmentStatistics;
        _deadlineStats = results[2] as DeadlineStatistics;
        _statsLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _statsError = e.toString();
        _statsLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Thống kê công việc'),
        actions: [
          IconButton(
            tooltip: 'Tải lại thống kê',
            onPressed: _statsLoading ? null : refresh,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: refresh,
        child: ListView(
          // Luôn cuộn được để kéo xuống làm mới cả khi nội dung ngắn.
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            TaskStatisticsCard(
              isLoading: _statsLoading,
              error: _statsError,
              taskStats: _taskStats,
              assignmentStats: _assignmentStats,
              deadlineStats: _deadlineStats,
              onRetry: refresh,
              onOpenStatus: widget.onOpenStatus,
              onOpenDueFilter: widget.onOpenDueFilter,
            ),
          ],
        ),
      ),
    );
  }
}
