import 'package:flutter/material.dart';
import '../app_colors.dart';
import '../models/calendar_event.dart';

class EventStatusDialog extends StatelessWidget {
  final CalendarEvent event;

  const EventStatusDialog({super.key, required this.event});

  static Future<String?> show({
    required BuildContext context,
    required CalendarEvent event,
  }) {
    return showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => EventStatusDialog(event: event),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.forCategory(event.category.name),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  event.title,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
              if (event.isFixed)
                const Icon(Icons.lock, size: 14, color: AppColors.fixedTag),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            _timeLabel,
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 16),
          const Divider(color: AppColors.divider),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _buildActions(context),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  String get _timeLabel {
    final s = event.startTime;
    final e = event.endTime;
    return '${s.hour.toString().padLeft(2, '0')}:${s.minute.toString().padLeft(2, '0')} – '
        '${e.hour.toString().padLeft(2, '0')}:${e.minute.toString().padLeft(2, '0')}';
  }

  List<Widget> _buildActions(BuildContext context) {
    final actions = <Widget>[];

    if (event.status == EventStatus.pending) {
      actions.add(_ActionChip(
        label: 'Starten',
        icon: Icons.play_arrow,
        color: AppColors.started,
        onTap: () => Navigator.pop(context, 'start'),
      ));
    }
    if (event.status == EventStatus.started) {
      actions.add(_ActionChip(
        label: 'Pause',
        icon: Icons.pause,
        color: AppColors.paused,
        onTap: () => Navigator.pop(context, 'pause'),
      ));
      actions.add(_ActionChip(
        label: 'Fertig',
        icon: Icons.check_circle,
        color: AppColors.started,
        onTap: () => Navigator.pop(context, 'done'),
      ));
    }
    if (event.status == EventStatus.paused) {
      actions.add(_ActionChip(
        label: 'Weiter',
        icon: Icons.play_arrow,
        color: AppColors.started,
        onTap: () => Navigator.pop(context, 'resume'),
      ));
    }
    if (event.status == EventStatus.done) {
      actions.add(_ActionChip(
        label: 'Wieder öffnen',
        icon: Icons.undo,
        color: AppColors.textSecondary,
        onTap: () => Navigator.pop(context, 'reopen'),
      ));
    }

    actions.add(_ActionChip(
      label: 'Bearbeiten',
      icon: Icons.edit_outlined,
      color: AppColors.textSecondary,
      onTap: () => Navigator.pop(context, 'edit'),
    ));
    actions.add(_ActionChip(
      label: 'Löschen',
      icon: Icons.delete_outline,
      color: Colors.redAccent,
      onTap: () => Navigator.pop(context, 'delete'),
    ));

    return actions;
  }
}

class _ActionChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ActionChip({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: color),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(color: color, fontSize: 13)),
          ],
        ),
      ),
    );
  }
}
