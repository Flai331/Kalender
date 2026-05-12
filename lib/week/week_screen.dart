import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../app_colors.dart';
import '../models/calendar_event.dart';
import '../models/todo.dart';
import '../models/yearly_checklist.dart';
import '../services/daylight_service.dart';
import '../services/supabase_service.dart';
import '../services/shift_service.dart';
import '../services/ics_service.dart';
import 'week_day_column.dart';
import '../todos/todo_status_dialog.dart';
import '../week/event_status_dialog.dart';
import '../week/event_edit_screen.dart';

const _uuid = Uuid();

class WeekScreen extends StatefulWidget {
  const WeekScreen({super.key});

  @override
  State<WeekScreen> createState() => _WeekScreenState();
}

class _WeekScreenState extends State<WeekScreen> {
  late DateTime _weekStart;
  final ScrollController _scrollController = ScrollController();

  // Daten-Streams
  Stream<List<CalendarEvent>>? _eventsStream;
  Stream<List<Todo>>? _todosStream;
  Stream<List<Todo>>? _unscheduledStream;

  List<CalendarEvent> _events = [];
  List<CalendarEvent> _icsEvents = [];
  List<Todo> _todos = [];
  List<Todo> _unscheduled = [];
  List<YearlyChecklist> _pendingChecklists = [];

  Timer? _nowTimer;
  List<String> _blockingAllDayCats = ['vacation'];
  final Set<String> _noSlotTodos = {};

  static const double _hourHeight = 60.0;
  static const int _startHour = 6;
  static const int _endHour = 23;

