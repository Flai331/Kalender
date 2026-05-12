import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_config.dart';
import 'app_colors.dart';
import 'services/auth_service.dart';
import 'services/feedback_service.dart';
import 'services/reminder_service.dart';
import 'week/week_screen.dart' show WeekScreen, WeekScreenState;
import 'todos/todo_list_screen.dart';
import 'notes/notes_screen.dart';
import 'reminders/reminders_screen.dart';
import 'settings/settings_screen.dart';

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

  bool supabaseReady = false;
  if (SupabaseConfig.isConfigured) {
    try {
      await Supabase.initialize(
        url: SupabaseConfig.url,
        anonKey: SupabaseConfig.anonKey,
      );
      await AuthService.ensureSignedIn();
      supabaseReady = true;
    } catch (e) {
      debugPrint('Supabase Fehler: $e');
    }
  }

  await ReminderService.initialize();
  await ReminderService.requestPermissions();

  runApp(KalenderApp(supabaseReady: supabaseReady));
}

class KalenderApp extends StatelessWidget {
  final bool supabaseReady;

  const KalenderApp({super.key, required this.supabaseReady});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Kalender',
      debugShowCheckedModeBanner: false,
      theme: _buildDarkTheme(),
      navigatorKey: navigatorKey,
      navigatorObservers: [FeedbackService.screenObserver],
      home: supabaseReady ? const MainScreen() : const _SetupScreen(),
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
    const SettingsScreen(),
  ];

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

// ── Supabase Setup Screen ────────────────────────────────────────────────────

class _SetupScreen extends StatelessWidget {
  const _SetupScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.cloud_off, size: 64, color: AppColors.textDisabled),
              const SizedBox(height: 24),
              const Text(
                'Supabase einrichten',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Für Cloud-Sync muss Supabase einmalig konfiguriert werden:',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 15),
              ),
              const SizedBox(height: 24),
              _buildStep(1, 'Kostenloses Projekt auf supabase.com erstellen'),
              _buildStep(2, 'SQL aus lib/supabase_schema.sql in SQL-Editor ausführen'),
              _buildStep(3, 'URL + Anon-Key in lib/supabase_config.dart eintragen'),
              _buildStep(4, 'App neu starten'),
              const SizedBox(height: 32),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.divider),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('lib/supabase_config.dart:',
                        style: TextStyle(
                            color: AppColors.textSecondary, fontSize: 12)),
                    SizedBox(height: 6),
                    Text(
                      "static const String url = 'https://xxx.supabase.co';\n"
                      "static const String anonKey = 'eyJ...';",
                      style: TextStyle(
                        color: AppColors.primary,
                        fontSize: 12,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStep(int number, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primary,
            ),
            alignment: Alignment.center,
            child: Text(
              '$number',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                  color: AppColors.textPrimary, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}
