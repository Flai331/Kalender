import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import '../models/ics_source.dart';
import 'week_day_column.dart';
import '../todos/todo_status_dialog.dart';
import '../widgets/feedback_button.dart';
import '../week/event_status_dialog.dart';
import '../week/event_edit_screen.dart';
import '../todos/todo_edit_screen.dart';

const _uuid = Uuid();

class WeekScreen extends StatefulWidget {
  const WeekScreen({super.key});

  @override
  State<WeekScreen> createState() => WeekScreenState();
}

class WeekScreenState extends State<WeekScreen> {
  late DateTime _weekStart;
  late DateTime _selectedDay;
  bool _isDayView = false;
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
  List<IcsSource> _icsSources = [];
  bool _outlookAllowTodoDrop = false;

  Timer? _nowTimer;
  List<String> _blockingAllDayCats = ['vacation'];
  final Set<String> _noSlotTodos = {};
  final Set<String> _overriddenIcsIds = {};
  static const String _overriddenIcsKey = 'overridden_ics_ids';

  double _hourHeight = 60.0;
  double _baseHourHeight = 60.0;
  bool _isCtrlPressed = false;
  static const int _startHour = 0;
  static const int _endHour = 24;

  double _hourHeightForSnap(int snap) {
    switch (snap) {
      case 15: return 150.0;
      case 5:  return 360.0;
      case 1:  return 720.0;
      default: return _baseHourHeight;
    }
  }

