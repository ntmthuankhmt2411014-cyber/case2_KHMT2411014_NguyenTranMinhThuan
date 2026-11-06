import 'dart:async';

import 'package:flutter/material.dart';

import '../../models/task.dart';
import '../../models/task_share.dart';
import '../../models/user.dart';
import '../../services/auth_service.dart';
import '../../services/task_api_service.dart';
import '../../services/user_service.dart';

class TaskShareScreen extends StatefulWidget {
  final Task task;

  const TaskShareScreen({super.key, required this.task});

  @override
  State<TaskShareScreen> createState() => _TaskShareScreenState();
}

class _TaskShareScreenState extends State<TaskShareScreen> {
  final TaskApiService _apiService = TaskApiService();
  final UserService _userService = UserService();
  final AuthService _authService = AuthService();
  final TextEditingController _searchController = TextEditingController();

  // Debounce để không gọi API tìm kiếm trên mỗi ký tự gõ.
  Timer? _searchTimer;

  List<TaskShare> _shares = [];
  bool _isLoading = true;
  String? _loadError;
  String? _currentUserId;

  // Id của bản ghi đang cập nhật/thu hồi để khóa đúng dòng đó.
  String? _updatingShareId;
  String? _removingShareId;

  Set<String> _selectedIds = {};
  List<User> _searchResults = [];
  bool _isSearching = false;
  bool _isSharing = false;
  String? _searchError;
  String _newPermission = 'viewer';

