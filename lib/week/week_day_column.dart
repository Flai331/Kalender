import 'dart:async';
import 'package:flutter/material.dart';
import '../app_colors.dart';
import '../models/todo.dart';
import '../models/calendar_event.dart';
import 'event_block.dart';

// ── Overlap-Layout ────────────────────────────────────────────────────────────

class _ColInfo {
  final int col;
  final int numCols;
  const _ColInfo(this.col, this.numCols);
}

// ── Globaler Snap-State (spaltenübergreifend) ─────────────────────────────────

class SnapState {
  static const _levels = [30, 15, 5, 1];
  static int _index = 0;
  static Timer? _timer;

  static final snapNotifier = ValueNotifier<int>(30);
  static final isDraggingNotifier = ValueNotifier<bool>(false);
  static final currentTimeNotifier = ValueNotifier<String>('');

  static int get current => snapNotifier.value;

  static void resume() {
    isDraggingNotifier.value = true;
    _runTimer();
  }

  static void pause() {
    _timer?.cancel();
    _timer = null;
  }

  static void _runTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(milliseconds: 1500), (t) {
      if (_index < _levels.length - 1) {
        _index++;
        snapNotifier.value = _levels[_index];
      } else {
        t.cancel();
      }
    });
  }

  static void stop() {
    _timer?.cancel();
    _index = 0;
    snapNotifier.value = _levels[0];
    isDraggingNotifier.value = false;
    currentTimeNotifier.value = '';
  }

  static void updateTime(int hour, int minute) {
    currentTimeNotifier.value =
        '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
  }

  static int snap(int rawMinutes, int totalHourMinutes) {
    final snapped = ((rawMinutes / current).round() * current);
    return snapped.clamp(0, totalHourMinutes - 1);
  }

  static double hourHeightForSnap(int snap) {
    switch (snap) {
      case 15: return 150.0;
      case 5:  return 360.0;
      case 1:  return 720.0;
      default: return 60.0;
    }
  }
}

// ── WeekDayColumn ─────────────────────────────────────────────────────────────

class WeekDayColumn extends StatefulWidget {
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
  final Function(Todo todo, CalendarEvent event)? onTodoDroppedOnEvent;
  final List<CalendarEvent> allDayEvents;
  final bool showHeader;

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
    this.onTodoDroppedOnEvent,
    this.allDayEvents = const [],
    this.showHeader = true,
  });

  @override
  State<WeekDayColumn> createState() => _WeekDayColumnState();
}

class _WeekDayColumnState extends State<WeekDayColumn> {
  final _gridKey = GlobalKey();
  Timer? _stillTimer;
  Timer? _acceptTimer;
  bool _dayAccepted = false;

  double get _minuteHeight => widget.hourHeight / 60.0;
  int get _totalHours => widget.endHour - widget.startHour;
  int get _totalMinutes => _totalHours * 60;

  void _onDragMove() {
    SnapState.pause();
    _stillTimer?.cancel();
    _stillTimer = Timer(const Duration(milliseconds: 600), SnapState.resume);
  }

  void _onDragEnd() {
    _stillTimer?.cancel();
    _stillTimer = null;
    _acceptTimer?.cancel();
    _acceptTimer = null;
    _dayAccepted = false;
    SnapState.stop();
  }

  @override
  void dispose() {
    _stillTimer?.cancel();
    _acceptTimer?.cancel();
    super.dispose();
  }

  // ── Overlap layout ────────────────────────────────────────────────────────

