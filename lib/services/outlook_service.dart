import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Microsoft Graph API – Outlook Kalender Integration
///
/// Setup-Schritte (einmalig manuell):
/// 1. Azure Portal → App Registration erstellen
/// 2. Redirect URI hinzufügen: msauth://com.example.kalender/auth
/// 3. API Permissions: Calendars.ReadWrite, Tasks.ReadWrite
/// 4. CLIENT_ID unten eintragen
class OutlookService {
  // ⚠️ HIER NACH AZURE SETUP EINTRAGEN:
  static const String _clientId = 'DEINE_AZURE_CLIENT_ID';
  static const String _tenantId = 'common';
  static const String _redirectUri = 'msauth://com.example.kalender/auth';
  static const List<String> _scopes = [
    'Calendars.ReadWrite',
    'Tasks.ReadWrite',
    'offline_access',
  ];

  static const String _graphBase = 'https://graph.microsoft.com/v1.0';
  static const String _cacheKey = 'outlook_calendars_cache';

  static const _storage = FlutterSecureStorage();

  static bool get isConfigured => _clientId != 'DEINE_AZURE_CLIENT_ID';

  // ── OAuth PKCE Flow ────────────────────────────────────────────────────────

  static String _generateCodeVerifier() {
    final random = Random.secure();
    final bytes = List<int>.generate(32, (_) => random.nextInt(256));
    return base64UrlEncode(bytes).replaceAll('=', '');
  }

  static Future<void> signIn() async {
    if (!isConfigured) {
      debugPrint('OutlookService: Azure Client ID nicht konfiguriert');
      return;
    }
    final verifier = _generateCodeVerifier();
    await _storage.write(key: 'pkce_verifier', value: verifier);

    final authUrl = Uri.https(
      'login.microsoftonline.com',
      '/$_tenantId/oauth2/v2.0/authorize',
      {
        'client_id': _clientId,
        'response_type': 'code',
        'redirect_uri': _redirectUri,
        'scope': _scopes.join(' '),
        'code_challenge': verifier,
        'code_challenge_method': 'plain',
      },
    );

    await launchUrl(authUrl, mode: LaunchMode.externalApplication);
  }

  /// Aufrufen wenn App den Redirect-URI empfängt
  static Future<bool> handleRedirect(Uri uri) async {
    final code = uri.queryParameters['code'];
    if (code == null) return false;

    final verifier = await _storage.read(key: 'pkce_verifier');
    final response = await http.post(
      Uri.https('login.microsoftonline.com', '/$_tenantId/oauth2/v2.0/token'),
      body: {
        'client_id': _clientId,
        'grant_type': 'authorization_code',
        'code': code,
        'redirect_uri': _redirectUri,
        'code_verifier': verifier ?? '',
        'scope': _scopes.join(' '),
      },
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      await _storage.write(key: 'ms_access_token', value: data['access_token']);
      await _storage.write(key: 'ms_refresh_token', value: data['refresh_token']);
      return true;
    }
    return false;
  }

  static Future<bool> get isSignedIn async {
    final token = await _storage.read(key: 'ms_access_token');
    return token != null;
  }

  static Future<void> signOut() async {
    await _storage.delete(key: 'ms_access_token');
    await _storage.delete(key: 'ms_refresh_token');
  }

  // ── Token Management ───────────────────────────────────────────────────────

  static Future<String?> _getValidToken() async {
    var token = await _storage.read(key: 'ms_access_token');
    if (token == null) return null;

    // Token-Ablauf prüfen (einfache Heuristik: immer refreshen)
    token = await _refreshToken() ?? token;
    return token;
  }

  static Future<String?> _refreshToken() async {
    final refreshToken = await _storage.read(key: 'ms_refresh_token');
    if (refreshToken == null) return null;

    final response = await http.post(
      Uri.https('login.microsoftonline.com', '/$_tenantId/oauth2/v2.0/token'),
      body: {
        'client_id': _clientId,
        'grant_type': 'refresh_token',
        'refresh_token': refreshToken,
        'scope': _scopes.join(' '),
      },
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final newToken = data['access_token'] as String;
      await _storage.write(key: 'ms_access_token', value: newToken);
      if (data['refresh_token'] != null) {
        await _storage.write(key: 'ms_refresh_token', value: data['refresh_token']);
      }
      return newToken;
    }
    return null;
  }

  // ── Graph API Calls ────────────────────────────────────────────────────────

