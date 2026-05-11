import 'package:flutter/material.dart';
import '../app_colors.dart';
import '../models/todo.dart';
import '../models/calendar_event.dart';
import 'event_block.dart';

/// Eine Tagesspalte in der Wochenansicht.
/// Akzeptiert Drag-and-Drop von Todos aus dem Todo-Pool.
class WeekDayColumn extends StatelessWidget {
  final DateTime day;
  final List<CalendarEvent> events;
  final List<Todo> todos;
  final bool isToday;
  final double hourHeight;
  final int startHour;
  final int endHour;
  final Function(Todo todo, DateTime day, int hour, int minute) onTodoDrop;
  final Function(CalendarEvent event, DateTime day, int hour, int minute) onEventDrop;
  final Function(CalendarEvent event) onEventTap;
  final Function(Todo todo) onTodoTap;

  const WeekDayColumn({
    super.key,
    required this.day,
    required this.events,
    required this.todos,
    required this.isToday,
    required this.hourHeight,
    required this.startHour,
    required this.endHour,
    required this.onTodoDrop,
    required this.onEventDrop,
    required this.onEventTap,
    required this.onTodoTap,
  });

  double get _minuteHeight => hourHeight / 60.0;
  int get _totalHours => endHour - startHour;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Tages-Header
        _DayHeader(day: day, isToday: isToday),
        // Zeitgitter
        Expanded(
          child: Stack(
            children: [
              // Hintergrund-Gitter mit DragTargets
              _buildGrid(),
              // Events
              ..._buildEventBlocks(),
              // Todos
              ..._buildTodoBlocks(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildGrid() {
    return SizedBox(
      height: _totalHours * hourHeight,
      child: Stack(
        children: List.generate(_totalHours, (i) {
          final hour = startHour + i;
          final top = i * hourHeight;
          return Positioned(
            top: top,
            left: 0,
            right: 0,
            height: hourHeight,
            child: DragTarget<Object>(
              onAcceptWithDetails: (details) {
                if (details.data is Todo) {
                  onTodoDrop(details.data as Todo, day, hour, 0);
                } else if (details.data is CalendarEvent) {
                  onEventDrop(details.data as CalendarEvent, day, hour, 0);
                }
              },
              builder: (ctx, candidateData, rejectedData) {
                final isHighlighted = candidateData.isNotEmpty;
                return Container(
                  decoration: BoxDecoration(
                    color: isHighlighted
                        ? AppColors.primary.withOpacity(0.15)
                        : Colors.transparent,
                    border: Border(
                      top: BorderSide(
                        color: AppColors.divider.withOpacity(0.4),
                        width: 0.5,
                      ),
                    ),
                  ),
                );
              },
            ),
          );
        }),
      ),
    );
  }

  List<Widget> _buildEventBlocks() {
    return events.map((event) {
      final startMinutes =
          (event.startTime.hour - startHour) * 60 + event.startTime.minute;
      final top = startMinutes * _minuteHeight;
      final durationMinutes = event.scheduledDuration.inMinutes;
      final height = (durationMinutes * _minuteHeight).clamp(20.0, 500.0);

      return Positioned(
        top: top,
        left: 2,
        right: 2,
        height: height,
        child: LongPressDraggable<CalendarEvent>(
          data: event,
          feedback: Material(
            color: Colors.transparent,
            child: Opacity(
              opacity: 0.8,
              child: SizedBox(
                width: 80,
                height: height,
                child: EventBlock(
                  event: event,
                  onTap: () {},
                  heightPerMinute: _minuteHeight,
                ),
              ),
            ),
          ),
          childWhenDragging: Opacity(
            opacity: 0.3,
            child: EventBlock(
              event: event,
              onTap: () {},
              heightPerMinute: _minuteHeight,
            ),
          ),
          child: EventBlock(
            event: event,
            onTap: () => onEventTap(event),
            heightPerMinute: _minuteHeight,
          ),
        ),
      );
    }).toList();
  }

  List<Widget> _buildTodoBlocks() {
    return todos.where((t) => t.scheduledStartHour != null).map((todo) {
      final startMinutes = ((todo.scheduledStartHour ?? 0) - startHour) * 60 +
          (todo.scheduledStartMinute ?? 0);
      final top = startMinutes * _minuteHeight;
      final height =
          (todo.estimatedMinutes * _minuteHeight).clamp(20.0, 500.0);

      return Positioned(
        top: top,
        left: 2,
        right: 2,
        height: height,
        child: EventBlock(
          todo: todo,
          onTap: () => onTodoTap(todo),
          heightPerMinute: _minuteHeight,
        ),
      );
    }).toList();
  }
}

class _DayHeader extends StatelessWidget {
  final DateTime day;
  final bool isToday;

  const _DayHeader({required this.day, required this.isToday});

  static const _weekdays = ['Mo', 'Di', 'Mi', 'Do', 'Fr', 'Sa', 'So'];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: isToday ? AppColors.primary.withOpacity(0.15) : Colors.transparent,
        border: Border(
          bottom: BorderSide(color: AppColors.divider, width: 0.5),
        ),
      ),
      child: Column(
        children: [
          Text(
            _weekdays[day.weekday - 1],
            style: TextStyle(
              fontSize: 11,
              color: isToday ? AppColors.primary : AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 2),
          Container(
            width: 28,
            height: 28,
            decoration: isToday
                ? const BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.primary,
                  )
                : null,
            alignment: Alignment.center,
            child: Text(
              '${day.day}',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: isToday ? Colors.white : AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