  Map<Object, _ColInfo> _computeOverlapLayout() {
    final dayStart = DateTime(widget.day.year, widget.day.month, widget.day.day);
    final dayEnd = dayStart.add(const Duration(days: 1));

    final items = <({int start, int end, Object item})>[];

    for (final event in widget.events) {
      final cs = event.startTime.isBefore(dayStart) ? dayStart : event.startTime;
      final ce = event.endTime.isAfter(dayEnd) ? dayEnd : event.endTime;
      final s = (cs.hour - widget.startHour) * 60 + cs.minute;
      final e = (ce.hour - widget.startHour) * 60 + ce.minute;
      if (e > s) items.add((start: s, end: e, item: event));
    }

    for (final todo in widget.todos.where((t) => t.scheduledStartHour != null)) {
      final ts = DateTime(
        todo.scheduledDate?.year ?? widget.day.year,
        todo.scheduledDate?.month ?? widget.day.month,
        todo.scheduledDate?.day ?? widget.day.day,
        todo.scheduledStartHour!,
        todo.scheduledStartMinute ?? 0,
      );
      final te = ts.add(Duration(minutes: todo.estimatedMinutes));
      final cs = ts.isBefore(dayStart) ? dayStart : ts;
      final ce = te.isAfter(dayEnd) ? dayEnd : te;
      final s = (cs.hour - widget.startHour) * 60 + cs.minute;
      final e = (ce.hour - widget.startHour) * 60 + ce.minute;
      if (e > s) items.add((start: s, end: e, item: todo));
    }

    if (items.isEmpty) return {};
    items.sort((a, b) => a.start.compareTo(b.start));

    final assignedCols = List<int>.filled(items.length, 0);
    final colEnds = <int>[];

    for (int i = 0; i < items.length; i++) {
      int assigned = -1;
      for (int c = 0; c < colEnds.length; c++) {
        if (colEnds[c] <= items[i].start) {
          assigned = c;
          colEnds[c] = items[i].end;
          break;
        }
      }
      if (assigned == -1) {
        assigned = colEnds.length;
        colEnds.add(items[i].end);
      }
      assignedCols[i] = assigned;
    }

    final result = <Object, _ColInfo>{};
    for (int i = 0; i < items.length; i++) {
      int maxCol = assignedCols[i];
      for (int j = 0; j < items.length; j++) {
        if (i == j) continue;
        if (items[j].start < items[i].end && items[j].end > items[i].start) {
          if (assignedCols[j] > maxCol) maxCol = assignedCols[j];
        }
      }
      result[items[i].item] = _ColInfo(assignedCols[i], maxCol + 1);
    }

    return result;
  }

  void _handleDrop(Object data, Offset globalOffset) {
    final box = _gridKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;
    final local = box.globalToLocal(globalOffset);
    final rawMinutes = (local.dy / _minuteHeight).clamp(0.0, _totalMinutes - 1.0).toInt();
    final snapped = SnapState.snap(rawMinutes, _totalMinutes);
    final hour = widget.startHour + snapped ~/ 60;
    final minute = snapped % 60;
    SnapState.stop();
    if (data is Todo) {
      widget.onTodoDrop(data, widget.day, hour, minute);
    } else if (data is CalendarEvent) {
      widget.onEventDrop(data, widget.day, hour, minute);
    }
  }

  @override
  Widget build(BuildContext context) {
    final grid = _buildGrid();
    if (!widget.showHeader) return grid;
    return Column(
      children: [
        _DayHeader(day: widget.day, isToday: widget.isToday),
        if (widget.allDayEvents.isNotEmpty)
          _AllDayBanner(events: widget.allDayEvents),
        Expanded(child: grid),
      ],
    );
  }

  Widget _buildGrid() {
    return LayoutBuilder(
      builder: (_, constraints) {
        final totalWidth = constraints.maxWidth;
        final layout = _computeOverlapLayout();
        return _buildGridInner(totalWidth, layout);
      },
    );
  }

