import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:home_widget/home_widget.dart';
import 'app_colors.dart';
import 'db/app_database.dart';
import 'models/todo.dart';
import 'services/feedback_service.dart';
import 'services/local_service.dart';
import 'services/reminder_service.dart';
import 'services/category_service.dart';
import 'services/travel_service.dart';
import 'services/widget_service.dart';
import 'week/week_screen.dart' show WeekScreen, WeekScreenState;
import 'todos/todo_edit_screen.dart';
import 'todos/todo_list_screen.dart';
import 'notes/notes_screen.dart';
import 'reminders/reminders_screen.dart';
import 'settings/settings_screen.dart';
import 'yearly/yearly_planner_screen.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Feedback-Service einrichten
  FeedbackService.setNavigatorKey(navigatorKey);

  // Flutter-Fehler abfangen – nur loggen, kein Auto-Dialog (verhindert Loop)
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    FeedbackService.log('FlutterError: ${details.exceptionAsString()}');
  };

  // Dart-Fehler abfangen (Netzwerkfehler ignorieren)
  PlatformDispatcher.instance.onError = (error, stack) {
    final msg = error.toString();
    FeedbackService.log('PlatformError: $msg');
    return true;
  };

  await ReminderService.initialize();
  await ReminderService.requestPermissions();

  final db = AppDatabase();
  await LocalService.init(db);
  // An-/Abfahrtszeiten in den Speicher holen, damit TravelService.resolve
  // ohne await auskommt und in build aufgerufen werden kann.
  await TravelService.load();

  // Namen und Farben der Kategorien; ohne sie zeigen Termine und Todos nur
  // ihren Schluessel.
  await CategoryService.load();

  // Serien-Erinnerungen einplanen. Muss nach LocalService.init laufen.
  // Bewusst nicht awaited: die Fallback-Regel fragt Outlook ab, und
  // outlook_service setzt keinen Timeout — ein hängender Request würde sonst
  // den App-Start blockieren. evaluateAll wirft nicht.
  unawaited(ReminderService.evaluateAll());

  await WidgetService.init();

  runApp(const KalenderApp());
}

class KalenderApp extends StatelessWidget {
  const KalenderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Kalender',
      debugShowCheckedModeBanner: false,
      theme: _buildDarkTheme(),
      navigatorKey: navigatorKey,
      navigatorObservers: [FeedbackService.screenObserver],
      home: const MainScreen(),
    );
  }

  ThemeData _buildDarkTheme() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        brightness: Brightness.dark,
      ).copyWith(
        surface: AppColors.surface,
        onSurface: AppColors.textPrimary,
      ),
      scaffoldBackgroundColor: AppColors.background,
      cardColor: AppColors.card,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.surface,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.textDisabled,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      dividerColor: AppColors.divider,
    );
  }
}

// ── Haupt-Navigation ─────────────────────────────────────────────────────────

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;
  final _weekKey = GlobalKey<WeekScreenState>();

  late final List<Widget> _screens = [
    WeekScreen(key: _weekKey),
    const TodoListScreen(),
    const NotesScreen(),
    const RemindersScreen(),
    const YearlyPlannerScreen(),
    const SettingsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _setupWidgetListener();
  }

  void _setupWidgetListener() {
    if (!Platform.isAndroid && !Platform.isIOS) return;
    HomeWidget.widgetClicked.listen(_handleWidgetUri);
    // Also handle if app was launched from widget
    HomeWidget.initiallyLaunchedFromHomeWidget().then((uri) {
      if (uri != null) _handleWidgetUri(uri);
    });
  }

  void _handleWidgetUri(Uri? uri) {
    if (uri == null) return;
    if (uri.host == 'toggle-todo') {
      final todoId = uri.queryParameters['todoId'];
      if (todoId != null) _handleWidgetToggle(todoId);
    } else if (uri.host == 'new-todo') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const TodoEditScreen()),
      );
    }
  }

  Future<void> _handleWidgetToggle(String todoId) async {
    final todo = await LocalService.getTodoById(todoId);
    if (todo == null) return;
    final updated = todo.copyWith(
      status: todo.status == TodoStatus.done ? TodoStatus.pending : TodoStatus.done,
      isCompleted: todo.status != TodoStatus.done,
    );
    await LocalService.saveTodo(updated);
    final todayTodos = await LocalService.getTodosForDate(DateTime.now());
    await WidgetService.update(todayTodos: todayTodos);
  }

  void _onTabTap(int i) {
    if (i == 0) _weekKey.currentState?.reload();
    setState(() => _currentIndex = i);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(
            top: BorderSide(color: AppColors.divider, width: 0.5),
          ),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: _onTabTap,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.calendar_view_week_outlined),
              activeIcon: Icon(Icons.calendar_view_week),
              label: 'Woche',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.checklist_outlined),
              activeIcon: Icon(Icons.checklist),
              label: 'Todos',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.sticky_note_2_outlined),
              activeIcon: Icon(Icons.sticky_note_2),
              label: 'Notizen',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.notifications_outlined),
              activeIcon: Icon(Icons.notifications),
              label: 'Erinnerungen',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.event_repeat_outlined),
              activeIcon: Icon(Icons.event_repeat),
              label: 'Jahresplan',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.settings_outlined),
              activeIcon: Icon(Icons.settings),
              label: 'Einstellungen',
            ),
          ],
        ),
      ),
    );
  }
}
