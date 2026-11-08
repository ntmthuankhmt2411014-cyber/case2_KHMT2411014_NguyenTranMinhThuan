import 'package:flutter/material.dart';
import '../../models/statistics.dart';
import '../../models/user.dart';
import '../../services/auth_service.dart';
import '../../services/statistics_service.dart';
import '../../widgets/task_statistics_card.dart';
import '../auth/login_screen.dart';
import '../task_list_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _authService = AuthService();
  final _statisticsService = StatisticsService();
  User? _currentUser;
  bool _isLoading = true;

  // Trạng thái riêng cho phần thống kê để lỗi thống kê không làm hỏng màn hình.
  TaskStatusStatistics? _taskStats;
  AssignmentStatistics? _assignmentStats;
  DeadlineStatistics? _deadlineStats;
  bool _statsLoading = true;
  String? _statsError;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
    _loadStatistics();
  }

  Future<void> _loadStatistics() async {
    setState(() {
      _statsLoading = true;
      _statsError = null;
    });

    try {
      // Gọi 3 API song song để màn hình tải nhanh hơn.
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

  // Mở danh sách công việc với bộ lọc ban đầu, quay lại thì tải lại thống kê.
  Future<void> _openTaskList({String? status, String? dueFilter}) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TaskListScreen(
          initialStatus: status,
          initialDueFilter: dueFilter,
        ),
      ),
    );
    if (!mounted) return;
    _loadStatistics();
  }

  Future<void> _loadUserProfile() async {
    setState(() => _isLoading = true);
    // Ưu tiên lấy từ server để có dữ liệu mới nhất
    final result = await _authService.getMe();
    if (result['success'] == true) {
      setState(() {
        _currentUser = result['user'];
        _isLoading = false;
      });
    } else {
      // Fallback lấy từ local storage
      final localUser = await _authService.getCurrentUser();
      setState(() {
        _currentUser = localUser;
        _isLoading = false;
      });
    }
  }

  // Dialog Cập nhật Họ tên
  void _showEditProfileDialog() {
    final nameController = TextEditingController(text: _currentUser?.fullName ?? '');
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (dialogCtx) {
        bool isSubmitting = false;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Cập nhật thông tin'),
              content: Form(
                key: formKey,
                child: TextFormField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Họ và tên',
                    border: OutlineInputBorder(),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Họ tên không được để trống';
                    }
                    return null;
                  },
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSubmitting ? null : () => Navigator.pop(dialogCtx),
                  child: const Text('Hủy'),
                ),
                ElevatedButton(
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          if (!formKey.currentState!.validate()) return;
                          setDialogState(() => isSubmitting = true);

                          final result = await _authService.updateProfile(
                            fullName: nameController.text.trim(),
                          );

                          setDialogState(() => isSubmitting = false);

                          if (!mounted) return;
                          if (result['success'] == true) {
                            Navigator.pop(dialogCtx);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Cập nhật thông tin thành công!'),
                                backgroundColor: Colors.green,
                              ),
                            );
                            _loadUserProfile();
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(result['message'] ?? 'Cập nhật thất bại'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        },
                  child: isSubmitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Lưu'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // Dialog Đổi mật khẩu
  void _showChangePasswordDialog() {
    final oldPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (dialogCtx) {
        bool isSubmitting = false;
        bool obscureOld = true;
        bool obscureNew = true;
        bool obscureConfirm = true;

        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Đổi mật khẩu'),
              content: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Mật khẩu cũ
                      TextFormField(
                        controller: oldPasswordController,
                        obscureText: obscureOld,
                        decoration: InputDecoration(
                          labelText: 'Mật khẩu hiện tại',
                          border: const OutlineInputBorder(),
                          suffixIcon: IconButton(
                            icon: Icon(obscureOld ? Icons.visibility_off : Icons.visibility),
                            onPressed: () => setDialogState(() => obscureOld = !obscureOld),
                          ),
                        ),
                        validator: (val) {
                          if (val == null || val.isEmpty) {
                            return 'Vui lòng nhập mật khẩu hiện tại';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),

                      // Mật khẩu mới
                      TextFormField(
                        controller: newPasswordController,
                        obscureText: obscureNew,
                        decoration: InputDecoration(
                          labelText: 'Mật khẩu mới',
                          border: const OutlineInputBorder(),
                          suffixIcon: IconButton(
                            icon: Icon(obscureNew ? Icons.visibility_off : Icons.visibility),
                            onPressed: () => setDialogState(() => obscureNew = !obscureNew),
                          ),
                        ),
                        validator: (val) {
                          if (val == null || val.isEmpty) {
                            return 'Vui lòng nhập mật khẩu mới';
                          }
                          if (val.length < 6) {
                            return 'Mật khẩu mới phải từ 6 ký tự trở lên';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),

                      // Xác nhận mật khẩu mới
                      TextFormField(
                        controller: confirmPasswordController,
                        obscureText: obscureConfirm,
                        decoration: InputDecoration(
                          labelText: 'Xác nhận mật khẩu mới',
                          border: const OutlineInputBorder(),
                          suffixIcon: IconButton(
                            icon: Icon(obscureConfirm ? Icons.visibility_off : Icons.visibility),
                            onPressed: () => setDialogState(() => obscureConfirm = !obscureConfirm),
                          ),
                        ),
                        validator: (val) {
                          if (val == null || val.isEmpty) {
                            return 'Vui lòng xác nhận mật khẩu';
                          }
                          if (val != newPasswordController.text) {
                            return 'Mật khẩu xác nhận không khớp';
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSubmitting ? null : () => Navigator.pop(dialogCtx),
                  child: const Text('Hủy'),
                ),
                ElevatedButton(
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          if (!formKey.currentState!.validate()) return;
                          setDialogState(() => isSubmitting = true);

                          final result = await _authService.changePassword(
                            oldPassword: oldPasswordController.text,
                            newPassword: newPasswordController.text,
                          );

                          setDialogState(() => isSubmitting = false);

                          if (!mounted) return;
                          if (result['success'] == true) {
                            Navigator.pop(dialogCtx);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Đổi mật khẩu thành công!'),
                                backgroundColor: Colors.green,
                              ),
                            );
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(result['message'] ?? 'Đổi mật khẩu thất bại'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        },
                  child: isSubmitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Đổi mật khẩu'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // Đăng xuất
  Future<void> _handleLogout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xác nhận đăng xuất'),
        content: const Text('Bạn có chắc chắn muốn đăng xuất khỏi ứng dụng không?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('Đăng xuất'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _authService.logout();
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Thông tin cá nhân'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                children: [
                  // Avatar
                  Center(
                    child: CircleAvatar(
                      radius: 45,
                      backgroundColor: Colors.blue.shade100,
                      child: Text(
                        (_currentUser?.fullName.isNotEmpty == true)
                            ? _currentUser!.fullName[0].toUpperCase()
                            : 'U',
                        style: const TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Họ tên
                  Text(
                    _currentUser?.fullName ?? 'Chưa cập nhật',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),

                  // Email
                  Text(
                    _currentUser?.email ?? '',
                    style: TextStyle(fontSize: 15, color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 24),

                  // Thống kê công việc (mục E)
                  TaskStatisticsCard(
                    isLoading: _statsLoading,
                    error: _statsError,
                    taskStats: _taskStats,
                    assignmentStats: _assignmentStats,
                    deadlineStats: _deadlineStats,
                    onRetry: _loadStatistics,
                    onOpenStatus: (status) => _openTaskList(status: status),
                    onOpenDueFilter: (dueFilter) =>
                        _openTaskList(dueFilter: dueFilter),
                  ),
                  const SizedBox(height: 8),

                  const Divider(),
                  const SizedBox(height: 8),

                  // Nút Cập nhật họ tên
                  ListTile(
                    leading: const Icon(Icons.edit_outlined, color: Colors.blue),
                    title: const Text('Chỉnh sửa thông tin cá nhân'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: _showEditProfileDialog,
                  ),

                  // Nút Đổi mật khẩu
                  ListTile(
                    leading: const Icon(Icons.lock_reset, color: Colors.orange),
                    title: const Text('Đổi mật khẩu'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: _showChangePasswordDialog,
                  ),

                  const Divider(),
                  const SizedBox(height: 8),

                  // Nút Đăng xuất
                  ListTile(
                    leading: const Icon(Icons.logout, color: Colors.red),
                    title: const Text(
                      'Đăng xuất',
                      style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                    ),
                    onTap: _handleLogout,
                  ),
                ],
              ),
            ),
    );
  }
}