  Widget _buildGridInner(double totalWidth, Map<Object, _ColInfo> layout) {
    return SizedBox(
      height: _totalHours * widget.hourHeight,
      child: DragTarget<Object>(
        onWillAcceptWithDetails: (_) => true,
        onAcceptWithDetails: (details) {
          _stillTimer?.cancel();
          _stillTimer = null;
          if (_dayAccepted) _handleDrop(details.data, details.offset);
        },
        onLeave: (_) {
          _acceptTimer?.cancel();
          _acceptTimer = null;
          _stillTimer?.cancel();
          _stillTimer = null;
          _dayAccepted = false;
        },
        onMove: (details) {
          if (!_dayAccepted && _acceptTimer == null) {
            final data = details.data;
            final isOwn = (data is CalendarEvent &&
                    data.startTime.year == widget.day.year &&
                    data.startTime.month == widget.day.month &&
                    data.startTime.day == widget.day.day) ||
                (data is Todo &&
                    data.scheduledDate?.year == widget.day.year &&
                    data.scheduledDate?.month == widget.day.month &&
                    data.scheduledDate?.day == widget.day.day);
            if (isOwn) {
              _dayAccepted = true;
            } else {
              _acceptTimer = Timer(const Duration(milliseconds: 250), () {
                _dayAccepted = true;
              });
            }
          }
          _onDragMove();
          final box = _gridKey.currentContext?.findRenderObject() as RenderBox?;
          if (box == null) return;
          final local = box.globalToLocal(details.offset);
          final rawMinutes = (local.dy / _minuteHeight).clamp(0.0, _totalMinutes - 1.0).toInt();
          final snapped = SnapState.snap(rawMinutes, _totalMinutes);
          final hour = widget.startHour + snapped ~/ 60;
          final minute = snapped % 60;
          SnapState.updateTime(hour, minute);
        },
        builder: (ctx, candidateData, rejectedData) {
          final isHighlighted = candidateData.isNotEmpty;
          return AnimatedBuilder(
            animation: Listenable.merge([SnapState.snapNotifier, SnapState.isDraggingNotifier]),
            builder: (ctx, _) {
              final snapMinutes = SnapState.snapNotifier.value;
              final dragging = SnapState.isDraggingNotifier.value;
              return Stack(
                key: _gridKey,
                children: [
                  // Stunden-Linien
                  ...List.generate(_totalHours, (i) {
                    return Positioned(
                      top: i * widget.hourHeight,
                      left: 0,
                      right: 0,
                      height: widget.hourHeight,
                      child: Container(
                        decoration: BoxDecoration(
                          color: isHighlighted
                              ? AppColors.primary.withValues(alpha: 0.1)
                              : Colors.transparent,
                          border: Border(
                            top: BorderSide(
                              color: AppColors.divider.withValues(alpha: 0.4),
                              width: 0.5,
                            ),
                          ),
                        ),
                      ),
                    );
                  }),

                  // Snap-Hilfslinien
                  if (dragging && snapMinutes < 60) ..._buildSnapLines(snapMinutes),

                  ..._buildEventBlocks(layout, totalWidth),
                  ..._buildTodoBlocks(layout, totalWidth),
                ],
              );
            },
          );
        },
      ),
    );
  }

  List<Widget> _buildSnapLines(int snapMinutes) {
    final lines = <Widget>[];
    // Linien bei jedem Snap-Intervall (außer volle Stunden, die schon gezeichnet)
    int interval = snapMinutes;
    int totalSlots = _totalMinutes ~/ interval;
    for (int i = 0; i <= totalSlots; i++) {
      final minutes = i * interval;
      if (minutes % 60 == 0) continue; // Stundenlinie schon vorhanden
      final top = minutes * _minuteHeight;
      final isQuarter = minutes % 15 == 0;
      final isFive = minutes % 5 == 0;
      lines.add(
        Positioned(
          top: top,
          left: 0,
          right: 0,
          child: Container(
            height: 0.5,
            color: isQuarter
                ? AppColors.divider.withValues(alpha: 0.45)
                : isFive
                    ? AppColors.divider.withValues(alpha: 0.3)
                    : AppColors.divider.withValues(alpha: 0.15),
          ),
        ),
      );
    }
    return lines;
  }