  static Future<List<Map<String, dynamic>>> getCalendars() async {
    final token = await _getValidToken();
    if (token == null) return [];

    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getString(_cacheKey);
    if (cached != null) {
      return (jsonDecode(cached) as List).cast<Map<String, dynamic>>();
    }

    final response = await http.get(
      Uri.parse('$_graphBase/me/calendars'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final calendars =
          (data['value'] as List).cast<Map<String, dynamic>>();
      await prefs.setString(_cacheKey, jsonEncode(calendars));
      return calendars;
    }
    return [];
  }

  /// Outlook Events in einem Zeitraum laden
  static Future<List<Map<String, dynamic>>> getEvents({
    required DateTime start,
    required DateTime end,
    String? calendarId,
  }) async {
    final token = await _getValidToken();
    if (token == null) return [];

    final startStr = start.toUtc().toIso8601String();
    final endStr = end.toUtc().toIso8601String();

    final path = calendarId != null
        ? '/me/calendars/$calendarId/calendarView'
        : '/me/calendarView';

    final uri = Uri.parse('$_graphBase$path').replace(queryParameters: {
      'startDateTime': startStr,
      'endDateTime': endStr,
      '\$select': 'id,subject,start,end,isAllDay',
      '\$orderby': 'start/dateTime',
    });

    final response = await http.get(
      uri,
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return (data['value'] as List).cast<Map<String, dynamic>>();
    }
    return [];
  }

  /// Prüft ob an einem bestimmten Datum ein Event mit Keyword existiert
  static Future<Map<String, dynamic>?> findEventOnDay({
    required DateTime day,
    required String keyword,
    String? calendarId,
  }) async {
    final start = DateTime(day.year, day.month, day.day);
    final end = start.add(const Duration(days: 1));
    final events = await getEvents(start: start, end: end, calendarId: calendarId);

    for (final event in events) {
      final subject = (event['subject'] as String? ?? '').toLowerCase();
      if (subject.contains(keyword.toLowerCase())) {
        return event;
      }
    }
    return null;
  }

  /// Startzeit eines Outlook-Events parsen
  static DateTime? parseEventStart(Map<String, dynamic> event) {
    final startData = event['start'] as Map<String, dynamic>?;
    if (startData == null) return null;
    final dateTimeStr = startData['dateTime'] as String?;
    if (dateTimeStr == null) return null;
    return DateTime.parse(dateTimeStr);
  }

  /// Outlook-Event verschieben (Uhrzeit/Datum ändern)
  static Future<bool> updateEvent({
    required String outlookEventId,
    required DateTime newStart,
    required DateTime newEnd,
  }) async {
    final token = await _getValidToken();
    if (token == null) return false;

    final response = await http.patch(
      Uri.parse('$_graphBase/me/events/$outlookEventId'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'start': {
          'dateTime': newStart.toUtc().toIso8601String(),
          'timeZone': 'UTC',
        },
        'end': {
          'dateTime': newEnd.toUtc().toIso8601String(),
          'timeZone': 'UTC',
        },
      }),
    );

    return response.statusCode == 200;
  }

  // ── Microsoft To Do ────────────────────────────────────────────────────────

  /// Alle To-Do Listen laden
  static Future<List<Map<String, dynamic>>> getTaskLists() async {
    final token = await _getValidToken();
    if (token == null) return [];

    final response = await http.get(
      Uri.parse('$_graphBase/me/todo/lists'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return (data['value'] as List).cast<Map<String, dynamic>>();
    }
    return [];
  }

  /// Tasks einer Liste laden (nur offene)
  static Future<List<Map<String, dynamic>>> getTasks(String listId) async {
    final token = await _getValidToken();
    if (token == null) return [];

    final uri = Uri.parse('$_graphBase/me/todo/lists/$listId/tasks').replace(
      queryParameters: {
        '\$filter': "status ne 'completed'",
        '\$select': 'id,title,body,dueDateTime,importance,status',
      },
    );

    final response = await http.get(
      uri,
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return (data['value'] as List).cast<Map<String, dynamic>>();
    }
    return [];
  }

  /// Task in Microsoft To Do als erledigt markieren
  static Future<bool> completeTask({
    required String listId,
    required String taskId,
  }) async {
    final token = await _getValidToken();
    if (token == null) return false;

    final response = await http.patch(
      Uri.parse('$_graphBase/me/todo/lists/$listId/tasks/$taskId'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'status': 'completed'}),
    );

    return response.statusCode == 200;
  }
}
