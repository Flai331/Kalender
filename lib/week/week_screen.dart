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
import '../services/local_service.dart';
import '../services/place_reminder_service.dart';
import '../services/shift_service.dart';
import '../services/category_service.dart';
import '../services/travel_service.dart';
import '../services/widget_service.dart';
import '../services/ics_service.dart';
import '../models/ics_source.dart';
import 'week_day_column.dart';
import 'month_grid.dart';
import '../todos/todo_status_dialog.dart';
import '../widgets/feedback_button.dart';
import '../week/event_status_dialog.dart';
import '../week/event_edit_screen.dart';
import '../week/travel_override_dialog.dart';
import '../todos/todo_edit_screen.dart';

const _uuid = Uuid();

/// Der Zeitraum, den die Ansicht zeigt.
enum CalendarView { tag, woche, monat }

class WeekScreen extends StatefulWidget {
  const WeekScreen({super.key});

  @override
  State<WeekScreen> createState() => WeekScreenState();
}

class WeekScreenState extends State<WeekScreen> {
  late DateTime _weekStart;
  late DateTime _selectedDay;
  /// Erster Tag des Monats, den die Monatsansicht zeigt.
  late DateTime _month;
  CalendarView _view = CalendarView.woche;
  final ScrollController _scrollController = ScrollController();

  // Daten-Streams
  Stream<List<CalendarEvent>>? _eventsStream;
  Stream<List<Todo>>? _todosStream;
  Stream<List<Todo>>? _unscheduledStream;