  List<Widget> _buildEventBlocks(Map<Object, _ColInfo> layout, double totalWidth) {
    final widgets = <Widget>[];
    final dayStart = DateTime(widget.day.year, widget.day.month, widget.day.day);
    final dayEnd = dayStart.add(const Duration(days: 1));
    for (final event in widget.events) {
      final isContinuation = event.startTime.isBefore(dayStart);
      final clippedStart = isContinuation ? dayStart : event.startTime;
      final clippedEnd = event.endTime.isAfter(dayEnd) ? dayEnd : event.endTime;
      final startMinutes = (clippedStart.hour - widget.startHour) * 60 + clippedStart.minute;
      final top = startMinutes * _minuteHeight;
      final visibleMinutes = clippedEnd.difference(clippedStart).inMinutes;
      final durationMinutes = event.scheduledDuration.inMinutes;
      final height = (visibleMinutes * _minuteHeight).clamp(20.0, double.infinity);

      final info = layout[event] ?? const _ColInfo(0, 1);
      final slotW = totalWidth / info.numCols;
      final colLeft = info.col * slotW + 1;
      final colWidth = slotW - 2;

      if (!isContinuation && event.travelMinutesBefore > 0) {
        final travelHeight = (event.travelMinutesBefore * _minuteHeight).clamp(8.0, double.infinity);
        widgets.add(Positioned(
          top: top - travelHeight,
          left: colLeft,
          width: colWidth,
          height: travelHeight,
          child: _TravelBlock(minutes: event.travelMinutesBefore, isAfter: false),
        ));
      }

      widgets.add(Positioned(
        top: top,
        left: colLeft,
        width: colWidth,
        height: height,
        child: DragTarget<Todo>(
          onWillAcceptWithDetails: (_) => widget.onTodoDroppedOnEvent != null,
          onAcceptWithDetails: (details) {
            widget.onTodoDroppedOnEvent?.call(details.data, event);
          },
          builder: (ctx, candidateTodos, _) {
            final isTarget = candidateTodos.isNotEmpty;
            return LongPressDraggable<CalendarEvent>(
              data: event,
              onDraggableCanceled: (velocity, offset) => _onDragEnd(),
              onDragCompleted: _onDragEnd,
              feedback: ValueListenableBuilder<int>(
                valueListenable: SnapState.snapNotifier,
                builder: (ctx, snap, _) {
                  final mh = SnapState.hourHeightForSnap(snap) / 60.0;
                  final h = (durationMinutes * mh).clamp(20.0, 2000.0);
                  return Material(
                    color: Colors.transparent,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ValueListenableBuilder<String>(
                          valueListenable: SnapState.currentTimeNotifier,
                          builder: (ctx, timeStr, _) {
                            if (timeStr.isEmpty) return const SizedBox.shrink();
                            final parts = timeStr.split(':');
                            final totalEnd = int.parse(parts[0]) * 60 + int.parse(parts[1]) + durationMinutes;
                            final endStr = '${(totalEnd ~/ 60).toString().padLeft(2, '0')}:${(totalEnd % 60).toString().padLeft(2, '0')}';
                            return Container(
                              margin: const EdgeInsets.only(bottom: 2),
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text('$timeStr – $endStr',
                                  style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                            );
                          },
                        ),
                        Opacity(
                          opacity: 0.85,
                          child: SizedBox(
                            width: 90,
                            height: h,
                            child: EventBlock(event: event, onTap: () {}, heightPerMinute: mh),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
              childWhenDragging: const SizedBox.shrink(),
              child: EventBlock(
                event: event,
                onTap: () => widget.onEventTap(event),
                heightPerMinute: _minuteHeight,
                isDropTarget: isTarget,
              ),
            );
          },
        ),
      ));

      if (!event.endTime.isAfter(dayEnd) && event.travelMinutesAfter > 0) {
        final travelHeight = (event.travelMinutesAfter * _minuteHeight).clamp(8.0, double.infinity);
        widgets.add(Positioned(
          top: top + height,
          left: colLeft,
          width: colWidth,
          height: travelHeight,
          child: _TravelBlock(minutes: event.travelMinutesAfter, isAfter: true),
        ));
      }
    }
    return widgets;
  }

  List<Widget> _buildTodoBlocks(Map<Object, _ColInfo> layout, double totalWidth) {
    final widgets = <Widget>[];
    final dayStart = DateTime(widget.day.year, widget.day.month, widget.day.day);
    final dayEnd = dayStart.add(const Duration(days: 1));
    for (final todo in widget.todos.where((t) => t.scheduledStartHour != null)) {
      final todoStart = DateTime(
        todo.scheduledDate?.year ?? widget.day.year,
        todo.scheduledDate?.month ?? widget.day.month,
        todo.scheduledDate?.day ?? widget.day.day,
        todo.scheduledStartHour!,
        todo.scheduledStartMinute ?? 0,
      );
      final todoEnd = todoStart.add(Duration(minutes: todo.estimatedMinutes));
      final isContinuation = todoStart.isBefore(dayStart);
      final clippedStart = isContinuation ? dayStart : todoStart;
      final clippedEnd = todoEnd.isAfter(dayEnd) ? dayEnd : todoEnd;
      final startMinutes = (clippedStart.hour - widget.startHour) * 60 + clippedStart.minute;
      final top = startMinutes * _minuteHeight;
      final visibleMinutes = clippedEnd.difference(clippedStart).inMinutes;
      final height = (visibleMinutes * _minuteHeight).clamp(20.0, double.infinity);

      final info = layout[todo] ?? const _ColInfo(0, 1);
      final slotW = totalWidth / info.numCols;
      final colLeft = info.col * slotW + 1;
      final colWidth = slotW - 2;

      if (!isContinuation && todo.travelMinutesBefore > 0) {
        final travelHeight = (todo.travelMinutesBefore * _minuteHeight).clamp(8.0, double.infinity);
        widgets.add(Positioned(
          top: top - travelHeight,
          left: colLeft,
          width: colWidth,
          height: travelHeight,
          child: _TravelBlock(minutes: todo.travelMinutesBefore, isAfter: false),
        ));
      }

      widgets.add(Positioned(
        top: top,
        left: colLeft,
        width: colWidth,
        height: height,
        child: LongPressDraggable<Todo>(
          data: todo,
          onDraggableCanceled: (velocity, offset) => _onDragEnd(),
          onDragCompleted: _onDragEnd,
          feedback: ValueListenableBuilder<int>(
            valueListenable: SnapState.snapNotifier,
            builder: (ctx, snap, _) {
              final mh = SnapState.hourHeightForSnap(snap) / 60.0;
              final h = (todo.estimatedMinutes * mh).clamp(20.0, 2000.0);
              return Material(
                color: Colors.transparent,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ValueListenableBuilder<String>(
                      valueListenable: SnapState.currentTimeNotifier,
                      builder: (ctx, timeStr, _) {
                        if (timeStr.isEmpty) return const SizedBox.shrink();
                        final parts = timeStr.split(':');
                        final totalEnd = int.parse(parts[0]) * 60 + int.parse(parts[1]) + todo.estimatedMinutes;
                        final endStr = '${(totalEnd ~/ 60).toString().padLeft(2, '0')}:${(totalEnd % 60).toString().padLeft(2, '0')}';
                        return Container(
                          margin: const EdgeInsets.only(bottom: 2),
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text('$timeStr – $endStr',
                              style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                        );
                      },
                    ),
                    Opacity(
                      opacity: 0.85,
                      child: SizedBox(
                        width: 90,
                        height: h,
                        child: EventBlock(todo: todo, onTap: () {}, heightPerMinute: mh),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          childWhenDragging: const SizedBox.shrink(),
          child: EventBlock(
            todo: todo,
            onTap: () => widget.onTodoTap(todo),
            heightPerMinute: _minuteHeight,
          ),
        ),
      ));

      if (!todoEnd.isAfter(dayEnd) && todo.travelMinutesAfter > 0) {
        final travelHeight = (todo.travelMinutesAfter * _minuteHeight).clamp(8.0, double.infinity);
        widgets.add(Positioned(
          top: top + height,
          left: colLeft,
          width: colWidth,
          height: travelHeight,
          child: _TravelBlock(minutes: todo.travelMinutesAfter, isAfter: true),
        ));
      }
    }
    return widgets;
  }
}

class _AllDayBanner extends StatelessWidget {
  final List<CalendarEvent> events;
  const _AllDayBanner({required this.events});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      color: AppColors.primary.withValues(alpha: 0.08),
      child: Wrap(
        spacing: 4,
        runSpacing: 2,
        children: events.map((e) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            e.title,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: AppColors.textPrimary,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        )).toList(),
      ),
    );
  }
}

// ── TravelBlock ───────────────────────────────────────────────────────────────

class _TravelBlock extends StatelessWidget {
  final int minutes;
  final bool isAfter;

  const _TravelBlock({required this.minutes, required this.isAfter});

  @override
  Widget build(BuildContext context) {
    const color = Color(0xFF78909C);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 1, vertical: 0),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.5), width: 1),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      child: Row(
        children: [
          Icon(
            isAfter ? Icons.directions_car : Icons.directions_car_outlined,
            size: 9,
            color: color,
          ),
          const SizedBox(width: 3),
          if (minutes >= 10)
            Text(
              '${minutes}min',
              style: const TextStyle(fontSize: 8, color: color),
            ),
        ],
      ),
    );
  }
}

// ── DayHeader ─────────────────────────────────────────────────────────────────


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
        color: isToday ? AppColors.primary.withValues(alpha: 0.15) : Colors.transparent,
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
                ? const BoxDecoration(shape: BoxShape.circle, color: AppColors.primary)
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
