import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import '../models/series_reminder.dart';
import 'supabase_service.dart';
import 'outlook_service.dart';

class ReminderService {
  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  static Future<void> initialize() async {
    tz.initializeTimeZones();

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: android);
    await _notifications.initialize(settings);
  }

  static Future<void> requestPermissions() async {
    await _notifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }

  /// Alle aktiven Serien-Erinnerungen evaluieren und Notifications planen
  static Future<void> evaluateAll() async {
    final reminders = await SupabaseService.getReminders();
    final now = DateTime.now();

    for (final reminder in reminders) {
      if (!reminder.isActive) continue;
      await _evaluate(reminder, now);
    }
  }

  static Future<void> _evaluate(SeriesReminder reminder, DateTime now) async {
    // Erinnerung für den aktuellen Monat berechnen
    final normalDay = DateTime(now.year, now.month, reminder.normalTriggerDay);

    DateTime triggerDate;
    int triggerHour = reminder.windowStartHour;
    int triggerMinute = reminder.windowStartMinute;

    if (reminder.fallbackCondition == 'if_event_on_day') {
      // Prüfen ob am normalTriggerDay ein passendes Outlook-Event existiert
      final event = await OutlookService.findEventOnDay(
        day: normalDay,
        keyword: reminder.triggerEventKeyword,
        calendarId: reminder.outlookCalendarId.isNotEmpty
            ? reminder.outlookCalendarId
            : null,
      );

      if (event != null) {
        // Fallback: Erinnerung am fallbackDay verschieben
        triggerDate = DateTime(now.year, now.month, reminder.fallbackDay);
        final eventStart = OutlookService.parseEventStart(event);
        if (eventStart != null) {
          final offsetTime =
              eventStart.add(Duration(minutes: reminder.fallbackOffsetMinutes));
          triggerHour = offsetTime.hour;
          triggerMinute = offsetTime.minute;
        }
      } else {
        // Kein Konflikt → normalTriggerDay verwenden
        triggerDate = normalDay;
      }
    } else {
      triggerDate = normalDay;
    }

    // Zeitfenster einhalten
    final windowStart =
        reminder.windowStartHour * 60 + reminder.windowStartMinute;
    final windowEnd = reminder.windowEndHour * 60 + reminder.windowEndMinute;
    final triggerMinutes = triggerHour * 60 + triggerMinute;

    if (triggerMinutes < windowStart) {
      triggerHour = reminder.windowStartHour;
      triggerMinute = reminder.windowStartMinute;
    } else if (triggerMinutes > windowEnd) {
      // Nächsten Tag, Anfang des Fensters
      triggerDate = triggerDate.add(const Duration(days: 1));
      triggerHour = reminder.windowStartHour;
      triggerMinute = reminder.windowStartMinute;
    }

    final triggerDateTime = DateTime(
      triggerDate.year,
      triggerDate.month,
      triggerDate.day,
      triggerHour,
      triggerMinute,
    );

    // Nicht in der Vergangenheit planen
    if (triggerDateTime.isBefore(now)) return;

    await _scheduleNotification(
      id: reminder.id.hashCode,
      title: reminder.title,
      body: reminder.message,
      scheduledAt: triggerDateTime,
    );
  }

  static Future<void> _scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledAt,
  }) async {
    final tzTime = tz.TZDateTime.from(scheduledAt, tz.local);

    const androidDetails = AndroidNotificationDetails(
      'series_reminders',
      'Serien-Erinnerungen',
      channelDescription: 'Kalender-gesteuerte Erinnerungen',
      importance: Importance.high,
      priority: Priority.high,
    );

    await _notifications.zonedSchedule(
      id,
      title,
      body,
      tzTime,
      const NotificationDetails(android: androidDetails),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  /// Einfache sofortige Testbenachrichtigung
  static Future<void> showTestNotification(String title, String body) async {
    const androidDetails = AndroidNotificationDetails(
      'test_channel',
      'Test',
      importance: Importance.high,
      priority: Priority.high,
    );
    await _notifications.show(
      0,
      title,
      body,
      const NotificationDetails(android: androidDetails),
    );
  }

  static Future<void> cancelAll() async {
    await _notifications.cancelAll();
  }

  static Future<void> cancel(int id) async {
    await _notifications.cancel(id);
  }
}
