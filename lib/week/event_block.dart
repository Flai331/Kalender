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
  final bool isDropTarget;

  const EventBlock({
    super.key,
    this.event,
    this.todo,
    this.onTap,
    this.heightPerMinute = 1.0,
    this.isDropTarget = false,
  }) : assert(event != null || todo != null);

  @override
  Widget build(BuildContext context) {
    final title = event?.title ?? todo?.title ?? '';
    final isFixed = event?.isFixed ?? todo?.isFixed ?? false;
    final category = event?.category.name ?? todo?.category ?? 'personal';
    final hasAddress = (event?.address ?? todo?.address) != null;
    final status = event?.status ?? _todoStatus;
    final durationMinutes = event != null
        ? event!.scheduledDuration.inMinutes
        : (todo?.estimatedMinutes ?? 30);

    final color = event?.calendarColor != null
        ? Color(event!.calendarColor!)
        : _colorForStatus(status, category);
    final height = (durationMinutes * heightPerMinute).clamp(24.0, 200.0);
    final showTime = height >= 36;
    final timeStr = _timeString();

    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: height,
        margin: const EdgeInsets.symmetric(horizontal: 1, vertical: 1),
        clipBehavior: Clip.hardEdge,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(6),
          border: isDropTarget
              ? Border.all(color: Colors.white.withValues(alpha: 0.8), width: 2)
              : Border.all(color: color, width: 1.5),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                if (isFixed)
                  const Padding(
                    padding: EdgeInsets.only(right: 3),
                    child: Icon(Icons.lock, size: 10, color: AppColors.fixedTag),
                  ),
                if (hasAddress)
                  Padding(
                    padding: const EdgeInsets.only(right: 3),
                    child: Icon(Icons.location_on, size: 10, color: color.withOpacity(0.8)),
                  ),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 12,
                      color: color,
                      fontWeight: FontWeight.w600,
                      decoration: status == EventStatus.done
                          ? TextDecoration.lineThrough
                          : null,
                    ),
                    maxLines: (showTime || durationMinutes >= 45) ? 2 : 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                _statusIcon(status),
              ],
            ),
            if (showTime && timeStr != null)
              Text(
                timeStr,
                style: TextStyle(
                  fontSize: 9,
                  color: color.withOpacity(0.85),
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
          ],
        ),
      ),
    );
  }

  String? _timeString() {
    if (event != null) {
      final s = event!.startTime;
      final e = event!.endTime;
      final start = '${s.hour.toString().padLeft(2, '0')}:${s.minute.toString().padLeft(2, '0')}';
      final end   = '${e.hour.toString().padLeft(2, '0')}:${e.minute.toString().padLeft(2, '0')}';
      return '$start – $end';
    }
    if (todo != null && todo!.scheduledStartHour != null) {
      final sh = todo!.scheduledStartHour!;
      final sm = todo!.scheduledStartMinute ?? 0;
      final total = sh * 60 + sm + todo!.estimatedMinutes;
      final eh = total ~/ 60;
      final em = total % 60;
      final start = '${sh.toString().padLeft(2, '0')}:${sm.toString().padLeft(2, '0')}';
      final end   = '${(eh % 24).toString().padLeft(2, '0')}:${em.toString().padLeft(2, '0')}';
      return '$start – $end';
    }
    return null;
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
