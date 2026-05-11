import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../app_colors.dart';
import '../models/calendar_event.dart';
import '../models/todo.dart';
import '../models/yearly_checklist.dart';
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
    // Scrolle zur aktuellen Uhrzeit
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToNow());
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
                  separatorBuilder: (_, __) => const SizedBox(width: 6),
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
                      return Expanded(
                        child: WeekDayColumn(
                          day: day,
                          events: _eventsForDay(day),
                          todos: _todosForDay(day),
                          isToday: isToday,
                          hourHeight: _hourHeight,
                          startHour: _startHour,
                          endHour: _endHour,
                          onTodoDrop: _onTodoDrop,
                          onEventDrop: _onEventDrop,
                          onEventTap: _onEventTap,
                          onTodoTap: _onTodoTap,
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
    _scrollController.dispose();
    super.dispose();
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