  // Đánh dấu đã có thay đổi để màn chi tiết biết cần tải lại khi quay về.
  bool _didChange = false;

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
    _loadShares();
  }

  @override
  void dispose() {
    _searchTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  // Không cho chia sẻ cho chính mình, người tạo hoặc người đã có trong danh sách.
  Set<String> get _excludedIds => {
        ..._shares.map((share) => share.userId),
        ?_currentUserId,
        ?widget.task.createdBy,
      };

  Future<void> _loadCurrentUser() async {
    final user = await _authService.getCurrentUser();
    if (!mounted) return;
    setState(() => _currentUserId = user?.id);
  }

  Future<void> _loadShares() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });

    try {
      final shares = await _apiService.getShares(widget.task.id);
      if (!mounted) return;
      setState(() {
        _shares = shares;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = e.toString();
        _isLoading = false;
      });
    }
  }

  void _onSearchChanged(String value) {
    _searchTimer?.cancel();
    final query = value.trim();

    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
        _searchError = null;
      });
      return;
    }

    _searchTimer = Timer(const Duration(milliseconds: 400), () => _search(query));
  }

  Future<void> _search(String query) async {
    setState(() {
      _isSearching = true;
      _searchError = null;
    });

    try {
      final results = await _userService.searchUsers(query);
      if (!mounted || query != _searchController.text.trim()) return;
      setState(() {
        _searchResults = filterShareCandidates(
          users: results,
          excludedIds: _excludedIds,
        );
        _isSearching = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSearching = false;
        _searchError = e.toString();
      });
    }
  }

  void _toggleCandidate(User user) {
    setState(() {
      if (_selectedIds.contains(user.id)) {
        _selectedIds.remove(user.id);
      } else {
        _selectedIds.add(user.id);
      }
    });
  }

  Future<void> _shareSelected() async {
    if (_isSharing) return;

    if (_selectedIds.isEmpty) {
      _showSnack('Vui lòng chọn ít nhất một người để chia sẻ', Colors.orange);
      return;
    }

    setState(() => _isSharing = true);
    final result = await _apiService.shareUsers(
      widget.task.id,
      _selectedIds.toList(),
      _newPermission,
    );
    if (!mounted) return;
    setState(() => _isSharing = false);

    if (result['success'] != true) {
      _showSnack(result['message'] ?? 'Chia sẻ công việc thất bại', Colors.red);
      return;
    }

    setState(() {
      _selectedIds = {};
      _searchResults = [];
      _searchController.clear();
      _didChange = true;
    });

    // Response của API chia sẻ đã trả danh sách mới nhất; nếu thiếu thì tải lại.
    final rawShares = result['shares'];
    if (rawShares is List) {
      setState(() {
        _shares = rawShares
            .whereType<Map<String, dynamic>>()
            .map(TaskShare.fromJson)
            .toList();
      });
    } else {
      await _loadShares();
    }

    if (!mounted) return;
    _showSnack('Chia sẻ công việc thành công', Colors.green);
  }

  Future<void> _updatePermission(TaskShare share, String permission) async {
    if (_updatingShareId != null || share.permission == permission) return;

    setState(() => _updatingShareId = share.id);
    final result = await _apiService.updateSharePermission(
      widget.task.id,
      share.id,
      permission,
    );
    if (!mounted) return;
    setState(() => _updatingShareId = null);

    if (result['success'] != true) {
      _showSnack(result['message'] ?? 'Cập nhật quyền chia sẻ thất bại', Colors.red);
      return;
    }

    final rawShare = result['share'];
    if (rawShare is Map<String, dynamic>) {
      final updated = TaskShare.fromJson(rawShare);
      setState(() {
        _shares = _shares
            .map((item) => item.id == share.id ? updated : item)
            .toList();
        _didChange = true;
      });
    } else {
      await _loadShares();
    }

    if (!mounted) return;
    _showSnack('Đã cập nhật quyền chia sẻ', Colors.green);
  }

  Future<void> _confirmRemove(TaskShare share) async {
    if (_removingShareId != null) return;

    final name = share.userFullName.isNotEmpty
        ? share.userFullName
        : (share.userEmail.isNotEmpty ? share.userEmail : 'người dùng này');

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Thu hồi quyền chia sẻ'),
        content: Text('Thu hồi quyền truy cập của $name?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Thu hồi'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _removingShareId = share.id);
    final result = await _apiService.removeShare(widget.task.id, share.id);
    if (!mounted) return;
    setState(() => _removingShareId = null);

    if (result['success'] == true) {
      setState(() {
        _shares = _shares.where((item) => item.id != share.id).toList();
        _didChange = true;
      });
      _showSnack('Đã thu hồi quyền chia sẻ', Colors.green);
    } else {
      _showSnack(result['message'] ?? 'Thu hồi quyền chia sẻ thất bại', Colors.red);
    }
  }

  void _showSnack(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: color),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // Nếu đã chia sẻ/thu hồi/đổi quyền, khi quay về trả true để màn trước tải lại.
      canPop: !_didChange,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        Navigator.pop(context, true);
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('Quản lý chia sẻ')),
        body: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_loadError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 12),
              Text(
                'Không thể tải danh sách chia sẻ.\n$_loadError',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: _loadShares,
                child: const Text('Thử lại'),
              ),
            ],
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Người được chia sẻ',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        ),
        const SizedBox(height: 8),
        if (_shares.isEmpty)
          Card(
            elevation: 0,
            color: Colors.grey.shade100,
            child: const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Chưa chia sẻ cho ai.'),
            ),
          )
        else
          ..._shares.map(_buildShareCard),
        const SizedBox(height: 24),
        const Text(
          'Thêm người',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _searchController,
          onChanged: _onSearchChanged,
          decoration: const InputDecoration(
            hintText: 'Tìm theo tên hoặc email',
            prefixIcon: Icon(Icons.search),
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 8),
        if (_isSearching)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_searchError != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              'Không thể tìm người dùng.\n$_searchError',
              style: const TextStyle(color: Colors.red),
            ),
          )
        else if (_searchResults.isEmpty && _searchController.text.trim().isNotEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text('Không tìm thấy người dùng phù hợp.'),
          )
        else
          ..._searchResults.map(_buildCandidateTile),
        const SizedBox(height: 12),
        _buildNewPermissionDropdown(),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: _isSharing ? null : _shareSelected,
          icon: _isSharing
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.share_outlined),
          label: Text(
            _isSharing
                ? 'Đang chia sẻ...'
                : 'Chia sẻ${_selectedIds.isEmpty ? '' : ' (${_selectedIds.length})'}',
          ),
        ),
      ],
    );
  }

  Widget _buildShareCard(TaskShare share) {
    final name = share.userFullName.isNotEmpty
        ? share.userFullName
        : (share.userEmail.isNotEmpty ? share.userEmail : 'Người dùng');
    final isUpdating = _updatingShareId == share.id;
    final isRemoving = _removingShareId == share.id;

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: Colors.purple.shade100,
              child: Text(
                name[0].toUpperCase(),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.purple,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  if (share.userEmail.isNotEmpty)
                    Text(
                      share.userEmail,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                ],
              ),
            ),
            if (isUpdating)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            else
              DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: share.permission == 'editor' ? 'editor' : 'viewer',
                  isDense: true,
                  style: const TextStyle(fontSize: 12, color: Colors.black87),
                  items: const [
                    DropdownMenuItem(value: 'viewer', child: Text('Chỉ xem')),
                    DropdownMenuItem(value: 'editor', child: Text('Chỉnh sửa')),
                  ],
                  onChanged: _updatingShareId != null
                      ? null
                      : (value) {
                          if (value != null) _updatePermission(share, value);
                        },
                ),
              ),
            if (isRemoving)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            else
              IconButton(
                icon: const Icon(Icons.person_remove_outlined, color: Colors.red),
                tooltip: 'Thu hồi quyền chia sẻ',
                onPressed: _removingShareId != null ? null : () => _confirmRemove(share),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCandidateTile(User user) {
    final selected = _selectedIds.contains(user.id);

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: Colors.blue.shade100,
        child: Text(
          user.fullName.isNotEmpty ? user.fullName[0].toUpperCase() : 'U',
          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue),
        ),
      ),
      title: Text(user.fullName),
      subtitle: Text(user.email),
      trailing: Icon(
        selected ? Icons.check_circle : Icons.add_circle_outline,
        color: selected ? Colors.green : Colors.blue,
      ),
      onTap: _isSharing ? null : () => _toggleCandidate(user),
    );
  }

  Widget _buildNewPermissionDropdown() {
    return InputDecorator(
      decoration: const InputDecoration(
        labelText: 'Quyền khi chia sẻ',
        border: OutlineInputBorder(),
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          isExpanded: true,
          value: _newPermission,
          items: const [
            DropdownMenuItem(value: 'viewer', child: Text('Chỉ xem')),
            DropdownMenuItem(value: 'editor', child: Text('Chỉnh sửa')),
          ],
          onChanged: _isSharing
              ? null
              : (value) {
                  if (value != null) setState(() => _newPermission = value);
                },
        ),
      ),
    );
  }
}

// Chỉ giữ những người còn có thể chia sẻ: bỏ chính mình, người tạo và người
// đã có trong danh sách chia sẻ.
List<User> filterShareCandidates({
  required List<User> users,
  required Set<String> excludedIds,
}) {
  return users.where((user) => !excludedIds.contains(user.id)).toList();
}

String sharePermissionLabel(String permission) {
  return permission == 'editor' ? 'Chỉnh sửa' : 'Chỉ xem';
}