  List<CalendarEvent> _events = [];
  List<CalendarEvent> _icsEvents = [];
  List<Todo> _todos = [];
  /// Tag, fuer den zuletzt Liegengebliebenes nachgeholt wurde.
  DateTime? _carriedOverFor;
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
    _month = DateTime(_selectedDay.year, _selectedDay.month, 1);
    _initStreams();
    _loadOverrides().then((_) => _loadIcsEvents());
    _checkYearlyChecklists();
    DaylightService.loadSettings();
    DaylightService.prefetchLocation();
    _loadBlockingCats();
    SnapState.snapNotifier.addListener(_onSnapChanged);
    SnapState.isDraggingNotifier.addListener(_onSnapChanged);
    // Neue An-/Abfahrtsvorgabe oder umbenannte Kategorie: sofort neu
    // zeichnen. Die Termine selbst haben sich nicht geaendert, der Stream
    // meldet also nichts.
    TravelService.revision.addListener(_onTravelChanged);
    CategoryService.revision.addListener(_onTravelChanged);
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
    // Auf Mitternacht des Montags, sonst fehlen beim Oeffnen am Nachmittag
    // die Termine von heute morgen.
    return addDays(DateTime(date.year, date.month, date.day), -(date.weekday - 1));
  }

  /// Erster Tag, den die aktuelle Ansicht zeigt.
  DateTime get _visibleStart => _view == CalendarView.monat
      ? monthGridDays(_month).first
      : DateTime(_weekStart.year, _weekStart.month, _weekStart.day);

  /// Erster Tag *nach* der aktuellen Ansicht.
  DateTime get _visibleEnd => _view == CalendarView.monat
      ? addDays(monthGridDays(_month).last, 1)
      : addDays(_visibleStart, 7);

  /// Der Tag, auf dem die Ansicht gerade steht. Beim Umschalten bleibt man
  /// damit am selben Datum, statt auf heute zurueckzufallen.
  DateTime get _anchorDay => switch (_view) {
        CalendarView.tag => _selectedDay,
        CalendarView.woche => _weekStart,
        CalendarView.monat =>
          (_selectedDay.year == _month.year && _selectedDay.month == _month.month)
              ? _selectedDay
              : _month,
      };

  void _onTravelChanged() {
    if (mounted) setState(() {});
  }

  void _initStreams() {
    // Die Monatsansicht braucht den ganzen sichtbaren Monat, nicht nur eine
    // Woche — deshalb hier der Zeitraum der Ansicht.
    _eventsStream = LocalService.eventsForRange(_visibleStart, _visibleEnd);
    _todosStream = LocalService.todosForRange(_visibleStart, _visibleEnd);
    _unscheduledStream = LocalService.unscheduledTodos();
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
    final start = _visibleStart;
    final end = _visibleEnd;
    if (mounted) {
      setState(() {
        // Mitgenommen wird alles, was in den Zeitraum hineinreicht: eine
        // Reise ueber den Monatswechsel soll in beiden Monaten stehen.
        _icsEvents = all
            .where((e) =>
                e.startTime.isBefore(end) &&
                !e.endTime.isBefore(start) &&
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
    // Beim Übernehmen verliert der Termin seine Herkunft: neue Kennung, keine
    // Quelle, keine Serie. Eine eingestellte An-/Abfahrt hinge damit in der
    // Luft — sie wird als eigener Wert mitgenommen, damit "Bearbeiten" nicht
    // heimlich das Aussehen ändert. War nichts eingestellt, erbt der Termin
    // ab jetzt die Vorgabe des eigenen Kalenders.
    final resolved = TravelService.resolve(ics);
    final before =
        resolved.travelMinutesBefore > 0 ? resolved.travelMinutesBefore : null;
    final after =
        resolved.travelMinutesAfter > 0 ? resolved.travelMinutesAfter : null;
    return ics.adoptedAsOwn(
      newId: _uuid.v4(),
      travelBeforeOverride: before,
      travelAfterOverride: after,
    );
  }

  Future<CalendarEvent> _adoptIcsEvent(
      CalendarEvent icsEvent, CalendarEvent Function(CalendarEvent) transform) async {
    // Guard: already adopted → skip to prevent duplicate entries
    if (_overriddenIcsIds.contains(icsEvent.id)) {
      return _convertIcsToApp(icsEvent);
    }
    final appEvent = transform(_convertIcsToApp(icsEvent));
    _overriddenIcsIds.add(icsEvent.id);
    // Remove from local list BEFORE any async — prevents a double entry
    if (mounted) {
      setState(() {
        _icsEvents = _icsEvents.where((e) => e.id != icsEvent.id).toList();
      });
    }
    _saveOverrides(); // fire-and-forget
    await LocalService.saveEvent(appEvent);
    // Der alte ICS-Termin ist ab jetzt ausgeblendet; seine eigene Einstellung
    // ist damit toter Ballast. Die Serien-Einstellung bleibt — die anderen
    // Vorkommen hängen noch daran.
    await TravelService.setEventTimes(icsEvent.id, null);
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
    final checklists = await LocalService.getYearlyChecklists();
    final now = DateTime.now();
    final pending =
        checklists.where((c) => c.shouldTrigger(now)).toList();
    if (pending.isNotEmpty && mounted) {
      setState(() => _pendingChecklists = pending);
    }
  }

  /// Ein Schritt vor (+1) oder zurueck (-1) — je nach Ansicht ein Tag, eine
  /// Woche oder ein Monat.
  void _navigate(int direction) {
    switch (_view) {
      case CalendarView.tag:
        _navigateDay(direction);
      case CalendarView.woche:
        _navigateWeek(direction);
      case CalendarView.monat:
        _navigateMonth(direction);
    }
  }

  /// Wischen nach links blaettert vor, nach rechts zurueck. Die Pfeile oben
  /// in der Titelzeile tun dasselbe, nur findet die am Handy niemand.
  void _onSwipe(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    // Darunter war es kein Wischen, sondern ein Verrutschen beim Tippen.
    if (velocity.abs() < 120) return;
    _navigate(velocity < 0 ? 1 : -1);
  }

  void _navigateMonth(int direction) {
    setState(() {
      _month = DateTime(_month.year, _month.month + direction, 1);
      _initStreams();
    });
    _loadIcsEvents();
  }

  void _navigateWeek(int direction) {
    setState(() {
      _weekStart = addDays(_weekStart, 7 * direction);
      _selectedDay = _weekStart;
      _initStreams();
    });
    _loadIcsEvents();
  }

  void _navigateDay(int direction) {
    final next = addDays(_selectedDay, direction);
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

  /// Umschalten zwischen Tag, Woche und Monat, ohne das Datum zu verlieren.
  void _setView(CalendarView view) {
    if (view == _view) return;
    final anchor = _anchorDay;
    setState(() {
      _view = view;
      _selectedDay = anchor;
      _weekStart = _getWeekStart(anchor);
      _month = DateTime(anchor.year, anchor.month, 1);
      _initStreams();
    });
    _loadIcsEvents();
  }

  /// Tippen auf den Titel springt in jeder Ansicht zurueck auf heute.
  void _goToToday() {
    final today = DateTime.now();
    setState(() {
      _selectedDay = today;
      _weekStart = _getWeekStart(today);
      _month = DateTime(today.year, today.month, 1);
      _initStreams();
    });
    _loadIcsEvents();
  }

  /// Tippen auf einen Tag im Monatsraster oeffnet ihn als Tagesansicht.
  void _openDay(DateTime day) {
    setState(() {
      _view = CalendarView.tag;
      _selectedDay = day;
      _weekStart = _getWeekStart(day);
      _initStreams();
    });
    _loadIcsEvents();
  }

  List<CalendarEvent> _eventsForDay(DateTime day) {
    final dayStart = DateTime(day.year, day.month, day.day);
    final dayEnd = dayStart.add(const Duration(days: 1));
    final icsFiltered = _icsEvents.where((e) => !_overriddenIcsIds.contains(e.id));
    final seen = <String>{};
    final all = [..._events, ...icsFiltered]
        .where((e) => seen.add(e.id))
        .toList();
    // Hier werden die An-/Abfahrtszeiten eingesetzt: eigener Wert, sonst
    // Serie, sonst Kalender-Vorgabe. Alles dahinter — Zeichnen, Kollisionen,
    // Auto-Shift — rechnet unveraendert mit travelMinutesBefore/After.
    return TravelService.resolveAll(all.where((e) {
      return !e.isAllDay &&
          e.startTime.isBefore(dayEnd) &&
          e.endTime.isAfter(dayStart);
    }))
      ..sort((a, b) => a.startTime.compareTo(b.startTime));
  }

  List<CalendarEvent> _allDayEventsForDay(DateTime day) {
    final dayStart = DateTime(day.year, day.month, day.day);
    final icsFiltered = _icsEvents.where((e) => !_overriddenIcsIds.contains(e.id));
    final seen = <String>{};
    final all = [..._events, ...icsFiltered].where((e) => seen.add(e.id)).toList();
    return all.where((e) {
      if (!e.isAllDay) return false;
      final eStart = DateTime(e.startTime.year, e.startTime.month, e.startTime.day);
      // ICS DTEND is exclusive; if end == start treat as 1-day
      var eEnd = DateTime(e.endTime.year, e.endTime.month, e.endTime.day);
      if (!eEnd.isAfter(eStart)) eEnd = eStart.add(const Duration(days: 1));
      return !dayStart.isBefore(eStart) && dayStart.isBefore(eEnd);
    }).toList();
  }

  /// Returns (blockStart, blockEnd) in minutes-since-midnight including travel.
  static (int, int) _eventBlock(CalendarEvent e) {
    final start = e.startTime.hour * 60 + e.startTime.minute;
    final end   = e.endTime.hour   * 60 + e.endTime.minute;
    return (start - e.travelMinutesBefore, end + e.travelMinutesAfter);
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
    // Include todo's own travel in the drop block
    final todoBlockStart = dropStart - todo.travelMinutesBefore;
    final todoBlockEnd   = dropEnd   + todo.travelMinutesAfter;
    final dayEvents = _eventsForDay(day);

    for (final event in dayEvents) {
      final (evStart, evEnd) = _eventBlock(event);
      final overlaps = todoBlockStart < evEnd && todoBlockEnd > evStart;
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
    await LocalService.saveTodo(updated);
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
    await LocalService.saveEvent(updated);
  }

  Future<void> _onEventTap(CalendarEvent event) async {
    // ICS-Event: in App-Event konvertieren und bearbeiten
    if (event.source == 'ics') {
      if (!mounted) return;
      final action = await showDialog<String>(
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
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Abbrechen',
                  style: TextStyle(color: AppColors.textSecondary)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, 'delete'),
              child: const Text('Ausblenden',
                  style: TextStyle(color: Colors.redAccent)),
            ),
            // Zu einem Termin, der nur zur Kenntnis dasteht, faehrt man
            // nicht hin: resolve() erzwingt dort 0/0. Der Knopf wuerde einen
            // Dialog oeffnen, dessen Eingabe nirgends ankommt.
            if (!event.infoOnly)
              TextButton(
                onPressed: () => Navigator.pop(ctx, 'travel'),
                child: const Text('An-/Abfahrt',
                    style: TextStyle(color: AppColors.primary)),
              ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, 'edit'),
              child: const Text('Bearbeiten',
                  style: TextStyle(color: AppColors.primary)),
            ),
          ],
        ),
      );
      if (action == null || !mounted) return;
      if (action == 'delete') {
        _overriddenIcsIds.add(event.id);
        _saveOverrides();
        if (mounted) {
          setState(() {
            _icsEvents = _icsEvents.where((e) => e.id != event.id).toList();
          });
        }
        return;
      }
      // An-/Abfahrt ohne Übernahme: der Termin bleibt am Abonnement.
      if (action == 'travel') {
        final match =
            _icsSources.where((s) => s.id == event.icsSourceId).toList();
        final name =
            match.isNotEmpty ? match.first.name : 'Importierter Kalender';
        if (!mounted) return;
        await TravelOverrideDialog.show(context, event, name);
        return;
      }
      if (action == 'edit') {
        final appEvent = await _adoptIcsEvent(event, (e) => e);
        if (!mounted) return;
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => EventEditScreen(event: appEvent)),
        );
      }
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
        await LocalService.saveEvent(updated);
      case 'pause':
        final pausedExtra = event.pauseStart != null
            ? now.difference(event.pauseStart!).inMinutes
            : 0;
        updated = event.copyWith(
          status: EventStatus.paused,
          pausedMinutes: event.pausedMinutes + pausedExtra,
          pauseStart: now,
        );
        await LocalService.saveEvent(updated);
      case 'resume':
        updated = event.copyWith(
          status: EventStatus.started,
          pauseStart: null,
        );
        await LocalService.saveEvent(updated);
      case 'done':
        updated = event.copyWith(
          status: EventStatus.done,
          actualEnd: now,
        );
        await LocalService.saveEvent(updated);
      case 'edit':
        if (!mounted) return;
        await Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => EventEditScreen(event: event)),
        );
      case 'delete':
        await LocalService.deleteEvent(event.id);
        // Sonst meldet sich die App noch fuer einen Termin, den es nicht
        // mehr gibt.
        await PlaceReminderService.cancelFor(event.id);
    }
  }

  Todo _adaptTodoTime(Todo todo) {
    if (todo.repeatType == RepeatType.none) return todo;
    if (todo.actualStart == null || todo.actualEnd == null) return todo;

    final actualMinutes = todo.actualEnd!
            .difference(todo.actualStart!)
            .inMinutes -
        todo.pausedMinutes;
    if (actualMinutes <= 0) return todo;

    final history = [...todo.durationHistory, actualMinutes];
    final capped = history.length > 10
        ? history.sublist(history.length - 10)
        : history;
    final avg = (capped.reduce((a, b) => a + b) / capped.length).round();

    return todo.copyWith(
      durationHistory: capped,
      estimatedMinutes: avg,
    );
  }

  /// Hakt ein To-do ab: Status, Dauer-Lernwert und der Zeitplan dahinter.
  Future<void> _markTodoDone(Todo todo, DateTime now) async {
    await LocalService.saveTodo(_adaptTodoTime(todo.markDone(now)));

    // Zeitplan automatisch anpassen (positiv = zu spät, negativ = früher)
    final delta = ShiftService.computeDelta(todo: todo, actualEnd: now);
    final verschoben = delta.abs() >= 2;
    if (verschoben) {
      await ShiftService.shiftAfterTodo(
          completedTodo: todo, deltaMinutes: delta);
    }
    if (!mounted) return;

    if (verschoben) {
      // Hier kein "Rückgängig": die Folgetermine sind mitgewandert, ein
      // halbes Zurueck waere schlimmer als keins.
      final msg = delta < 0
          ? '${(-delta)} min früher – Zeitplan vorgezogen'
          : '$delta min später – Zeitplan nach hinten verschoben';
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), duration: const Duration(seconds: 2)));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('${todo.title} erledigt'),
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: 'Rückgängig',
          onPressed: () => LocalService.saveTodo(todo),
        ),
      ));
    }
  }

  /// Macht ein erledigtes To-do wieder offen. `isCompleted` muss mit
  /// zurueck, sonst bleibt es aus der Todo-Leiste verschwunden.
  Future<void> _reopenTodo(Todo todo) async {
    await LocalService.saveTodo(todo.reopen());
  }

  /// Der Haken im Block: ein Tipp erledigt, ein zweiter macht es wieder auf.
  Future<void> _toggleTodoDone(Todo todo) async {
    if (todo.status == TodoStatus.done) {
      await _reopenTodo(todo);
      return;
    }
    await _markTodoDone(todo, DateTime.now());
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
        await LocalService.saveTodo(updated);
      case 'pause':
        final pausedExtra = todo.pauseStart != null
            ? now.difference(todo.pauseStart!).inMinutes
            : 0;
        updated = todo.copyWith(
          status: TodoStatus.paused,
          pausedMinutes: todo.pausedMinutes + pausedExtra,
          pauseStart: now,
        );
        await LocalService.saveTodo(updated);
      case 'resume':
        updated = todo.copyWith(status: TodoStatus.started, pauseStart: null);
        await LocalService.saveTodo(updated);
      case 'done':
        await _markTodoDone(todo, now);
      case 'reopen':
        await _reopenTodo(todo);
      case 'unschedule':
        updated = todo.copyWith(scheduledDate: null,
            scheduledStartHour: null, scheduledStartMinute: null);
        await LocalService.saveTodo(updated);
      case 'edit':
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => TodoEditScreen(todo: todo)),
        );
      case 'delete':
        await LocalService.deleteTodo(todo.id);
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
              Expanded(
                child: GestureDetector(
                  onHorizontalDragEnd: _onSwipe,
                  child: switch (_view) {
                    CalendarView.tag => _buildDayView(),
                    CalendarView.woche => _buildWeekView(),
                    CalendarView.monat => _buildMonthView(),
                  },
                ),
              ),
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

  String _dayLabel() {
    const weekdays = ['Mo', 'Di', 'Mi', 'Do', 'Fr', 'Sa', 'So'];
    final wd = weekdays[_selectedDay.weekday - 1];
    return '$wd, ${_selectedDay.day}.${_selectedDay.month}.${_selectedDay.year}';
  }

  String _weekLabel() {
    final weekEnd = addDays(_weekStart, 6);
    return '${_weekStart.day}.${_weekStart.month} – '
        '${weekEnd.day}.${weekEnd.month}.${weekEnd.year}';
  }

  IconData _viewIcon(CalendarView view) => switch (view) {
        CalendarView.tag => Icons.view_day_outlined,
        CalendarView.woche => Icons.view_week_outlined,
        CalendarView.monat => Icons.calendar_month_outlined,
      };

  String _viewName(CalendarView view) => switch (view) {
        CalendarView.tag => 'Tag',
        CalendarView.woche => 'Woche',
        CalendarView.monat => 'Monat',
      };

  /// Monatsraster. Die Termine kommen aus demselben Stream wie in der Woche,
  /// nur ueber den ganzen Monat.
  Widget _buildMonthView() {
    return StreamBuilder<List<CalendarEvent>>(
      stream: _eventsStream,
      builder: (ctx, evSnap) {
        _events = evSnap.data ?? [];
        return MonthGrid(
          month: _month,
          selectedDay: _selectedDay,
          days: monthGridDays(_month),
          entriesForDay: _monthEntriesForDay,
          onDayTap: _openDay,
        );
      },
    );
  }

  /// Was an einem Tag im Monatsraster steht: erst die ganztaegigen Termine,
  /// dann die mit Uhrzeit in zeitlicher Reihenfolge.
  List<CalendarEvent> _monthEntriesForDay(DateTime day) =>
      [..._allDayEventsForDay(day), ..._eventsForDay(day)];

  AppBar _buildAppBar() {
    final label = switch (_view) {
      CalendarView.tag => _dayLabel(),
      CalendarView.woche => _weekLabel(),
      CalendarView.monat => '${monthNames[_month.month - 1]} ${_month.year}',
    };

    return AppBar(
      backgroundColor: AppColors.surface,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.chevron_left, color: AppColors.textPrimary),
        onPressed: () => _navigate(-1),
      ),
      title: GestureDetector(
        onTap: _goToToday,
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
          onPressed: () => _navigate(1),
        ),
        PopupMenuButton<CalendarView>(
          icon: Icon(_viewIcon(_view), color: AppColors.textPrimary),
          tooltip: 'Ansicht',
          color: AppColors.surface,
          onSelected: _setView,
          itemBuilder: (ctx) => [
            for (final view in CalendarView.values)
              PopupMenuItem<CalendarView>(
                value: view,
                height: 42,
                child: Row(
                  children: [
                    Icon(_viewIcon(view),
                        size: 18,
                        color: view == _view
                            ? AppColors.primary
                            : AppColors.textSecondary),
                    const SizedBox(width: 10),
                    Text(_viewName(view),
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: view == _view
                                ? FontWeight.w600
                                : FontWeight.w400,
                            color: view == _view
                                ? AppColors.primary
                                : AppColors.textPrimary)),
                  ],
                ),
              ),
          ],
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
              await LocalService.saveTodo(todo);
              // lastTriggeredYear aktualisieren
              final updated = checklist.copyWith(
                  lastTriggeredYear: DateTime.now().year);
              await LocalService.saveYearlyChecklist(updated);
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
                child: Text('TODOS – Haken erledigt, lange halten & ziehen',
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
                        child: _TodoChip(
                          todo: todo,
                          onToggleDone: () => _toggleTodoDone(todo),
                        ),
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
                                        : AppColors.forCategory(
                                            span.event.category))
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

  Widget _buildWeekView() {
    return StreamBuilder<List<CalendarEvent>>(
      stream: _eventsStream,
      builder: (ctx, evSnap) {
        _events = evSnap.data ?? [];
        return StreamBuilder<List<Todo>>(
          stream: _todosStream,
          builder: (ctx, todoSnap) {
            _todos = todoSnap.data ?? [];
            final now = DateTime.now();
            final today = DateTime(now.year, now.month, now.day);
            final todayTodos = _todos.where((t) =>
                t.scheduledDate != null &&
                t.scheduledDate!.year == today.year &&
                t.scheduledDate!.month == today.month &&
                t.scheduledDate!.day == today.day).toList();
            WidgetService.update(todayTodos: todayTodos);
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
                                          onTodoToggleDone: _toggleTodoDone,
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
            final now = DateTime.now();
            final today = DateTime(now.year, now.month, now.day);
            final todayTodos = _todos.where((t) =>
                t.scheduledDate != null &&
                t.scheduledDate!.year == today.year &&
                t.scheduledDate!.month == today.month &&
                t.scheduledDate!.day == today.day).toList();
            WidgetService.update(todayTodos: todayTodos);
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
                                        onTodoToggleDone: _toggleTodoDone,
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
    // Ein Termin nur zur Kenntnis verbietet gar nichts.
    if (event.infoOnly) return true;
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
    TravelService.revision.removeListener(_onTravelChanged);
    CategoryService.revision.removeListener(_onTravelChanged);
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
    await LocalService.saveTodo(updated);
  }

  bool _dayBlockedByAllDay(DateTime day) {
    // ICS-Events werden nur für die aktuelle Woche geladen.
    // Ganztags-ICS-Events außerhalb der Woche blockieren daher nicht.
    final icsFiltered = _icsEvents.where((e) => !_overriddenIcsIds.contains(e.id));
    final allEventsOnDay = [..._events, ...icsFiltered].where((e) =>
        e.isAllDay &&
        // Nur zur Kenntnis: der Dienstplan eines anderen blockiert nicht
        // den eigenen Tag.
        !e.infoOnly &&
        e.startTime.year == day.year &&
        e.startTime.month == day.month &&
        e.startTime.day == day.day);
    return allEventsOnDay
        .any((e) => _blockingAllDayCats.contains(e.category));
  }

  List<CalendarEvent> _timedEventsOnDay(DateTime day) {
    final icsFiltered = _icsEvents.where((e) => !_overriddenIcsIds.contains(e.id));
    final seen = <String>{};
    return TravelService.resolveAll([..._events, ...icsFiltered]
        .where((e) => seen.add(e.id))
        // Hiermit sucht die App freie Zeit. Ein Termin nur zur Kenntnis
        // belegt keine — sonst waere der Tag eines anderen Menschen auf
        // einmal der eigene.
        .where((e) => !e.infoOnly)
        .where((e) =>
            !e.isAllDay &&
            e.startTime.year == day.year &&
            e.startTime.month == day.month &&
            e.startTime.day == day.day))
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
              final (es, ee) = _eventBlock(e!);
              return pos < ee && pos + total > es;
            },
            orElse: () => null,
          );
          if (blocker == null) {
            found = true;
            break;
          }
          final (_, newPos) = _eventBlock(blocker);
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

  /// Holt offene To-dos aus vergangenen Tagen auf heute.
  ///
  /// Ohne das bleiben sie liegen, wo sie waren: der Auto-Shift unten sieht nur
  /// den heutigen Tag an, und um Mitternacht ist ein unerledigtes To-do nicht
  /// mehr "heute". Gerade das, was man liegen laesst, verschwaende damit nach
  /// hinten aus dem Blick.
  ///
  /// Laeuft einmal beim Oeffnen und danach einmal je Tageswechsel — oefter
  /// waere es eine Abfrage ohne Ergebnis.
  Future<void> _carryOverOpenTodos(DateTime today) async {
    if (_carriedOverFor == today) return;
    _carriedOverFor = today; // vor dem await: der Timer ruft jede Minute
    final stale = await LocalService.getOpenTodosBefore(today);
    if (stale.isEmpty) return;

    for (final todo in stale) {
      // Die Uhrzeit bleibt. Ist sie heute schon vorbei, raeumt der Shift
      // unten das To-do ohnehin nach vorne.
      await LocalService.saveTodo(todo.copyWith(scheduledDate: today));
    }

    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(stale.length == 1
            ? 'Ein liegengebliebenes To-do auf heute geholt.'
            : '${stale.length} liegengebliebene To-dos auf heute geholt.'),
      ));
    });
  }

  Future<void> _autoShiftOverdueTodos() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final nowMinutes = now.hour * 60 + now.minute;

    await _carryOverOpenTodos(today);

    // Aus der Datenbank, nicht aus _todos: _todos haelt die ANGEZEIGTE Woche.
    // Blaettert man eine Woche weiter, waeren die heutigen To-dos nicht darin
    // und der Shift liefe ins Leere.
    final todayTodos = (await LocalService.getTodosForDate(today))
        .where((t) =>
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
        .map(_eventBlock)
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
            await LocalService.saveTodo(todo.copyWith(
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
            await LocalService.saveTodo(todo.copyWith(
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
      await LocalService.saveTodo(todo.copyWith(
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

  /// Ohne Rueckruf (im Schleppbild) bleibt der Haken ein reines Symbol.
  final VoidCallback? onToggleDone;

  const _TodoChip({required this.todo, this.onToggleDone});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(4, 5, 10, 5),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onToggleDone,
            child: const Padding(
              padding: EdgeInsets.fromLTRB(4, 4, 6, 4),
              child: Icon(Icons.radio_button_unchecked,
                  size: 17, color: AppColors.textDisabled),
            ),
          ),
          Column(
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
