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
                    child: Icon(Icons.location_on, size: 10, color: color.withValues(alpha: 0.8)),
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
                  color: color.withValues(alpha: 0.85),
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
      final start = _hm(s.hour, s.minute);
      final end   = _hm(e.hour, e.minute);
      final before = event!.travelMinutesBefore;
      final after  = event!.travelMinutesAfter;
      final depart = before > 0
          ? _addMin(s.hour * 60 + s.minute - before)
          : null;
      final returnArrival = after > 0
          ? _addMin(e.hour * 60 + e.minute + after)
          : null;
      final parts = [
        if (depart != null) '🚗$depart',
        '$start – $end',
        if (returnArrival != null) '🏠$returnArrival',
      ];
      return parts.join('  ');
    }
    if (todo != null && todo!.scheduledStartHour != null) {
      final sh = todo!.scheduledStartHour!;
      final sm = todo!.scheduledStartMinute ?? 0;
      final total = sh * 60 + sm + todo!.estimatedMinutes;
      final eh = total ~/ 60;
      final em = total % 60;
      final start = _hm(sh, sm);
      final end   = _hm(eh % 24, em);
      final before = todo!.travelMinutesBefore;
      final after  = todo!.travelMinutesAfter;
      final depart = before > 0
          ? _addMin(sh * 60 + sm - before)
          : null;
      final returnArrival = after > 0
          ? _addMin(total + after)
          : null;
      final parts = [
        if (depart != null) '🚗$depart',
        '$start – $end',
        if (returnArrival != null) '🏠$returnArrival',
      ];
      return parts.join('  ');
    }
    return null;
  }

  static String _hm(int h, int m) =>
      '${(h % 24).toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';

  static String _addMin(int totalMin) {
    final h = (totalMin ~/ 60) % 24;
    final m = totalMin % 60;
    if (h < 0 || m < 0) {
      // negative = before midnight
      final abs = totalMin.abs();
      return _hm(24 - abs ~/ 60 - (abs % 60 > 0 ? 1 : 0), (60 - abs % 60) % 60);
    }
    return _hm(h, m);
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
