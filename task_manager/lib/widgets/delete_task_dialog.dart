import 'package:flutter/material.dart';

/// Hiển thị hộp thoại xác nhận xóa công việc.
/// Trả về `true` nếu người dùng bấm "Xóa", ngược lại `false`.
Future<bool> showDeleteTaskDialog(BuildContext context, String taskTitle) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Xóa công việc'),
      content: Text(
        'Bạn có chắc muốn xóa công việc "$taskTitle"?\n'
        'Hành động này không thể hoàn tác.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Hủy'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: Colors.red),
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Xóa'),
        ),
      ],
    ),
  );

  return result ?? false;
}
