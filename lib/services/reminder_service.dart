import 'dart:typed_data';

import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import '../models/calendar_event.dart';
import '../models/reminder_urgency.dart';
import '../models/series_reminder.dart';
import 'feedback_service.dart';
import 'ics_service.dart';
import 'local_service.dart';

class ReminderService {
  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  /// Wird gerufen, wenn der Benutzer eine Benachrichtigung antippt.
  /// Setzt main.dart, damit dieser Dienst keine Bildschirme kennen muss.
  static void Function(String? payload)? onTap;

  static Future<void> initialize() async {
    tz.initializeTimeZones();

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: android);
    await _notifications.initialize(
      settings,
      onDidReceiveNotificationResponse: (antwort) =>
          onTap?.call(antwort.payload),
    );
  }

  /// Die Nutzlast der Benachrichtigung, mit der die App gestartet wurde —
  /// null, wenn sie normal geoeffnet wurde. Beim kalten Start kommt der
  /// Rueckruf oben nicht, die Nutzlast liegt nur hier.
  static Future<String?> startPayload() async {
    try {
      final details = await _notifications.getNotificationAppLaunchDetails();
      if (details?.didNotificationLaunchApp != true) return null;
      return details?.notificationResponse?.payload;
    } catch (_) {
      return null;
    }
  }

  static Future<void> requestPermissions() async {
    await _notifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }

  /// Alle aktiven Serien-Erinnerungen evaluieren und Notifications planen.
  ///
  /// Wirft nie: die Methode läuft beim App-Start und nach jedem Speichern,
  /// ein Fehler darf weder den Start noch die übrigen Erinnerungen kippen.
  /// `_evaluate` holt für die Fallback-Regel die abonnierten Kalender —
  /// ohne Netz schlägt das fehl, die Erinnerungen ohne Fallback müssen
  /// trotzdem geplant werden.
  static Future<void> evaluateAll() async {
    final List<SeriesReminder> reminders;
    try {
      reminders = await LocalService.getReminders();
    } catch (e) {
      FeedbackService.log('Erinnerungen konnten nicht geladen werden: $e');
      return;
    }
    final now = DateTime.now();

    for (final reminder in reminders) {
      if (!reminder.isActive) continue;
      try {
        await _evaluate(reminder, now);
      } catch (e) {
        FeedbackService.log(
            'Erinnerung "${reminder.title}" nicht planbar: $e');
      }
    }
  }

  /// Sucht den Ausloeser-Termin an einem Tag in den abonnierten Kalendern.
  ///
  /// Die Termine kommen aus den ICS-Abos — das ist der einzige Weg, auf dem
  /// Outlook-Termine in dieser App landen. Ohne `sourceId` zaehlen alle
  /// sichtbaren Kalender. Ein leeres Stichwort heisst "irgendein Termin an
  /// dem Tag". Bei mehreren Treffern gewinnt der frueheste.
  static Future<CalendarEvent?> findEventOnDay({
    required DateTime day,
    required String keyword,
    String? sourceId,
    List<CalendarEvent>? events,
  }) async {
    final alle = events ?? await IcsService.fetchEvents();
    final tagStart = DateTime(day.year, day.month, day.day);
    final tagEnde = DateTime(day.year, day.month, day.day + 1);
    final suche = keyword.trim().toLowerCase();

    final treffer = alle.where((e) {
      if (sourceId != null && e.icsSourceId != sourceId) return false;
      // Ueberlappung mit dem Tag, gleiche Regel wie in der Wochenansicht.
      if (!e.startTime.isBefore(tagEnde)) return false;
      if (e.endTime.isBefore(tagStart)) return false;
      if (suche.isEmpty) return true;
      return e.title.toLowerCase().contains(suche);
    }).toList()
      ..sort((a, b) => a.startTime.compareTo(b.startTime));

    return treffer.isEmpty ? null : treffer.first;
  }

  static Future<void> _evaluate(SeriesReminder reminder, DateTime now) async {
    // Erinnerung für den aktuellen Monat berechnen
    final normalDay = DateTime(now.year, now.month, reminder.normalTriggerDay);

    DateTime triggerDate;
    int triggerHour = reminder.windowStartHour;
    int triggerMinute = reminder.windowStartMinute;

    if (reminder.fallbackCondition == 'if_event_on_day') {
      // Prüfen ob am normalTriggerDay ein passender Termin im abonnierten
      // Kalender steht
      final event = await findEventOnDay(
        day: normalDay,
        keyword: reminder.triggerEventKeyword,
        sourceId: reminder.calendarSourceId.isNotEmpty
            ? reminder.calendarSourceId
            : null,
      );

      if (event != null) {
        // Fallback: Erinnerung am fallbackDay verschieben
        triggerDate = DateTime(now.year, now.month, reminder.fallbackDay);
        final offsetTime = event.startTime
            .add(Duration(minutes: reminder.fallbackOffsetMinutes));
        triggerHour = offsetTime.hour;
        triggerMinute = offsetTime.minute;
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

    await scheduleAt(
      id: reminder.id.hashCode,
      title: reminder.title,
      body: reminder.message,
      scheduledAt: triggerDateTime,
    );
  }

  /// Was eine Stufe auf Android bedeutet.
  ///
  /// Die Zuordnung steht nur hier, damit sie nicht an mehreren Stellen
  /// auseinanderlaeuft. [ReminderUrgency.dringend] ist genau das, was die
  /// Serien-Erinnerungen und die Ortsvorschlaege vorher fest eingebaut
  /// hatten — darum ist es auch die Vorgabe von [scheduleAt].
  ///
  /// **Die Stufe gehoert zum Kanal, nicht zur einzelnen Meldung**: Android
  /// uebernimmt Wichtigkeit, Ton und Rutteln beim **Anlegen** des Kanals und
  /// ignoriert sie danach. Wer die Stufe wechselt, muss deshalb auch den
  /// `channelId` wechseln, sonst bleibt alles beim Alten.
  static AndroidNotificationDetails androidFuer(
    ReminderUrgency urgency, {
    required String channelId,
    required String channelName,
    required String channelDescription,
  }) {
    switch (urgency) {
      case ReminderUrgency.still:
        return AndroidNotificationDetails(channelId, channelName,
            channelDescription: channelDescription,
            importance: Importance.low,
            priority: Priority.low,
            playSound: false,
            enableVibration: false);
      case ReminderUrgency.normal:
        return AndroidNotificationDetails(channelId, channelName,
            channelDescription: channelDescription,
            importance: Importance.defaultImportance,
            priority: Priority.defaultPriority);
      case ReminderUrgency.dringend:
        return AndroidNotificationDetails(channelId, channelName,
            channelDescription: channelDescription,
            importance: Importance.high,
            priority: Priority.high);
      case ReminderUrgency.alarm:
        return AndroidNotificationDetails(channelId, channelName,
            channelDescription: channelDescription,
            importance: Importance.max,
            priority: Priority.max,
            category: AndroidNotificationCategory.alarm,
            // Ueber die Alarm-Lautstaerke statt der Benachrichtigungs-:
            // die geht beim Stummschalten des Klingeltons nicht mit.
            audioAttributesUsage: AudioAttributesUsage.alarm,
            vibrationPattern:
                Int64List.fromList([0, 600, 300, 600, 300, 600]));
    }
  }

  /// Plant eine Benachrichtigung auf einen Zeitpunkt.
  ///
  /// Offen fuer andere Dienste (die Ortsvorschlaege und die
  /// Abfahrt-Erinnerung nutzen es), darum mit eigenem Kanal und Nutzlast.
  static Future<void> scheduleAt({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledAt,
    String? payload,
    String channelId = 'series_reminders',
    String channelName = 'Serien-Erinnerungen',
    String channelDescription = 'Kalender-gesteuerte Erinnerungen',
    ReminderUrgency urgency = ReminderUrgency.dringend,
  }) async {
    if (scheduledAt.isBefore(DateTime.now())) return;
    final androidDetails = androidFuer(
      urgency,
      channelId: channelId,
      channelName: channelName,
      channelDescription: channelDescription,
    );
    await _stellen(
      id: id,
      title: title,
      body: body,
      wann: tz.TZDateTime.from(scheduledAt, tz.local),
      details: NotificationDetails(android: androidDetails),
      payload: payload,
    );
  }

  /// Ob schon einmal gemeldet wurde, dass es nur ungenau geht. Einmal je
  /// App-Lauf genügt — sonst stehen bei zwanzig Terminen zwanzig gleiche
  /// Zeilen im Protokoll.
  static bool _ungenauGemeldet = false;

  /// Stellt die Meldung — notfalls ungenau.
  ///
  /// `exactAllowWhileIdle` braucht ab Android 14 eine Erlaubnis. Die App
  /// bringt sie im Manifest mit (`USE_EXACT_ALARM`), aber ein
  /// Hersteller-Aufsatz oder ein von Hand entzogenes Recht kann sie trotzdem
  /// verweigern; das Plugin wirft dann `exact_alarms_not_permitted`. Eine
  /// Meldung, die ein paar Minuten später kommt, ist besser als keine — und
  /// vor allem besser als ein Fehler, der die ganze Planung abbricht.
  static Future<void> _stellen({
    required int id,
    required String title,
    required String body,
    required tz.TZDateTime wann,
    required NotificationDetails details,
    String? payload,
  }) async {
    Future<void> versuch(AndroidScheduleMode modus) =>
        _notifications.zonedSchedule(
          id,
          title,
          body,
          wann,
          details,
          androidScheduleMode: modus,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          payload: payload,
        );

    try {
      await versuch(AndroidScheduleMode.exactAllowWhileIdle);
    } on PlatformException catch (e) {
      if (e.code != 'exact_alarms_not_permitted') rethrow;
      if (!_ungenauGemeldet) {
        _ungenauGemeldet = true;
        FeedbackService.log('Weckgenaue Meldungen sind nicht erlaubt — '
            'Erinnerungen kommen ungefähr statt genau zur Zeit.');
      }
      await versuch(AndroidScheduleMode.inexactAllowWhileIdle);
    }
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
