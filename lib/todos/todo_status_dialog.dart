import 'package:flutter/material.dart';
import '../app_colors.dart';
import '../models/todo.dart';
import '../services/supabase_service.dart';

class TodoStatusDialog extends StatefulWidget {
  final Todo todo;

  const TodoStatusDialog({super.key, required this.todo});

  static Future<String?> show({
    required BuildContext context,
    required Todo todo,
  }) {
    return showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => TodoStatusDialog(todo: todo),
    );
  }

  @override
  State<TodoStatusDialog> createState() => _TodoStatusDialogState();
}

class _TodoStatusDialogState extends State<TodoStatusDialog> {
  late List<SubTask> _subTasks;

  @override
  void initState() {
    super.initState();
    _subTasks = List.from(widget.todo.subTasks);
  }

  void _toggleSubTask(String id, bool isDone) {
    final prev = List<SubTask>.from(_subTasks);
    final newSubTasks = _subTasks
        .map((s) => s.id == id ? s.copyWith(isDone: isDone) : s)
        .toList();
    setState(() => _subTasks = newSubTasks);
    SupabaseService.saveTodo(widget.todo.copyWith(subTasks: newSubTasks))
        .catchError((_) {
      // rollback on save failure
      if (mounted) setState(() => _subTasks = prev);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
          20, 20, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
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
                  color: AppColors.forCategory(widget.todo.category),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  widget.todo.title,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
              if (widget.todo.isFixed)
                const Icon(Icons.lock, size: 14, color: AppColors.fixedTag),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            _timeInfo(),
            style: const TextStyle(
                color: AppColors.textSecondary, fontSize: 13),
          ),
          if (_subTasks.isNotEmpty) ...[
            const SizedBox(height: 8),
            const Divider(color: AppColors.divider),
            ..._subTasks.map((s) => CheckboxListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  value: s.isDone,
                  activeColor: AppColors.primary,
                  title: Text(
                    s.title,
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 14,
                      decoration: s.isDone ? TextDecoration.lineThrough : null,
                    ),
                  ),
                  onChanged: (val) => _toggleSubTask(s.id, val ?? false),
                )),
          ],
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

  String _timeInfo() {
    if (widget.todo.scheduledStartHour != null) {
      final sh = widget.todo.scheduledStartHour!;
      final sm = widget.todo.scheduledStartMinute ?? 0;
      final total = sh * 60 + sm + widget.todo.estimatedMinutes;
      final eh = (total ~/ 60) % 24;
      final em = total % 60;
      final start = '${sh.toString().padLeft(2, '0')}:${sm.toString().padLeft(2, '0')}';
      final end   = '${eh.toString().padLeft(2, '0')}:${em.toString().padLeft(2, '0')}';
      return '$start – $end  ·  ${widget.todo.estimatedMinutes} Min';
    }
    return '${widget.todo.estimatedMinutes} Min geplant';
  }

  List<Widget> _buildActions(BuildContext context) {
    final actions = <Widget>[];

    if (widget.todo.status == TodoStatus.pending) {
      actions.add(_Chip(
        label: 'Starten',
        icon: Icons.play_arrow,
        color: AppColors.started,
        onTap: () => Navigator.pop(context, 'start'),
      ));
    }
    if (widget.todo.status == TodoStatus.started) {
      actions.add(_Chip(
        label: 'Pause',
        icon: Icons.pause,
        color: AppColors.paused,
        onTap: () => Navigator.pop(context, 'pause'),
      ));
      actions.add(_Chip(
        label: 'Fertig ✓',
        icon: Icons.check_circle,
        color: AppColors.started,
        onTap: () => Navigator.pop(context, 'done'),
      ));
    }
    if (widget.todo.status == TodoStatus.paused) {
      actions.add(_Chip(
        label: 'Weiter',
        icon: Icons.play_arrow,
        color: AppColors.started,
        onTap: () => Navigator.pop(context, 'resume'),
      ));
    }
    if (widget.todo.status == TodoStatus.done) {
      actions.add(_Chip(
        label: 'Wieder öffnen',
        icon: Icons.undo,
        color: AppColors.textSecondary,
        onTap: () => Navigator.pop(context, 'reopen'),
      ));
    }

    if (widget.todo.isScheduled) {
      actions.add(_Chip(
        label: 'Aus Kalender entfernen',
        icon: Icons.event_busy,
        color: AppColors.textSecondary,
        onTap: () => Navigator.pop(context, 'unschedule'),
      ));
    }

    actions.add(_Chip(
      label: 'Bearbeiten',
      icon: Icons.edit_outlined,
      color: AppColors.primary,
      onTap: () => Navigator.pop(context, 'edit'),
    ));

    actions.add(_Chip(
      label: 'Löschen',
      icon: Icons.delete_outline,
      color: Colors.redAccent,
      onTap: () => Navigator.pop(context, 'delete'),
    ));

    return actions;
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _Chip({
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
