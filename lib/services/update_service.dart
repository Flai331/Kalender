import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../build_info.dart';
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

  /// Die eingebaute Build-Nummer dieser Installation.
  static int get installedBuild => kBuildNumber;

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
