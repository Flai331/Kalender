import 'package:flutter/material.dart';
import '../app_colors.dart';
import '../models/calendar_event.dart';
import '../models/todo.dart';

/// Visueller Block für einen Termin oder ein Todo in der Wochenansicht
class EventBlock extends StatelessWidget {
  final CalendarEvent? event;
  final Todo? todo;
  final VoidCallback? onTap;
  final double heightPerMinute;

  const EventBlock({
    super.key,
    this.event,
    this.todo,
    this.onTap,
    this.heightPerMinute = 1.0,
  }) : assert(event != null || todo != null);

  @override
  Widget build(BuildContext context) {
    final title = event?.title ?? todo?.title ?? '';
    final isFixed = event?.isFixed ?? todo?.isFixed ?? false;
    final category = event?.category.name ?? todo?.category ?? 'personal';
    final status = event?.status ?? _todoStatus;
    final durationMinutes = event != null
        ? event!.scheduledDuration.inMinutes
        : (todo?.estimatedMinutes ?? 30);

    final color = _colorForStatus(status, category);
    final height = (durationMinutes * heightPerMinute).clamp(24.0, 200.0);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: height,
        margin: const EdgeInsets.symmetric(horizontal: 1, vertical: 1),
        decoration: BoxDecoration(
          color: color.withOpacity(0.2),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color, width: 1.5),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        child: Row(
          children: [
            if (isFixed)
              const Padding(
                padding: EdgeInsets.only(right: 3),
                child: Icon(Icons.lock, size: 10, color: AppColors.fixedTag),
              ),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 11,
                  color: color,
                  fontWeight: FontWeight.w600,
                  decoration: status == EventStatus.done
                      ? TextDecoration.lineThrough
                      : null,
                ),
                maxLines: durationMinutes >= 45 ? 2 : 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            _statusIcon(status),
          ],
        ),
      ),
    );
  }

  EventStatus? get _todoStatus {
    switch (todo?.status) {
      case TodoStatus.started:
        return EventStatus.started;
      case TodoStatus.paused:
        return EventStatus.paused;
      case TodoStatus.done:
        return EventStatus.done;
      default:
        return EventStatus.pending;
    }
  }

  Color _colorForStatus(EventStatus? status, String category) {
    switch (status) {
      case EventStatus.started:
        return AppColors.started;
      case EventStatus.paused:
        return AppColors.paused;
      case EventStatus.done:
        return AppColors.done;
      default:
        return AppColors.forCategory(category);
    }
  }

  Widget _statusIcon(EventStatus? status) {
    switch (status) {
      case EventStatus.started:
        return const Icon(Icons.play_arrow, size: 12, color: AppColors.started);
      case EventStatus.paused:
        return const Icon(Icons.pause, size: 12, color: AppColors.paused);
      case EventStatus.done:
        return const Icon(Icons.check, size: 12, color: AppColors.done);
      default:
        return const SizedBox.shrink();
    }
  }
}