  void _onSnapChanged() {
    final dragging = SnapState.isDraggingNotifier.value;
    final snap    = SnapState.snapNotifier.value;
    final newH    = dragging ? _hourHeightForSnap(snap) : _baseHourHeight;
    if (newH == _hourHeight) return;

    final ratio      = newH / _hourHeight;
    final oldOffset  = _scrollController.hasClients ? _scrollController.offset : 0.0;
    final viewportH  = _scrollController.hasClients
        ? _scrollController.position.viewportDimension
        : 0.0;

    setState(() => _hourHeight = newH);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      // Viewport-Mitte bleibt auf gleicher Uhrzeit
      final center    = oldOffset + viewportH / 2;
      final newOffset = (center * ratio - viewportH / 2)
          .clamp(0.0, _scrollController.position.maxScrollExtent);
      _scrollController.jumpTo(newOffset);
    });
  }

  bool _onKey(KeyEvent event) {
    final isCtrl = HardwareKeyboard.instance.logicalKeysPressed.any((k) =>
        k == LogicalKeyboardKey.controlLeft ||
        k == LogicalKeyboardKey.controlRight);
    if (isCtrl != _isCtrlPressed) setState(() => _isCtrlPressed = isCtrl);
    return false; // don't consume
  }

  void _onCtrlScroll(double dy) {
    final factor = dy > 0 ? 0.88 : 1.12;
    final newBase = (_baseHourHeight * factor).clamp(30.0, 300.0);
    if (newBase == _baseHourHeight) return;

    final oldOffset = _scrollController.hasClients ? _scrollController.offset : 0.0;
    final viewportH = _scrollController.hasClients
        ? _scrollController.position.viewportDimension
        : 0.0;
    final ratio = newBase / _baseHourHeight;

    setState(() {
      _baseHourHeight = newBase;
      _hourHeight = newBase;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      final center = oldOffset + viewportH / 2;
      final newOffset = (center * ratio - viewportH / 2)
          .clamp(0.0, _scrollController.position.maxScrollExtent);
      _scrollController.jumpTo(newOffset);
    });
  }

  @override
  void initState() {
    super.initState();
    _selectedDay = DateTime.now();
    _weekStart = _getWeekStart(DateTime.now());
    _initStreams();
    _loadIcsEvents();
    _loadOverrides();
    _checkYearlyChecklists();
    DaylightService.loadSettings();
    DaylightService.prefetchLocation();
    _loadBlockingCats();
    SnapState.snapNotifier.addListener(_onSnapChanged);
    SnapState.isDraggingNotifier.addListener(_onSnapChanged);
    HardwareKeyboard.instance.addHandler(_onKey);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToNow();
      _autoShiftOverdueTodos();
    });
    _loadTodoDropSettings();
    _nowTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) {
        setState(() {});
        _autoShiftOverdueTodos();
      }
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

  void reload() {
    setState(() {
      _weekStart = _getWeekStart(_selectedDay);
      _initStreams();
    });
    _loadIcsEvents();
  }

  Future<void> _loadIcsEvents() async {
    final all = await IcsService.fetchEvents();
    final weekEnd = _weekStart.add(const Duration(days: 7));
    if (mounted) {
      setState(() {
        _icsEvents = all
            .where((e) =>
                !e.startTime.isBefore(_weekStart) &&
                e.startTime.isBefore(weekEnd) &&
                !_overriddenIcsIds.contains(e.id))
            .toList();
      });
    }
  }

  Future<void> _loadOverrides() async {
    final prefs = await SharedPreferences.getInstance();
    final ids = prefs.getStringList(_overriddenIcsKey) ?? [];
    if (mounted) setState(() => _overriddenIcsIds.addAll(ids));
  }

  Future<void> _saveOverrides() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_overriddenIcsKey, _overriddenIcsIds.toList());
  }

  CalendarEvent _convertIcsToApp(CalendarEvent ics) {
    return CalendarEvent(
      id: _uuid.v4(),
      title: ics.title,
      description: ics.description,
      startTime: ics.startTime,
      endTime: ics.endTime,
      isAllDay: ics.isAllDay,
      source: 'app',
      category: ics.category,
      address: ics.address,
    );
  }

  Future<CalendarEvent> _adoptIcsEvent(
      CalendarEvent icsEvent, CalendarEvent Function(CalendarEvent) transform) async {
    final appEvent = transform(_convertIcsToApp(icsEvent));
    _overriddenIcsIds.add(icsEvent.id);
    await _saveOverrides();
    if (mounted) setState(() {
      _icsEvents = _icsEvents.where((e) => e.id != icsEvent.id).toList();
    });
    await SupabaseService.saveEvent(appEvent);
    return appEvent;
  }

  void _scrollToNow() {
    final now = DateTime.now();
    final offset =
        (16.0 + (now.hour - _startHour) * _hourHeight + now.minute).clamp(0.0, double.infinity);
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
      _selectedDay = _weekStart;
      _initStreams();
    });
    _loadIcsEvents();
  }

  void _navigateDay(int direction) {
    final next = _selectedDay.add(Duration(days: direction));
    final newWeekStart = _getWeekStart(next);
    final weekChanged = !_isSameDay(newWeekStart, _weekStart);
    setState(() {
      _selectedDay = next;
      if (weekChanged) {
        _weekStart = newWeekStart;
        _initStreams();
      }
    });
    if (weekChanged) _loadIcsEvents();
  }

  List<CalendarEvent> _eventsForDay(DateTime day) {
    final dayStart = DateTime(day.year, day.month, day.day);
    final dayEnd = dayStart.add(const Duration(days: 1));
    final all = [..._events, ..._icsEvents];
    return all.where((e) {
      return !e.isAllDay &&
          e.startTime.isBefore(dayEnd) &&
          e.endTime.isAfter(dayStart);
    }).toList()
      ..sort((a, b) => a.startTime.compareTo(b.startTime));
  }

  List<CalendarEvent> _allDayEventsForDay(DateTime day) {
    final dayStart = DateTime(day.year, day.month, day.day);
    final all = [..._events, ..._icsEvents];
    return all.where((e) {
      if (!e.isAllDay) return false;
      final eStart = DateTime(e.startTime.year, e.startTime.month, e.startTime.day);
      // ICS DTEND is exclusive; if end == start treat as 1-day
      var eEnd = DateTime(e.endTime.year, e.endTime.month, e.endTime.day);
      if (!eEnd.isAfter(eStart)) eEnd = eStart.add(const Duration(days: 1));
      return !dayStart.isBefore(eStart) && dayStart.isBefore(eEnd);
    }).toList();
  }

  List<Todo> _todosForDay(DateTime day) {
    final dayStart = DateTime(day.year, day.month, day.day);
    final dayEnd = dayStart.add(const Duration(days: 1));
    return _todos.where((t) {
      if (t.scheduledDate == null || t.scheduledStartHour == null) return false;
      final todoStart = DateTime(
        t.scheduledDate!.year, t.scheduledDate!.month, t.scheduledDate!.day,
        t.scheduledStartHour!, t.scheduledStartMinute ?? 0,
      );
      final todoEnd = todoStart.add(Duration(minutes: t.estimatedMinutes));
      return todoStart.isBefore(dayEnd) && todoEnd.isAfter(dayStart);
    }).toList();
  }

  Future<void> _onTodoDrop(
      Todo todo, DateTime day, int hour, int minute) async {
    final dropStart = hour * 60 + minute;
    final dropEnd = dropStart + todo.estimatedMinutes;
    final dayEvents = [..._eventsForDay(day), ..._icsEvents.where((e) =>
        e.startTime.year == day.year &&
        e.startTime.month == day.month &&
        e.startTime.day == day.day)];

    for (final event in dayEvents) {
      final evStart = event.startTime.hour * 60 + event.startTime.minute;
      final evEnd = event.endTime.hour * 60 + event.endTime.minute;
      final overlaps = dropStart < evEnd && dropEnd > evStart;
      if (overlaps && !_todoDropAllowed(event)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(
              'Nicht erlaubt: "${event.title}" blockiert diesen Zeitraum.',
              style: const TextStyle(color: Colors.white),
            ),
            backgroundColor: Colors.redAccent,
            duration: const Duration(seconds: 3),
          ));
        }
        return;
      }
    }

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

    if (event.source == 'ics') {
      await _adoptIcsEvent(event, (e) => e.copyWith(startTime: newStart, endTime: newEnd));
      return;
    }

    final updated = event.copyWith(startTime: newStart, endTime: newEnd);
    await SupabaseService.saveEvent(updated);
  }

  Future<void> _onEventTap(CalendarEvent event) async {
    // ICS-Event: in App-Event konvertieren und bearbeiten
    if (event.source == 'ics') {
      if (!mounted) return;
      final confirm = await showDialog<bool>(
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
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
              if (event.description.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(event.description,
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
              ],
              const SizedBox(height: 12),
              const Text(
                'In App-Termin umwandeln um ihn zu bearbeiten?',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Abbrechen',
                  style: TextStyle(color: AppColors.textSecondary)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Bearbeiten',
                  style: TextStyle(color: AppColors.primary)),
            ),
          ],
        ),
      );
      if (confirm != true || !mounted) return;
      final appEvent = await _adoptIcsEvent(event, (e) => e);
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => EventEditScreen(event: appEvent)),
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
      case 'reopen':
        updated = todo.copyWith(
            status: TodoStatus.pending, actualStart: null, actualEnd: null);
        await SupabaseService.saveTodo(updated);
      case 'unschedule':
        updated = todo.copyWith(scheduledDate: null,
            scheduledStartHour: null, scheduledStartMinute: null);
        await SupabaseService.saveTodo(updated);
      case 'edit':
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => TodoEditScreen(todo: todo)),
        );
      case 'delete':
        await SupabaseService.deleteTodo(todo.id);
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
      body: Stack(
        children: [
          Column(
            children: [
              if (_pendingChecklists.isNotEmpty) _buildChecklistBanner(),
              Expanded(child: _isDayView ? _buildDayView() : _buildWeekView()),
              _buildTodoPool(),
            ],
          ),
          // Snap-Level + Zeit Overlay
          AnimatedBuilder(
            animation: Listenable.merge([
              SnapState.isDraggingNotifier,
              SnapState.snapNotifier,
              SnapState.currentTimeNotifier,
            ]),
            builder: (ctx, _) {
              if (!SnapState.isDraggingNotifier.value) return const SizedBox.shrink();
              final snap = SnapState.snapNotifier.value;
              final time = SnapState.currentTimeNotifier.value;
              return Positioned(
                bottom: 80,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [BoxShadow(color: Colors.black38, blurRadius: 10)],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (time.isNotEmpty) ...[
                          Text(
                            time,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Container(width: 1, height: 20, color: Colors.white38),
                          const SizedBox(width: 10),
                        ],
                        Text(
                          snap == 1 ? '1 min' : '$snap min',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
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
    final String label;
    if (_isDayView) {
      const weekdays = ['Mo', 'Di', 'Mi', 'Do', 'Fr', 'Sa', 'So'];
      final wd = weekdays[_selectedDay.weekday - 1];
      label = '$wd, ${_selectedDay.day}.${_selectedDay.month}.${_selectedDay.year}';
    } else {
      final weekEnd = _weekStart.add(const Duration(days: 6));
      label =
          '${_weekStart.day}.${_weekStart.month} – ${weekEnd.day}.${weekEnd.month}.${weekEnd.year}';
    }

    return AppBar(
      backgroundColor: AppColors.surface,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.chevron_left, color: AppColors.textPrimary),
        onPressed: () => _isDayView ? _navigateDay(-1) : _navigateWeek(-1),
      ),
      title: GestureDetector(
        onTap: () {
          final today = DateTime.now();
          setState(() {
            _selectedDay = today;
            _weekStart = _getWeekStart(today);
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
          onPressed: () => _isDayView ? _navigateDay(1) : _navigateWeek(1),
        ),
        IconButton(
          icon: Icon(
            _isDayView ? Icons.view_week_outlined : Icons.today_outlined,
            color: AppColors.textPrimary,
          ),
          tooltip: _isDayView ? 'Wochenansicht' : 'Tagesansicht',
          onPressed: () {
            setState(() {
              _isDayView = !_isDayView;
              if (_isDayView) {
                _selectedDay = DateTime.now();
              }
            });
          },
        ),
        const FeedbackIconButton(),
      ],
    );
  }

  Widget _buildChecklistBanner() {
    final checklist = _pendingChecklists.first;
    return Container(
      color: AppColors.vacation.withValues(alpha: 0.15),
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
              setState(() {
                _pendingChecklists.remove(checklist);
                _initStreams();
              });
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
                      child: GestureDetector(
                        onTap: () => _onTodoTap(todo),
                        child: _TodoChip(todo: todo),
                      ),
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

  Widget _buildAllDayRow({required List<DateTime> days}) {
    // Collect unique events and compute column spans
    final seenIds = <String>{};
    final spans = <_AllDaySpan>[];
    for (int i = 0; i < days.length; i++) {
      for (final e in _allDayEventsForDay(days[i])) {
        if (!seenIds.add(e.id)) continue;
        final eStart = DateTime(e.startTime.year, e.startTime.month, e.startTime.day);
        var eEnd = DateTime(e.endTime.year, e.endTime.month, e.endTime.day);
        if (!eEnd.isAfter(eStart)) eEnd = eStart.add(const Duration(days: 1));
        int first = days.length, last = -1;
        for (int j = 0; j < days.length; j++) {
          final d = DateTime(days[j].year, days[j].month, days[j].day);
          if (!d.isBefore(eStart) && d.isBefore(eEnd)) {
            if (j < first) first = j;
            if (j > last) last = j;
          }
        }
        if (first <= last) spans.add(_AllDaySpan(event: e, startCol: first, endCol: last));
      }
    }
    if (spans.isEmpty) return const SizedBox.shrink();

    // Assign lanes (rows) to avoid horizontal overlap
    final lanes = <List<_AllDaySpan>>[];
    for (final span in spans) {
      int lane = 0;
      while (true) {
        if (lane >= lanes.length) { lanes.add([span]); break; }
        final clash = lanes[lane].any(
            (s) => s.startCol <= span.endCol && span.startCol <= s.endCol);
        if (!clash) { lanes[lane].add(span); break; }
        lane++;
      }
    }

    const double rowH = 20.0;
    const double rowGap = 2.0;
    final totalH = rowGap + lanes.length * (rowH + rowGap);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.divider, width: 0.5)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 46,
            child: Padding(
              padding: const EdgeInsets.only(top: 4, right: 2),
              child: Text('ganzt.',
                  style: const TextStyle(fontSize: 9, color: AppColors.textSecondary),
                  textAlign: TextAlign.right),
            ),
          ),
          Expanded(
            child: LayoutBuilder(builder: (ctx, constraints) {
              final colW = constraints.maxWidth / days.length;
              return SizedBox(
                height: totalH,
                child: Stack(
                  children: [
                    for (int laneIdx = 0; laneIdx < lanes.length; laneIdx++)
                      for (final span in lanes[laneIdx])
                        Positioned(
                          left: span.startCol * colW + 1,
                          top: rowGap + laneIdx * (rowH + rowGap),
                          width: (span.endCol - span.startCol + 1) * colW - 2,
                          height: rowH,
                          child: GestureDetector(
                            onTap: () => _onEventTap(span.event),
                            child: Container(
                              decoration: BoxDecoration(
                                color: (span.event.calendarColor != null
                                        ? Color(span.event.calendarColor!)
                                        : _categoryColor(span.event.category))
                                    .withValues(alpha: 0.85),
                                borderRadius: BorderRadius.circular(3),
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 4),
                              alignment: Alignment.centerLeft,
                              child: Text(
                                span.event.title,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w500),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ),
                  ],
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Color _categoryColor(EventCategory cat) {
    switch (cat) {
      case EventCategory.work: return AppColors.work;
      case EventCategory.sport: return AppColors.sport;
      case EventCategory.vacation: return AppColors.vacation;
      case EventCategory.personal: return AppColors.primary;
    }
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
            return Column(
              children: [
                // Fixer Header
                Row(
                  children: [
                    const SizedBox(width: 46),
                    ...List.generate(7, (i) {
                      final day = _weekStart.add(Duration(days: i));
                      final isToday = _isSameDay(day, DateTime.now());
                      return Expanded(
                        child: _DayHeaderWidget(
                          day: day,
                          isToday: isToday,
                        ),
                      );
                    }),
                  ],
                ),
                // Ganztägige Events
                _buildAllDayRow(
                  days: List.generate(7, (i) => _weekStart.add(Duration(days: i))),
                ),
                // Scrollbarer Zeitbereich
                Expanded(
                  child: SingleChildScrollView(
                    controller: _scrollController,
                    physics: _isCtrlPressed ? const NeverScrollableScrollPhysics() : const ClampingScrollPhysics(),
                    child: Listener(
                      onPointerSignal: (event) {
                        if (event is PointerScrollEvent) {
                          final isCtrl = HardwareKeyboard.instance.logicalKeysPressed.any((k) =>
                              k == LogicalKeyboardKey.controlLeft ||
                              k == LogicalKeyboardKey.controlRight);
                          if (isCtrl) {
                            GestureBinding.instance.pointerSignalResolver.register(event, (e) {
                              if (e is PointerScrollEvent) _onCtrlScroll(e.scrollDelta.dy);
                            });
                          }
                        }
                      },
                      child: Column(
                        children: [
                          const SizedBox(height: 16),
                          SizedBox(
                            height: (_endHour - _startHour) * _hourHeight,
                            child: Stack(
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _TimeAxis(
                                      startHour: _startHour,
                                      endHour: _endHour,
                                      hourHeight: _hourHeight,
                                    ),
                                    ...List.generate(7, (i) {
                                      final day = _weekStart.add(Duration(days: i));
                                      return Expanded(
                                        child: WeekDayColumn(
                                          day: day,
                                          events: _eventsForDay(day),
                                          todos: _todosForDay(day),
                                          isToday: _isSameDay(day, DateTime.now()),
                                          hourHeight: _hourHeight,
                                          startHour: _startHour,
                                          endHour: _endHour,
                                          showHeader: false,
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
                                _NowLine(
                                  startHour: _startHour,
                                  hourHeight: _hourHeight,
                                  timeAxisWidth: 46,
                                  weekStart: _weekStart,
                                  dayCount: 7,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildDayView() {
    return StreamBuilder<List<CalendarEvent>>(
      stream: _eventsStream,
      builder: (ctx, evSnap) {
        _events = evSnap.data ?? [];
        return StreamBuilder<List<Todo>>(
          stream: _todosStream,
          builder: (ctx, todoSnap) {
            _todos = todoSnap.data ?? [];
            return Column(
              children: [
                // Fixer Header
                Row(
                  children: [
                    const SizedBox(width: 46),
                    Expanded(
                      child: _DayHeaderWidget(
                        day: _selectedDay,
                        isToday: _isSameDay(_selectedDay, DateTime.now()),
                      ),
                    ),
                  ],
                ),
                // Ganztägige Events
                _buildAllDayRow(days: [_selectedDay]),
                // Scrollbarer Zeitbereich
                Expanded(
                  child: SingleChildScrollView(
                    controller: _scrollController,
                    physics: _isCtrlPressed ? const NeverScrollableScrollPhysics() : const ClampingScrollPhysics(),
                    child: Listener(
                      onPointerSignal: (event) {
                        if (event is PointerScrollEvent) {
                          final isCtrl = HardwareKeyboard.instance.logicalKeysPressed.any((k) =>
                              k == LogicalKeyboardKey.controlLeft ||
                              k == LogicalKeyboardKey.controlRight);
                          if (isCtrl) {
                            GestureBinding.instance.pointerSignalResolver.register(event, (e) {
                              if (e is PointerScrollEvent) _onCtrlScroll(e.scrollDelta.dy);
                            });
                          }
                        }
                      },
                      child: Column(
                        children: [
                          const SizedBox(height: 16),
                          SizedBox(
                            height: (_endHour - _startHour) * _hourHeight,
                            child: Stack(
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _TimeAxis(
                                      startHour: _startHour,
                                      endHour: _endHour,
                                      hourHeight: _hourHeight,
                                    ),
                                    Expanded(
                                      child: WeekDayColumn(
                                        day: _selectedDay,
                                        events: _eventsForDay(_selectedDay),
                                        todos: _todosForDay(_selectedDay),
                                        isToday: _isSameDay(_selectedDay, DateTime.now()),
                                        hourHeight: _hourHeight,
                                        startHour: _startHour,
                                        endHour: _endHour,
                                        showHeader: false,
                                        onTodoDrop: _onTodoDrop,
                                        onEventDrop: _onEventDrop,
                                        onEventTap: _onEventTap,
                                        onTodoTap: _onTodoTap,
                                        onTodoDroppedOnEvent: _onTodoDroppedOnEvent,
                                      ),
                                    ),
                                  ],
                                ),
                                _NowLine(
                                  startHour: _startHour,
                                  hourHeight: _hourHeight,
                                  timeAxisWidth: 46,
                                  weekStart: _selectedDay,
                                  dayCount: 1,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
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

  Future<void> _loadTodoDropSettings() async {
    final sources = await IcsService.getSources();
    final outlook = await IcsService.getOutlookAllowTodoDrop();
    if (mounted) setState(() { _icsSources = sources; _outlookAllowTodoDrop = outlook; });
  }

  bool _todoDropAllowed(CalendarEvent event) {
    if (event.source == 'app') return true;
    if (event.source == 'outlook') return _outlookAllowTodoDrop;
    if (event.source == 'ics' && event.icsSourceId != null) {
      final src = _icsSources.where((s) => s.id == event.icsSourceId).firstOrNull;
      return src?.allowTodoDrop ?? false;
    }
    return false;
  }

  @override
  void dispose() {
    _nowTimer?.cancel();
    SnapState.snapNotifier.removeListener(_onSnapChanged);
    SnapState.isDraggingNotifier.removeListener(_onSnapChanged);
    HardwareKeyboard.instance.removeHandler(_onKey);
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

// ── Now Line ─────────────────────────────────────────────────────────────────

class _NowLine extends StatelessWidget {
  final int startHour;
  final double hourHeight;
  final double timeAxisWidth;
  final DateTime weekStart;
  final int dayCount;

  const _NowLine({
    required this.startHour,
    required this.hourHeight,
    required this.timeAxisWidth,
    required this.weekStart,
    required this.dayCount,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    // Only show when today is visible
    bool todayVisible = false;
    int todayIndex = 0;
    for (int i = 0; i < dayCount; i++) {
      final d = weekStart.add(Duration(days: i));
      if (d.year == now.year && d.month == now.month && d.day == now.day) {
        todayVisible = true;
        todayIndex = i;
        break;
      }
    }
    if (!todayVisible) return const SizedBox.shrink();

    final top = (now.hour - startHour) * hourHeight + now.minute * (hourHeight / 60.0);

    return LayoutBuilder(builder: (ctx, constraints) {
      final totalWidth = constraints.maxWidth - timeAxisWidth;
      final colWidth = dayCount > 0 ? totalWidth / dayCount : totalWidth;
      final lineLeft = timeAxisWidth + todayIndex * colWidth;

      return Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            top: top,
            left: lineLeft,
            width: colWidth,
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Colors.redAccent,
                    shape: BoxShape.circle,
                  ),
                ),
                Expanded(
                  child: Container(
                    height: 1.5,
                    color: Colors.redAccent,
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    });
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

  double get _minuteHeight => hourHeight / 60.0;
  int get _totalHours => endHour - startHour;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([SnapState.isDraggingNotifier, SnapState.snapNotifier]),
      builder: (ctx, _) {
        final dragging = SnapState.isDraggingNotifier.value;
        final snapMinutes = SnapState.snapNotifier.value;
        // Sub-Stunden-Intervall: beim Ziehen snap-basiert, sonst zoom-basiert
        final int subInterval;
        if (dragging && snapMinutes < 60) {
          subInterval = snapMinutes;
        } else if (hourHeight >= 360) {
          subInterval = 5;
        } else if (hourHeight >= 180) {
          subInterval = 15;
        } else if (hourHeight >= 90) {
          subInterval = 30;
        } else {
          subInterval = 0;
        }

        final labels = <Widget>[];

        // Stunden-Labels
        for (int i = 0; i < _totalHours; i++) {
          final hour = startHour + i;
          labels.add(Positioned(
            top: i * hourHeight - 7,
            left: 0,
            right: 2,
            child: Text(
              '$hour:00',
              style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
              textAlign: TextAlign.right,
            ),
          ));
        }

        // Sub-Stunden-Labels
        if (subInterval > 0 && subInterval < 60) {
          for (int i = 0; i < _totalHours; i++) {
            final hour = startHour + i;
            int min = subInterval;
            while (min < 60) {
              final top = i * hourHeight + min * _minuteHeight - 6;
              final isQuarter = min % 15 == 0;
              labels.add(Positioned(
                top: top,
                left: 0,
                right: 2,
                child: Text(
                  '$hour:${min.toString().padLeft(2, '0')}',
                  style: TextStyle(
                    fontSize: isQuarter ? 8 : 7,
                    color: isQuarter
                        ? AppColors.textDisabled
                        : AppColors.textDisabled.withValues(alpha: 0.6),
                  ),
                  textAlign: TextAlign.right,
                ),
              ));
              min += subInterval;
            }
          }
        }

        return SizedBox(
          width: 46,
          height: _totalHours * hourHeight,
          child: Stack(children: labels),
        );
      },
    );
  }
}

class _DayHeaderWidget extends StatelessWidget {
  final DateTime day;
  final bool isToday;
  const _DayHeaderWidget({required this.day, required this.isToday});

  static const _weekdays = ['Mo', 'Di', 'Mi', 'Do', 'Fr', 'Sa', 'So'];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: isToday ? AppColors.primary.withValues(alpha: 0.15) : Colors.transparent,
        border: Border(bottom: BorderSide(color: AppColors.divider, width: 0.5)),
      ),
      child: Column(
        children: [
          Text(
            _weekdays[day.weekday - 1],
            style: TextStyle(
              fontSize: 12,
              color: isToday ? AppColors.primary : AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          Container(
            width: 30,
            height: 30,
            decoration: isToday
                ? const BoxDecoration(shape: BoxShape.circle, color: AppColors.primary)
                : null,
            alignment: Alignment.center,
            child: Text(
              '${day.day}',
              style: TextStyle(
                fontSize: 16,
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

class _AllDaySpan {
  final CalendarEvent event;
  final int startCol;
  final int endCol;
  const _AllDaySpan({required this.event, required this.startCol, required this.endCol});
}
