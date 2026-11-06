import 'dart:async';

import 'package:flutter/material.dart';

import '../../models/task.dart';
import '../../models/user.dart';
import '../../services/auth_service.dart';
import '../../services/task_api_service.dart';
import '../../services/user_service.dart';

class TaskAssignScreen extends StatefulWidget {
  final Task task;

  const TaskAssignScreen({super.key, required this.task});

  @override
  State<TaskAssignScreen> createState() => _TaskAssignScreenState();
}

class _TaskAssignScreenState extends State<TaskAssignScreen> {
  final TaskApiService _apiService = TaskApiService();
  final UserService _userService = UserService();
  final AuthService _authService = AuthService();
  final TextEditingController _searchController = TextEditingController();

  // Debounce để không gọi API tìm kiếm trên mỗi ký tự gõ.
  Timer? _searchTimer;

  late final Set<String> _originalIds;
  late final Set<String> _selectedIds;

  // Giữ thông tin hiển thị của cả người đã giao lẫn kết quả tìm kiếm.
  final Map<String, TaskAssignee> _people = {};

  String? _primaryId;
  String? _currentUserId;
  List<User> _searchResults = [];
  bool _isSearching = false;
  bool _isSaving = false;
  String? _searchError;

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
    _originalIds = widget.task.assignees.map((a) => a.id).toSet();
    _selectedIds = {..._originalIds};
    for (final assignee in widget.task.assignees) {
      _people[assignee.id] = assignee;
    }

    final primary = widget.task.primaryAssigneeId;
    _primaryId = (primary != null && _selectedIds.contains(primary)) ? primary : null;
  }

  Future<void> _loadCurrentUser() async {
    final user = await _authService.getCurrentUser();
    if (!mounted) return;
    setState(() {
      _currentUserId = user?.id;
      // Nếu kết quả tìm kiếm về trước khi biết user hiện tại, loại mình ra luôn.
      _searchResults = filterAssignCandidates(
        users: _searchResults,
        currentUserId: _currentUserId,
      );
    });
  }

  @override
  void dispose() {
    _searchTimer?.cancel();
    _searchController.dispose();
    super.dispose();
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
        _searchResults = filterAssignCandidates(
          users: results,
          currentUserId: _currentUserId,
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

  void _toggleUser(User user) {
    // Phòng trường hợp dữ liệu tìm kiếm cũ: không cho tự giao việc cho mình.
    if (user.id == _currentUserId) return;

    setState(() {
      if (_selectedIds.contains(user.id)) {
        _removeSelected(user.id);
        return;
      }

      _selectedIds.add(user.id);
      _people[user.id] = TaskAssignee(
        id: user.id,
        fullName: user.fullName,
        email: user.email,
      );
      // Người đầu tiên được chọn mặc định làm phụ trách chính cho tiện.
      _primaryId ??= user.id;
    });
  }

  void _removeSelected(String id) {
    _selectedIds.remove(id);
    // Bỏ người đang là phụ trách chính thì chọn người còn lại đầu tiên.
    if (_primaryId == id) {
      _primaryId = _selectedIds.isEmpty ? null : _selectedIds.first;
    }
  }

  Future<void> _confirmAssign() async {
    if (_isSaving) return;

    final change = buildAssigneeChange(
      originalIds: _originalIds,
      selectedIds: _selectedIds,
      originalPrimaryId: widget.task.primaryAssigneeId,
      primaryId: _primaryId,
    );

    setState(() => _isSaving = true);

    // 1. Hủy giao việc cho những người bị bỏ chọn.
    for (final userId in change.removed) {
      final result = await _apiService.removeAssignee(widget.task.id, userId);
      if (!mounted) return;
      if (result['success'] != true) {
        _showError(result['message'] ?? 'Hủy giao việc thất bại');
        return;
      }
    }

    // 2. Thêm người mới; nếu phụ trách chính mới nằm trong nhóm này thì gửi kèm.
    if (change.added.isNotEmpty) {
      final result = await _apiService.assignUsers(
        widget.task.id,
        change.added.toList(),
        primaryAssigneeId: change.primaryInAdded ? change.primaryAssigneeId : null,
      );
      if (!mounted) return;
      if (result['success'] != true) {
        _showError(result['message'] ?? 'Giao việc thất bại');
        return;
      }
    }

    // 3. Đổi phụ trách chính sang người đã được giao từ trước.
    if (change.shouldSetPrimary) {
      final result = await _apiService.setPrimaryAssignee(
        widget.task.id,
        change.primaryAssigneeId!,
      );
      if (!mounted) return;
      if (result['success'] != true) {
        _showError(result['message'] ?? 'Cập nhật người phụ trách chính thất bại');
        return;
      }
    }

    setState(() => _isSaving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Giao việc thành công'),
        backgroundColor: Colors.green,
      ),
    );
    Navigator.pop(context, true);
  }

  void _showError(String message) {
    setState(() => _isSaving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Giao công việc')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSelectedSection(),
          const SizedBox(height: 16),
          if (_selectedIds.isNotEmpty) ...[
            _buildPrimaryDropdown(),
            const SizedBox(height: 20),
          ],
          _buildSearchSection(),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _isSaving ? null : _confirmAssign,
            icon: _isSaving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.check),
            label: Text(_isSaving ? 'Đang lưu...' : 'Xác nhận giao việc'),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectedSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Người được giao (${_selectedIds.length})',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        ),
        const SizedBox(height: 8),
        if (_selectedIds.isEmpty)
          Card(
            elevation: 0,
            color: Colors.grey.shade100,
            child: const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Chưa có ai được giao công việc này.'),
            ),
          )
        else
          Card(
            elevation: 1,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Column(
              children: _selectedIds.map(_buildSelectedTile).toList(),
            ),
          ),
      ],
    );
  }

  Widget _buildSelectedTile(String id) {
    final person = _people[id];
    final name = person?.fullName.isNotEmpty == true ? person!.fullName : 'Người dùng';
    final isPrimary = id == _primaryId;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      leading: CircleAvatar(
        backgroundColor: isPrimary ? Colors.amber.shade100 : Colors.teal.shade100,
        child: Text(
          name[0].toUpperCase(),
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: isPrimary ? Colors.orange.shade800 : Colors.teal,
          ),
        ),
      ),
      title: Row(
        children: [
          Flexible(child: Text(name)),
          if (isPrimary) ...[
            const SizedBox(width: 6),
            const Icon(Icons.star, size: 16, color: Colors.orange),
          ],
        ],
      ),
      subtitle: person != null && person.email.isNotEmpty ? Text(person.email) : null,
      trailing: IconButton(
        icon: const Icon(Icons.close),
        tooltip: 'Bỏ giao việc',
        onPressed: _isSaving ? null : () => setState(() => _removeSelected(id)),
      ),
    );
  }

  Widget _buildPrimaryDropdown() {
    return InputDecorator(
      decoration: const InputDecoration(
        labelText: 'Người phụ trách chính',
        border: OutlineInputBorder(),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          isExpanded: true,
          value: _primaryId,
          hint: const Text('Chọn người phụ trách chính'),
          items: _selectedIds.map((id) {
            final person = _people[id];
            return DropdownMenuItem(
              value: id,
              child: Text(
                person != null && person.fullName.isNotEmpty ? person.fullName : 'Người dùng',
              ),
            );
          }).toList(),
          onChanged: _isSaving
              ? null
              : (value) => setState(() => _primaryId = value),
        ),
      ),
    );
  }

  Widget _buildSearchSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
          ..._searchResults.map(_buildResultTile),
      ],
    );
  }

  Widget _buildResultTile(User user) {
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
      onTap: _isSaving ? null : () => _toggleUser(user),
    );
  }
}

