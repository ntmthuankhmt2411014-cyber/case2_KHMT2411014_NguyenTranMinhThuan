import 'package:flutter/material.dart';

import 'profile/profile_screen.dart';
import 'statistics/statistics_screen.dart';
import 'task_list_screen.dart';

/// Vỏ điều hướng chính: giữ 3 tab ngang cấp bằng IndexedStack + NavigationBar.
/// Nhờ vậy không còn cảnh TaskList -> Profile -> TaskList phải back 2 lần.
class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  // Dùng GlobalKey để gọi method public của từng tab khi cần.
  final _taskListKey = GlobalKey<TaskListScreenState>();
  final _statisticsKey = GlobalKey<StatisticsScreenState>();

  // Bấm ô thống kê: chuyển sang tab Danh sách và áp bộ lọc tương ứng.
  void _openTasksWithFilter({String? status, String? dueFilter}) {
    setState(() => _currentIndex = 0);
    _taskListKey.currentState?.applyFilters(
      status: status,
      dueFilter: dueFilter,
    );
  }

  void _onDestinationSelected(int index) {
    setState(() => _currentIndex = index);
    // Mỗi lần mở tab Thống kê thì tải lại để không hiển thị số cũ.
    if (index == 1) {
      _statisticsKey.currentState?.refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: [
          TaskListScreen(key: _taskListKey),
          StatisticsScreen(
            key: _statisticsKey,
            onOpenStatus: (status) => _openTasksWithFilter(status: status),
            onOpenDueFilter: (dueFilter) =>
                _openTasksWithFilter(dueFilter: dueFilter),
          ),
          const ProfileScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: _onDestinationSelected,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.list_alt_outlined),
            selectedIcon: Icon(Icons.list_alt),
            label: 'Danh sách',
          ),
          NavigationDestination(
            icon: Icon(Icons.insights_outlined),
            selectedIcon: Icon(Icons.insights),
            label: 'Thống kê',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Cá nhân',
          ),
        ],
      ),
    );
  }
}
