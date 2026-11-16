import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../build_info.dart';
import 'feedback_service.dart';
import 'offline_error.dart';

/// Prüft, ob im GitHub-Release eine neuere APK liegt als die installierte.
///
/// Grundlage ist die Datei `version.json`, die der Workflow neben der APK ins
/// Release legt. Release-Assets eines öffentlichen Repos sind ohne Login
/// abrufbar — anders als Actions-Artefakte, für die ein Token nötig wäre (das
/// in einer APK nichts zu suchen hätte).
///
/// Verglichen wird die Build-Nummer: der Workflow trägt sie beim Bauen in
/// `build_info.dart` ein, und dieselbe Nummer steht in der `version.json`.
class UpdateService {
  /// Repo, in dem die Releases liegen.
  static const String repo = 'Flai331/Kalender';

  /// Geprüft werden beide Kanäle: 'latest' ist der Stand des Standard-Branches,
  /// 'vorschau' der eines Feature-Branches. Genommen wird die höhere
  /// Build-Nummer, damit die Prüfung auch auf einem Vorschau-Build etwas
  /// Sinnvolles meldet.
  static const List<String> channels = ['latest', 'vorschau'];

  static const Duration timeout = Duration(seconds: 12);

  static String versionUrl(String channel) =>
      'https://github.com/$repo/releases/download/$channel/version.json';

  static String releaseUrl(String channel) =>
      'https://github.com/$repo/releases/tag/$channel';

  /// Native Seite: installierte Version, Prüfung der geladenen Datei und der
  /// Installer-Aufruf (siehe android/.../Updater.kt).
  static const MethodChannel _channel =
      MethodChannel('com.example.kalender/updater');

  /// Nur für Tests: erlaubt es, den Kanal zu ersetzen.
  @visibleForTesting
  static Future<T?> Function<T>(String method, [dynamic args])? invokeOverride;

  static Future<T?> _invoke<T>(String method, [dynamic args]) {
    final override = invokeOverride;
    if (override != null) return override<T>(method, args);
    return _channel.invokeMethod<T>(method, args);
  }

  static int _installedBuild = kBuildNumber;

  /// Die Build-Nummer dieser Installation.
  ///
  /// Wird beim ersten Aufruf vom System geholt (echter versionCode) und fällt
  /// auf die beim Bauen eingetragene Konstante zurück, wenn das nicht geht
  /// (z. B. im Test oder auf einer Plattform ohne den Kanal).
  static int get installedBuild => _installedBuild;

  static Future<int> refreshInstalledBuild() async {
    try {
      final code = await _invoke<int>('versionCode');
      if (code != null && code > 0) _installedBuild = code;
    } catch (e) {
      FeedbackService.log('versionCode nicht lesbar, nutze kBuildNumber: $e');
    }
    return _installedBuild;
  }

  static Future<UpdateCheckResult> check({http.Client? client}) async {
    final c = client ?? http.Client();
    final found = <ReleaseInfo>[];
    Object? lastError;

    try {
      for (final channel in channels) {
        try {
          final res =
              await c.get(Uri.parse(versionUrl(channel))).timeout(timeout);
          if (res.statusCode != 200) {
            // 404 heißt nur: dieser Kanal hat (noch) kein Release.
            if (res.statusCode != 404) {
              lastError = 'HTTP ${res.statusCode}';
            }
            continue;
          }
          final info = ReleaseInfo.tryParse(res.body, channel);
          if (info != null) found.add(info);
        } catch (e) {
          lastError = e;
        }
      }
    } finally {
      if (client == null) c.close();
    }

    if (found.isEmpty) {
      final offline = lastError != null && isOfflineError(lastError);
      return UpdateCheckResult(
        status: UpdateStatus.fehler,
        message: offline
            ? 'Keine Verbindung — Update-Prüfung nicht möglich.'
            : 'Update-Prüfung fehlgeschlagen'
                '${lastError != null ? ': $lastError' : '.'}',
      );
    }

    final newest = newestOf(found)!;
    if (newest.buildNumber > installedBuild) {
      return UpdateCheckResult(status: UpdateStatus.verfuegbar, release: newest);
    }
    return UpdateCheckResult(status: UpdateStatus.aktuell, release: newest);
  }

