import 'package:flutter/material.dart';
import '../app_colors.dart';

class TimeShiftDialog extends StatelessWidget {
  final int savedMinutes;
  final VoidCallback onKeepBuffer;
  final VoidCallback onShiftTodos;

  const TimeShiftDialog({
    super.key,
    required this.savedMinutes,
    required this.onKeepBuffer,
    required this.onShiftTodos,
  });

  static Future<bool?> show({
    required BuildContext context,
    required int savedMinutes,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => TimeShiftDialog(
        savedMinutes: savedMinutes,
        onKeepBuffer: () => Navigator.pop(ctx, false),
        onShiftTodos: () => Navigator.pop(ctx, true),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final minutes = savedMinutes;
    final label = minutes >= 60
        ? '${minutes ~/ 60}h ${minutes % 60 > 0 ? '${minutes % 60}min' : ''}'
        : '${minutes}min';

    return AlertDialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          const Icon(Icons.timer_outlined, color: AppColors.started, size: 22),
          const SizedBox(width: 8),
          Text(
            '$label gespart! 🎉',
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 17,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
      content: const Text(
        'Du bist früher fertig. Was soll mit der gewonnenen Zeit passieren?',
        style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
      ),
      actionsAlignment: MainAxisAlignment.spaceEvenly,
      actions: [
        OutlinedButton.icon(
          onPressed: onKeepBuffer,
          icon: const Icon(Icons.free_breakfast_outlined,
              size: 16, color: AppColors.textSecondary),
          label: const Text('Puffer lassen',
              style: TextStyle(color: AppColors.textSecondary)),
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: AppColors.divider),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8)),
          ),
        ),
        ElevatedButton.icon(
          onPressed: onShiftTodos,
          icon: const Icon(Icons.skip_next, size: 16),
          label: const Text('Termine vorziehen'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8)),
          ),
        ),
      ],
    );
  }
}
