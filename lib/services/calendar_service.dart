import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../models/calendar.dart';
import 'auth_service.dart';
import 'ics_service.dart';

const _uuid = Uuid();
const _defaultCalendarKey = 'default_calendar_id';
const _calendarsMigratedKey = 'calendars_migrated';
const _defaultColor = 0xFFFF6D00; // orange, former 'personal' color

class CalendarService {
  static final _db = Supabase.instance.client;
  static String get _uid => AuthService.userId ?? '';

  // ── Stream ────────────────────────────────────────────────────────────────

  static Stream<List<Calendar>> calendarsStream() {
    return _db
        .from('calendars')
        .stream(primaryKey: ['id'])
        .eq('user_id', _uid)
        .map((rows) => rows
            .map((r) => Calendar.fromJson(r['data'] as Map<String, dynamic>))
            .toList()
          ..sort((a, b) => a.name.compareTo(b.name)));
  }

  // ── CRUD ──────────────────────────────────────────────────────────────────

  static Future<void> saveCalendar(Calendar cal) async {
    await _db.from('calendars').upsert({
      'id': cal.id,
      'user_id': _uid,
      'data': cal.toJson(),
    });
  }

  static Future<void> deleteCalendar(String id) async {
    await _db.from('calendars').delete().eq('id', id).eq('user_id', _uid);
  }

  static Future<List<Calendar>> getCalendars() async {
    final rows = await _db.from('calendars').select().eq('user_id', _uid);
    return (rows as List)
        .map((r) => Calendar.fromJson(r['data'] as Map<String, dynamic>))
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));
  }

  // ── Default calendar ──────────────────────────────────────────────────────

  static Future<String> getDefaultCalendarId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_defaultCalendarKey) ?? '';
  }

  // ── One-time migration ────────────────────────────────────────────────────

  /// Runs once on first launch after F6.
  /// 1. Creates default "Persönlich" calendar.
  /// 2. Migrates each existing IcsSource to its own Calendar.
  static Future<void> migrateIfNeeded() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_calendarsMigratedKey) == true) return;

    // 1. Default calendar
    final defaultId = _uuid.v4();
    await saveCalendar(Calendar(
      id: defaultId,
      name: 'Persönlich',
      color: _defaultColor,
    ));
    await prefs.setString(_defaultCalendarKey, defaultId);

    // 2. Migrate existing IcsSources
    try {
      final sources = await IcsService.getSources();
      for (final src in sources) {
        await saveCalendar(Calendar(
          id: _uuid.v4(),
          name: src.name,
          color: src.color ?? 0xFF448AFF,
          icsFeeds: [src],
        ));
      }
    } catch (e) {
      debugPrint('IcsSource migration skipped: $e');
    }

    await prefs.setBool(_calendarsMigratedKey, true);
  }
}