  /// Lädt die APK des Releases in den Cache und meldet den Fortschritt.
  ///
  /// Zurück kommt der Pfad der fertigen Datei. Geladen wird nach `.part` und
  /// erst am Ende umbenannt — eine abgebrochene Übertragung hinterlässt so
  /// keine halbe Datei, die der Installer annehmen könnte.
  static Future<String> downloadApk(
    ReleaseInfo release, {
    void Function(int received, int? total)? onProgress,
    http.Client? client,
  }) async {
    final dir = Directory(p.join((await getApplicationCacheDirectory()).path,
        'update')); // muss zu res/xml/file_paths.xml passen
    await dir.create(recursive: true);
    final target = File(p.join(dir.path, 'kalender.apk'));
    final part = File('${target.path}.part');
    if (await part.exists()) await part.delete();

    final c = client ?? http.Client();
    try {
      final req = http.Request('GET', Uri.parse(release.downloadUrl));
      final res = await c.send(req).timeout(const Duration(seconds: 60));
      if (res.statusCode != 200) {
        throw HttpException('Download nicht möglich (HTTP ${res.statusCode})');
      }
      final total = res.contentLength;
      var received = 0;
      final sink = part.openWrite();
      try {
        await res.stream.forEach((chunk) {
          sink.add(chunk);
          received += chunk.length;
          onProgress?.call(received, total);
        });
      } finally {
        await sink.close();
      }
      if (await target.exists()) await target.delete();
      await part.rename(target.path);
      return target.path;
    } catch (_) {
      if (await part.exists()) await part.delete();
      rethrow;
    } finally {
      if (client == null) c.close();
    }
  }

  /// Prüft die geladene Datei nativ: gültiges Paket, derselbe Paketname,
  /// höherer versionCode. Wirft mit lesbarem Text, wenn etwas nicht stimmt.
  static Future<void> verifyApk(String path) async {
    await _invoke<Map<dynamic, dynamic>>('verifyApk', {'path': path});
  }

  static Future<bool> canInstall() async =>
      await _invoke<bool>('canInstall') ?? false;

  static Future<void> openInstallSettings() async =>
      _invoke<bool>('openInstallSettings');

  /// Übergibt die Datei an den Android-Installer.
  ///
  /// 'installer' = Installer gestartet, 'settings' = Erlaubnis fehlte und die
  /// Einstellung wurde geöffnet, 'error' = fehlgeschlagen.
  static Future<String> install(String path) async =>
      await _invoke<String>('install', {'path': path}) ?? 'error';

  /// Das Release mit der höchsten Build-Nummer. Pur — für Tests.
  static ReleaseInfo? newestOf(List<ReleaseInfo> releases) {
    if (releases.isEmpty) return null;
    return releases
        .reduce((a, b) => b.buildNumber > a.buildNumber ? b : a);
  }
}

/// Inhalt der `version.json` eines Releases.
class ReleaseInfo {
  final int buildNumber;
  final String channel;
  final String commit;
  final String branch;
  final String apkUrl;

  ReleaseInfo({
    required this.buildNumber,
    required this.channel,
    this.commit = '',
    this.branch = '',
    this.apkUrl = '',
  });

  String get releaseUrl => UpdateService.releaseUrl(channel);

  /// Zieldatei: die APK aus demselben Release.
  String get downloadUrl => apkUrl.isNotEmpty
      ? apkUrl
      : 'https://github.com/${UpdateService.repo}/releases/download/$channel/kalender.apk';

  /// Liest die `version.json`. Gibt `null` zurück, wenn sie unbrauchbar ist —
  /// ein defektes Release darf die Prüfung nicht mit einer Exception beenden.
  static ReleaseInfo? tryParse(String body, String channel) {
    try {
      final dynamic decoded = jsonDecode(body);
      if (decoded is! Map<String, dynamic>) return null;
      final build = decoded['buildNumber'];
      final number = build is int ? build : int.tryParse('$build');
      if (number == null) return null;
      return ReleaseInfo(
        buildNumber: number,
        channel: channel,
        commit: '${decoded['commit'] ?? ''}',
        branch: '${decoded['branch'] ?? ''}',
        apkUrl: '${decoded['apkUrl'] ?? ''}',
      );
    } catch (_) {
      return null;
    }
  }
}

enum UpdateStatus { aktuell, verfuegbar, fehler }

class UpdateCheckResult {
  final UpdateStatus status;
  final ReleaseInfo? release;
  final String? message;

  UpdateCheckResult({required this.status, this.release, this.message});
}