// Không cho giao việc cho chính người đang đăng nhập.
List<User> filterAssignCandidates({
  required List<User> users,
  required String? currentUserId,
}) {
  if (currentUserId == null) return users;
  return users.where((user) => user.id != currentUserId).toList();
}

// Kết quả tính toán khi xác nhận giao việc.
// Tách khỏi UI để unit test được phần logic quan trọng.
class AssigneeChange {
  final Set<String> added;
  final Set<String> removed;
  final String? primaryAssigneeId;
  final bool primaryInAdded;
  final bool shouldSetPrimary;

  const AssigneeChange({
    required this.added,
    required this.removed,
    required this.primaryAssigneeId,
    required this.primaryInAdded,
    required this.shouldSetPrimary,
  });
}

AssigneeChange buildAssigneeChange({
  required Set<String> originalIds,
  required Set<String> selectedIds,
  required String? originalPrimaryId,
  required String? primaryId,
}) {
  final added = selectedIds.difference(originalIds);
  final removed = originalIds.difference(selectedIds);

  // Chỉ chấp nhận phụ trách chính còn nằm trong danh sách được chọn.
  final effectivePrimary =
      (primaryId != null && selectedIds.contains(primaryId)) ? primaryId : null;

  final primaryChanged = effectivePrimary != originalPrimaryId;
  final primaryInAdded = effectivePrimary != null && added.contains(effectivePrimary);

  return AssigneeChange(
    added: added,
    removed: removed,
    primaryAssigneeId: effectivePrimary,
    primaryInAdded: primaryInAdded,
    shouldSetPrimary: primaryChanged && effectivePrimary != null && !primaryInAdded,
  );
}
