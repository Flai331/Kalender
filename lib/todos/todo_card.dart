import 'package:flutter/material.dart';
import '../app_colors.dart';
import '../models/todo.dart';
import '../models/calendar_event.dart' show RepeatType;

/// Draggable Todo-Karte für den Todo-Pool
class TodoCard extends StatelessWidget {
  final Todo todo;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const TodoCard({
    super.key,
    required this.todo,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Draggable<Todo>(
      data: todo,
      feedback: Material(
        color: Colors.transparent,
        child: _CardContent(todo: todo, isDragging: true),
      ),
      childWhenDragging: Opacity(
        opacity: 0.3,
        child: _CardContent(todo: todo),
      ),
      child: Dismissible(
        key: Key(todo.id),
        direction: DismissDirection.endToStart,
        onDismissed: (_) => onDelete(),
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 16),
          decoration: BoxDecoration(
            color: Colors.red.withOpacity(0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.delete, color: Colors.redAccent),
        ),
        child: GestureDetector(
          onTap: onTap,
          child: _CardContent(todo: todo),
        ),
      ),
    );
  }
}

class _CardContent extends StatelessWidget {
  final Todo todo;
  final bool isDragging;

  const _CardContent({required this.todo, this.isDragging = false});

  @override
  Widget build(BuildContext context) {
    final color = AppColors.forCategory(todo.category);
    return Container(
      width: isDragging ? 200 : null,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDragging ? AppColors.card.withOpacity(0.95) : AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border(left: BorderSide(color: color, width: 3)),
        boxShadow: isDragging
            ? [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                )
              ]
            : null,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  todo.title,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (todo.description.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    todo.description,
                    style: const TextStyle(
                        color: AppColors.textSecondary, fontSize: 12),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Zeitansatz-Badge
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              _formatDuration(todo.estimatedMinutes),
              style: TextStyle(
                  color: color,
                  fontSize: 11,
                  fontWeight: FontWeight.w600),
            ),
          ),
          if (todo.repeatType != RepeatType.none) ...[
            const SizedBox(width: 4),
            const Icon(Icons.repeat, size: 14, color: AppColors.textSecondary),
          ],
          if (todo.isFixed) ...[
            const SizedBox(width: 4),
            const Icon(Icons.lock, size: 14, color: AppColors.fixedTag),
          ],
          const SizedBox(width: 4),
          // Drag-Handle-Icon
          if (!isDragging)
            const Icon(Icons.drag_indicator,
                size: 18, color: AppColors.textDisabled),
        ],
      ),
    );
  }

  String _formatDuration(int minutes) {
    if (minutes < 60) return '${minutes}m';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return m > 0 ? '${h}h${m}m' : '${h}h';
  }
}