  @override
  void initState() {
    super.initState();
    _weekStart = _getWeekStart(DateTime.now());
    _initStreams();
    _loadIcsEvents();
    _checkYearlyChecklists();
    DaylightService.loadSettings();
    DaylightService.prefetchLocation();
    _loadBlockingCats();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToNow();
      _autoShiftOverdueTodos();
    });
    _nowTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) _autoShiftOverdueTodos();
    });
  }

  DateTime _getWeekStart(DateTime date) {
    return date.subtract(Duration(days: date.weekday - 1));
  }

  void _initStreams() {
    final start = DateTime(_weekStart.year, _weekStart.month, _weekStart.day);
    _eventsStream = SupabaseService.eventsForWeek(start);
    _todosStream = SupabaseService.todosForWeek(start);
    _unscheduledStream = SupabaseService.unscheduledTodos();
  }

  Future<void> _loadIcsEvents() async {
    final all = await IcsService.fetchEvents();
    final weekEnd = _weekStart.add(const Duration(days: 7));
    if (mounted) {
      setState(() {
        _icsEvents = all
            .where((e) =>
                !e.startTime.isBefore(_weekStart) &&
                e.startTime.isBefore(weekEnd))
            .toList();
      });
    }
  }

  void _scrollToNow() {
    final now = DateTime.now();
    final offset =
        ((now.hour - _startHour) * _hourHeight + now.minute).clamp(0.0, 1000.0);
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        offset,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _checkYearlyChecklists() async {
    final checklists = await SupabaseService.getYearlyChecklists();
    final now = DateTime.now();
    final pending =
        checklists.where((c) => c.shouldTrigger(now)).toList();
    if (pending.isNotEmpty && mounted) {
      setState(() => _pendingChecklists = pending);
    }
  }

  void _navigateWeek(int direction) {
    setState(() {
      _weekStart = _weekStart.add(Duration(days: 7 * direction));
      _initStreams();
    });
    _loadIcsEvents();
  }

  List<CalendarEvent> _eventsForDay(DateTime day) {
    final all = [..._events, ..._icsEvents];
    return all.where((e) {
      return e.startTime.year == day.year &&
          e.startTime.month == day.month &&
          e.startTime.day == day.day;
    }).toList()
      ..sort((a, b) => a.startTime.compareTo(b.startTime));
  }

  List<Todo> _todosForDay(DateTime day) {
    return _todos.where((t) {
      if (t.scheduledDate == null) return false;
      return t.scheduledDate!.year == day.year &&
          t.scheduledDate!.month == day.month &&
          t.scheduledDate!.day == day.day;
    }).toList();
  }

  Future<void> _onTodoDrop(
      Todo todo, DateTime day, int hour, int minute) async {
    final updated = todo.copyWith(
      scheduledDate: DateTime(day.year, day.month, day.day),
      scheduledStartHour: hour,
      scheduledStartMinute: minute,
    );
    await SupabaseService.saveTodo(updated);
  }

  Future<void> _onEventDrop(
      CalendarEvent event, DateTime day, int hour, int minute) async {
    final duration = event.endTime.difference(event.startTime);
    final newStart = DateTime(day.year, day.month, day.day, hour, minute);
    final newEnd = newStart.add(duration);

    final updated = event.copyWith(startTime: newStart, endTime: newEnd);
    await SupabaseService.saveEvent(updated);

    // ICS-Events können nicht zurückgeschrieben werden
    if (event.source == 'outlook') return;
  }

  Future<void> _onEventTap(CalendarEvent event) async {
    // ICS-Event: nur Info anzeigen
    if (event.source == 'outlook') {
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppColors.surface,
          title: Text(event.title,
              style: const TextStyle(color: AppColors.textPrimary)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${_fmt(event.startTime)} – ${_fmt(event.endTime)}',
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 13),
              ),
              if (event.description.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(event.description,
                    style: const TextStyle(
                        color: AppColors.textSecondary, fontSize: 12)),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('OK',
                  style: TextStyle(color: AppColors.primary)),
            ),
          ],
        ),
      );
      return;
    }

    final result = await EventStatusDialog.show(context: context, event: event);
    if (result == null || !mounted) return;

    final now = DateTime.now();
    CalendarEvent updated;

    switch (result) {
      case 'start':
        updated = event.copyWith(
          status: EventStatus.started,
          actualStart: now,
        );
        await SupabaseService.saveEvent(updated);
      case 'pause':
        final pausedExtra = event.pauseStart != null
            ? now.difference(event.pauseStart!).inMinutes
            : 0;
        updated = event.copyWith(
          status: EventStatus.paused,
          pausedMinutes: event.pausedMinutes + pausedExtra,
          pauseStart: now,
        );
        await SupabaseService.saveEvent(updated);
      case 'resume':
        updated = event.copyWith(
          status: EventStatus.started,
          pauseStart: null,
        );
        await SupabaseService.saveEvent(updated);
      case 'done':
        updated = event.copyWith(
          status: EventStatus.done,
          actualEnd: now,
        );
        await SupabaseService.saveEvent(updated);
      case 'edit':
        if (!mounted) return;
        await Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => EventEditScreen(event: event)),
        );
      case 'delete':
        await SupabaseService.deleteEvent(event.id);
    }
  }

  Future<void> _onTodoTap(Todo todo) async {
    final result =
        await TodoStatusDialog.show(context: context, todo: todo);
    if (result == null || !mounted) return;

    final now = DateTime.now();
    Todo updated;

    switch (result) {
      case 'start':
        updated =
            todo.copyWith(status: TodoStatus.started, actualStart: now);
        await SupabaseService.saveTodo(updated);
      case 'pause':
        final pausedExtra = todo.pauseStart != null
            ? now.difference(todo.pauseStart!).inMinutes
            : 0;
        updated = todo.copyWith(
          status: TodoStatus.paused,
          pausedMinutes: todo.pausedMinutes + pausedExtra,
          pauseStart: now,
        );
        await SupabaseService.saveTodo(updated);
      case 'resume':
        updated = todo.copyWith(status: TodoStatus.started, pauseStart: null);
        await SupabaseService.saveTodo(updated);
      case 'done':
        updated = todo.copyWith(
            status: TodoStatus.done, actualEnd: now, isCompleted: true);
        await SupabaseService.saveTodo(updated);
        // Zeitplan automatisch anpassen (positiv = zu spät, negativ = früher)
        final delta = ShiftService.computeDelta(todo: todo, actualEnd: now);
        if (delta.abs() >= 2) {
          await ShiftService.shiftAfterTodo(
              completedTodo: todo, deltaMinutes: delta);
          if (mounted) {
            final msg = delta < 0
                ? '${(-delta)} min früher – Zeitplan vorgezogen'
                : '$delta min später – Zeitplan nach hinten verschoben';
            ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(msg), duration: const Duration(seconds: 2)));
          }
        }
      case 'unschedule':
        updated = todo.copyWith(scheduledDate: null,
            scheduledStartHour: null, scheduledStartMinute: null);
        await SupabaseService.saveTodo(updated);
    }
  }

  Future<void> _addEvent() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const EventEditScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: _buildAppBar(),
      body: Column(
        children: [
          if (_pendingChecklists.isNotEmpty) _buildChecklistBanner(),
          Expanded(child: _buildWeekView()),
          _buildTodoPool(),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'week_fab',
        onPressed: _addEvent,
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  AppBar _buildAppBar() {
    final weekEnd = _weekStart.add(const Duration(days: 6));
    final label =
        '${_weekStart.day}.${_weekStart.month} – ${weekEnd.day}.${weekEnd.month}.${weekEnd.year}';

    return AppBar(
      backgroundColor: AppColors.surface,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.chevron_left, color: AppColors.textPrimary),
        onPressed: () => _navigateWeek(-1),
      ),
      title: GestureDetector(
        onTap: () {
          setState(() {
            _weekStart = _getWeekStart(DateTime.now());
            _initStreams();
          });
          _loadIcsEvents();
        },
        child: Text(
          label,
          style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w600),
        ),
      ),
      centerTitle: true,
      actions: [
        IconButton(
          icon: const Icon(Icons.chevron_right, color: AppColors.textPrimary),
          onPressed: () => _navigateWeek(1),
        ),
      ],
    );
  }

  Widget _buildChecklistBanner() {
    final checklist = _pendingChecklists.first;
    return Container(
      color: AppColors.vacation.withOpacity(0.15),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          const Icon(Icons.event_available,
              color: AppColors.vacation, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '📋 Jahres-Aufgabe: ${checklist.title}',
              style: const TextStyle(
                  color: AppColors.vacation,
                  fontWeight: FontWeight.w600,
                  fontSize: 13),
            ),
          ),
          TextButton(
            onPressed: () async {
              // Todo aus Vorlage erstellen
              final todo = Todo(
                id: _uuid.v4(),
                title: checklist.title,
                description: checklist.template,
                estimatedMinutes: 30,
                createdAt: DateTime.now(),
              );
              await SupabaseService.saveTodo(todo);
              // lastTriggeredYear aktualisieren
              final updated = checklist.copyWith(
                  lastTriggeredYear: DateTime.now().year);
              await SupabaseService.saveYearlyChecklist(updated);
              setState(() => _pendingChecklists.remove(checklist));
            },
            child: const Text('Todo erstellen',
                style: TextStyle(color: AppColors.vacation, fontSize: 12)),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 16, color: AppColors.textSecondary),
            onPressed: () =>
                setState(() => _pendingChecklists.remove(checklist)),
          ),
        ],
      ),
    );
  }

  Widget _buildTodoPool() {
    return StreamBuilder<List<Todo>>(
      stream: _unscheduledStream,
      builder: (ctx, snap) {
        _unscheduled = snap.data ?? [];
        if (_unscheduled.isEmpty) {
          return Container(
            height: 52,
            color: AppColors.surface,
            alignment: Alignment.center,
            child: const Text('Keine offenen Todos – tippe + um neue anzulegen',
                style: TextStyle(color: AppColors.textDisabled, fontSize: 12)),
          );
        }
        return Container(
          height: 72,
          color: AppColors.surface,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(left: 10, top: 4),
                child: Text('TODOS – lange gedrückt halten & in Kalender ziehen',
                    style: TextStyle(
                        color: AppColors.textDisabled,
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5)),
              ),
              Expanded(
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  itemCount: _unscheduled.length,
                  separatorBuilder: (context, index) => const SizedBox(width: 6),
                  itemBuilder: (ctx, i) {
                    final todo = _unscheduled[i];
                    return LongPressDraggable<Todo>(
                      data: todo,
                      feedback: Material(
                        color: Colors.transparent,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: [
                              BoxShadow(
                                  color: Colors.black26,
                                  blurRadius: 6,
                                  offset: const Offset(0, 3))
                            ],
                          ),
                          child: Text(todo.title,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600)),
                        ),
                      ),
                      childWhenDragging: Opacity(
                        opacity: 0.3,
                        child: _TodoChip(todo: todo),
                      ),
                      child: _TodoChip(todo: todo),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildWeekView() {
    return StreamBuilder<List<CalendarEvent>>(
      stream: _eventsStream,
      builder: (ctx, evSnap) {
        _events = evSnap.data ?? [];
        return StreamBuilder<List<Todo>>(
          stream: _todosStream,
          builder: (ctx, todoSnap) {
            _todos = todoSnap.data ?? [];
            return SingleChildScrollView(
              controller: _scrollController,
              child: SizedBox(
                height: (_endHour - _startHour) * _hourHeight,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Zeitachse links
                    _TimeAxis(
                      startHour: _startHour,
                      endHour: _endHour,
                      hourHeight: _hourHeight,
                    ),
                    // Tages-Spalten
                    ...List.generate(7, (i) {
                      final day = _weekStart.add(Duration(days: i));
                      final isToday = _isSameDay(day, DateTime.now());
                      final dayEvents = _eventsForDay(day);
                      final allDayEvs = dayEvents.where((e) => e.isAllDay).toList();
                      final timedEvs  = dayEvents.where((e) => !e.isAllDay).toList();
                      return Expanded(
                        child: WeekDayColumn(
                          day: day,
                          events: timedEvs,
                          allDayEvents: allDayEvs,
                          todos: _todosForDay(day),
                          isToday: isToday,
                          hourHeight: _hourHeight,
                          startHour: _startHour,
                          endHour: _endHour,
                          onTodoDrop: _onTodoDrop,
                          onEventDrop: _onEventDrop,
                          onEventTap: _onEventTap,
                          onTodoTap: _onTodoTap,
                          onTodoDroppedOnEvent: _onTodoDroppedOnEvent,
                        ),
                      );
                    }),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  String _fmt(DateTime dt) =>
      '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

  @override
  void dispose() {
    _nowTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  // ── Constraint-Helpers ─────────────────────────────────────────────────────

  Future<void> _loadBlockingCats() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _blockingAllDayCats =
          prefs.getStringList('blocking_allday_cats') ?? ['vacation'];
    });
  }

  Future<void> _onTodoDroppedOnEvent(Todo todo, CalendarEvent event) async {
    if (event.isAllDay) return;

    final evStart = event.startTime.hour * 60 + event.startTime.minute;
    final evEnd = event.endTime.hour * 60 + event.endTime.minute;
    final total = todo.travelMinutesBefore + todo.estimatedMinutes + todo.travelMinutesAfter;

    if (evEnd - evStart < total) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Todo passt zeitlich nicht in diesen Termin.'),
      ));
      return;
    }

    final newStart = evStart + todo.travelMinutesBefore;
    final updated = todo.copyWith(
      scheduledDate: event.startTime,
      scheduledStartHour: newStart ~/ 60,
      scheduledStartMinute: newStart % 60,
      contextMode: TodoContextMode.opportunistic,
      requiredCategory: event.category,
    );
    await SupabaseService.saveTodo(updated);
    if (mounted) setState(() => _initStreams());
  }

  bool _dayBlockedByAllDay(DateTime day) {
    // ICS-Events werden nur für die aktuelle Woche geladen.
    // Ganztags-ICS-Events außerhalb der Woche blockieren daher nicht.
    final allEventsOnDay = [..._events, ..._icsEvents].where((e) =>
        e.isAllDay &&
        e.startTime.year == day.year &&
        e.startTime.month == day.month &&
        e.startTime.day == day.day);
    return allEventsOnDay
        .any((e) => _blockingAllDayCats.contains(e.category.name));
  }

  List<CalendarEvent> _timedEventsOnDay(DateTime day) {
    return [..._events, ..._icsEvents]
        .where((e) =>
            !e.isAllDay &&
            e.startTime.year == day.year &&
            e.startTime.month == day.month &&
            e.startTime.day == day.day)
        .toList()
      ..sort((a, b) => a.startTime.compareTo(b.startTime));
  }

  /// Gibt (day, minuteOfDay) des nächsten gültigen Slots zurück.
  /// Gibt null zurück wenn kein Slot in 30 Tagen gefunden.
  Future<(DateTime, int)?> _findNextValidSlot(
      Todo todo, DateTime fromDay, int fromMinute) async {
    DateTime day = fromDay;
    int startMinute = fromMinute;
    final total =
        todo.travelMinutesBefore + todo.estimatedMinutes + todo.travelMinutesAfter;

    for (int attempt = 0; attempt < 30; attempt++) {
      // Wochentag-Filter
      if (todo.allowedWeekdays != null &&
          todo.allowedWeekdays!.isNotEmpty &&
          !todo.allowedWeekdays!.contains(day.weekday)) {
        day = day.add(const Duration(days: 1));
        startMinute = 0;
        continue;
      }

      // Ganztags-Block
      if (_dayBlockedByAllDay(day)) {
        day = day.add(const Duration(days: 1));
        startMinute = 0;
        continue;
      }

      // Zeitfenster bestimmen
      int winStart =
          todo.dueWindowStartHour != null ? todo.dueWindowStartHour! * 60 : 0;
      int winEnd = todo.dueWindowEndHour != null
          ? todo.dueWindowEndHour! * 60
          : 24 * 60;

      if (todo.daylightMode == DaylightMode.gps ||
          todo.daylightMode == DaylightMode.manual) {
        final (rise, set) = DaylightService.getDaylightWindowSync(day);
        winStart = math.max(winStart, rise);
        winEnd = math.min(winEnd, set);
      }

      if (startMinute < winStart) startMinute = winStart;

      // Kontext-Modus
      if (todo.contextMode == TodoContextMode.categoryEvent ||
          todo.contextMode == TodoContextMode.opportunistic) {
        if (todo.requiredCategory == null) {
          day = day.add(const Duration(days: 1));
          startMinute = 0;
          continue;
        }
        final matchEvents = _timedEventsOnDay(day)
            .where((e) => e.category == todo.requiredCategory)
            .toList();

        for (final ev in matchEvents) {
          final evStart = ev.startTime.hour * 60 + ev.startTime.minute;
          final evEnd = ev.endTime.hour * 60 + ev.endTime.minute;
          final pos =
              math.max(startMinute, math.max(winStart, evStart));
          if (pos + total <= math.min(winEnd, evEnd)) {
            return (day, pos);
          }
        }
        day = day.add(const Duration(days: 1));
        startMinute = 0;
        continue;
      }

      if (todo.contextMode == TodoContextMode.freeTime) {
        final dayEvents = _timedEventsOnDay(day);
        int pos = startMinute;
        bool found = false;
        for (int tries = 0; tries < 200; tries++) {
          if (pos + total > winEnd) break;
          final blocker = dayEvents.cast<CalendarEvent?>().firstWhere(
            (e) {
              final es = e!.startTime.hour * 60 + e.startTime.minute;
              final ee = e.endTime.hour * 60 + e.endTime.minute;
              return pos < ee && pos + total > es;
            },
            orElse: () => null,
          );
          if (blocker == null) {
            found = true;
            break;
          }
          final newPos = blocker.endTime.hour * 60 + blocker.endTime.minute;
          pos = newPos > pos ? newPos : pos + 1;
        }
        if (found) return (day, pos);
        day = day.add(const Duration(days: 1));
        startMinute = winStart;
        continue;
      }

      // anyTime: direkt platzieren wenn Fenster passt
      if (startMinute + total <= winEnd) {
        return (day, startMinute);
      }
      day = day.add(const Duration(days: 1));
      startMinute = winStart;
    }
    return null;
  }

  // ── Auto-Shift ─────────────────────────────────────────────────────────────

  Future<void> _autoShiftOverdueTodos() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final nowMinutes = now.hour * 60 + now.minute;

    final todayTodos = _todos
        .where((t) =>
            t.scheduledDate != null &&
            t.scheduledDate!.year == today.year &&
            t.scheduledDate!.month == today.month &&
            t.scheduledDate!.day == today.day &&
            t.scheduledStartHour != null &&
            !t.isFixed &&
            (t.status == TodoStatus.pending ||
                t.status == TodoStatus.started ||
                t.status == TodoStatus.paused))
        .toList()
      ..sort((a, b) {
        final aBlock =
            a.scheduledStartHour! * 60 + (a.scheduledStartMinute ?? 0) - a.travelMinutesBefore;
        final bBlock =
            b.scheduledStartHour! * 60 + (b.scheduledStartMinute ?? 0) - b.travelMinutesBefore;
        return aBlock.compareTo(bBlock);
      });

    final todayEventTuples = _timedEventsOnDay(today)
        .map((e) => (
              e.startTime.hour * 60 + e.startTime.minute,
              e.endTime.hour * 60 + e.endTime.minute,
            ))
        .toList();

    int skipEvents(int pos, int totalDuration) {
      bool changed = true;
      while (changed) {
        changed = false;
        for (final ev in todayEventTuples) {
          if (pos < ev.$2 && pos + totalDuration > ev.$1) {
            pos = ev.$2;
            changed = true;
          }
        }
      }
      return pos;
    }

    int runningMin = nowMinutes;
    DateTime runningDate = today;
    bool shifted = false;
    int? prevOriginalBlockEnd;
    final newNoSlot = <String>{};

    for (final todo in todayTodos) {
      final todoMin =
          todo.scheduledStartHour! * 60 + (todo.scheduledStartMinute ?? 0);
      final blockStart = todoMin - todo.travelMinutesBefore;
      final blockEnd =
          todoMin + todo.estimatedMinutes + todo.travelMinutesAfter;

      // Started/paused: Anker, kein Shift
      if (todo.status == TodoStatus.started ||
          todo.status == TodoStatus.paused) {
        int newMin = blockEnd > runningMin ? blockEnd : runningMin;
        while (newMin >= 24 * 60) {
          newMin -= 24 * 60;
          runningDate = runningDate.add(const Duration(days: 1));
        }
        runningMin = newMin;
        shifted = false;
        prevOriginalBlockEnd = blockEnd;
        continue;
      }

      // Pending: shift wenn überfällig oder cascaded
      if (blockStart < nowMinutes ||
          (shifted && blockStart < runningMin)) {
        if (prevOriginalBlockEnd != null && blockStart > prevOriginalBlockEnd) {
          runningMin += blockStart - prevOriginalBlockEnd;
        }

        final hasConstraints = todo.contextMode != TodoContextMode.anyTime ||
            (todo.allowedWeekdays != null && todo.allowedWeekdays!.isNotEmpty) ||
            todo.daylightMode != DaylightMode.none;

        if (hasConstraints) {
          if (_noSlotTodos.contains(todo.id)) {
            prevOriginalBlockEnd = blockEnd;
            continue;
          }
          final slot = await _findNextValidSlot(todo, runningDate, runningMin);
          if (slot == null) {
            newNoSlot.add(todo.id);
            prevOriginalBlockEnd = blockEnd;
            continue;
          }
          final (slotDay, slotMin) = slot;
          _noSlotTodos.remove(todo.id);
          final newStart = slotMin + todo.travelMinutesBefore;
          final newHour = (newStart ~/ 60).clamp(0, 23);
          final newMin = newStart % 60;
          final dateChanged = slotDay.year != (todo.scheduledDate?.year ?? 0) ||
              slotDay.month != (todo.scheduledDate?.month ?? 0) ||
              slotDay.day != (todo.scheduledDate?.day ?? 0);
          if (newHour != todo.scheduledStartHour ||
              newMin != (todo.scheduledStartMinute ?? 0) ||
              dateChanged) {
            await SupabaseService.saveTodo(todo.copyWith(
              scheduledDate: slotDay,
              scheduledStartHour: newHour,
              scheduledStartMinute: newMin,
            ));
            shifted = true;
          }
          runningMin = slotMin +
              todo.travelMinutesBefore +
              todo.estimatedMinutes +
              todo.travelMinutesAfter;
          runningDate = slotDay;
        } else {
          // Standard anyTime-Logik (wie zuvor)
          final totalBlock = todo.travelMinutesBefore +
              todo.estimatedMinutes +
              todo.travelMinutesAfter;
          final winStart = todo.dueWindowStartHour;
          final winEnd = todo.dueWindowEndHour;
          if (winStart != null && runningMin < winStart * 60) {
            runningMin = winStart * 60;
          }
          if (winEnd != null && runningMin + totalBlock > winEnd * 60) {
            runningDate = runningDate.add(const Duration(days: 1));
            runningMin = (winStart ?? 0) * 60;
            shifted = true;
          }
          runningMin = skipEvents(runningMin, totalBlock);
          final newScheduledStart = runningMin + todo.travelMinutesBefore;
          final newHour = (newScheduledStart ~/ 60).clamp(0, 23);
          final newMin = newScheduledStart % 60;
          final dateChanged =
              runningDate.year != (todo.scheduledDate?.year ?? 0) ||
                  runningDate.month != (todo.scheduledDate?.month ?? 0) ||
                  runningDate.day != (todo.scheduledDate?.day ?? 0);
          if (newHour != todo.scheduledStartHour ||
              newMin != (todo.scheduledStartMinute ?? 0) ||
              dateChanged) {
            await SupabaseService.saveTodo(todo.copyWith(
              scheduledDate: runningDate,
              scheduledStartHour: newHour,
              scheduledStartMinute: newMin,
            ));
            shifted = true;
          }
          runningMin = newScheduledStart +
              todo.estimatedMinutes +
              todo.travelMinutesAfter;
        }
      } else {
        runningMin = blockEnd;
      }
      prevOriginalBlockEnd = blockEnd;
    }

    // Opportunity-Todos: wenn verpasstes Event → nächstes Event suchen
    for (final todo in todayTodos) {
      if (todo.contextMode != TodoContextMode.opportunistic) continue;
      if (todo.status != TodoStatus.pending) continue;
      if (_noSlotTodos.contains(todo.id)) continue;
      final scheduledEnd = todo.scheduledEndTime;
      if (scheduledEnd == null || !scheduledEnd.isBefore(now)) continue;
      // Todo ist überfällig — suche nächstes passendes Event
      final slot = await _findNextValidSlot(todo, today, nowMinutes);
      if (slot == null) {
        _noSlotTodos.add(todo.id);
        continue;
      }
      final (slotDay, slotMin) = slot;
      _noSlotTodos.remove(todo.id);
      final newStart = slotMin + todo.travelMinutesBefore;
      await SupabaseService.saveTodo(todo.copyWith(
        scheduledDate: slotDay,
        scheduledStartHour: newStart ~/ 60,
        scheduledStartMinute: newStart % 60,
      ));
      shifted = true;
    }

    if (!mounted) return;
    if (shifted) setState(() => _initStreams());

    // Warnung für Todos ohne Slot
    if (newNoSlot.isNotEmpty) {
      _noSlotTodos.addAll(newNoSlot);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              '${newNoSlot.length} Todo(s) konnten nicht eingeplant werden – kein passender Slot in 30 Tagen.'),
          action: SnackBarAction(
            label: 'OK',
            onPressed: () => _noSlotTodos.clear(),
          ),
        ));
      });
    }
  }
}

// ── Todo-Pool Chip ────────────────────────────────────────────────────────────

class _TodoChip extends StatelessWidget {
  final Todo todo;
  const _TodoChip({required this.todo});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            todo.title,
            style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 12,
                fontWeight: FontWeight.w600),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            '${todo.estimatedMinutes} min',
            style: const TextStyle(
                color: AppColors.textDisabled, fontSize: 10),
          ),
        ],
      ),
    );
  }
}

// ── Zeitachse ─────────────────────────────────────────────────────────────────

class _TimeAxis extends StatelessWidget {
  final int startHour;
  final int endHour;
  final double hourHeight;

  const _TimeAxis({
    required this.startHour,
    required this.endHour,
    required this.hourHeight,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 36,
      height: (endHour - startHour) * hourHeight,
      child: Stack(
        children: List.generate(endHour - startHour, (i) {
          return Positioned(
            top: i * hourHeight - 6,
            left: 0,
            right: 0,
            child: Text(
              '${startHour + i}:00',
              style: const TextStyle(
                fontSize: 9,
                color: AppColors.textDisabled,
              ),
              textAlign: TextAlign.right,
            ),
          );
        }),
      ),
    );
  }
}
