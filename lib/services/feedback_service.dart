import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:flutter/rendering.dart';
import 'package:flutter_email_sender/flutter_email_sender.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app_colors.dart';
import '../build_info.dart';
import '../secrets.dart';

// ═══════════════════════════════════════════════════════════════
//  FEEDBACK & ERROR LOGGER
//
//  Primär: Notion-Datenbank → sendet Text direkt aus der App.
//  Fallback: öffnet E-Mail-App.
// ═══════════════════════════════════════════════════════════════

class FeedbackService {
  // ── Konfiguration aus secrets.dart ─────────────────────────
  static const String _notionToken  = kNotionToken;
  static const String _notionDbId   = kNotionDbId;
  static const String _supportEmail = kSupportEmail;

  static bool get _notionConfigured => _notionToken != 'DEIN_NOTION_TOKEN';

  static final List<String> _log = [];

  // ── Screen-Tracking ─────────────────────────────────────────
  static String _currentScreen = '';
  static void setCurrentScreen(String name) => _currentScreen = name;
  static NavigatorObserver get screenObserver => _ScreenObserver();

  // Key vom RepaintBoundary in main.dart (für Auto-Screenshot)
  static GlobalKey? _repaintKey;
  static void setRepaintKey(GlobalKey key) => _repaintKey = key;

  // Navigator-Key für automatische Dialog-Öffnung ohne BuildContext
  static GlobalKey<NavigatorState>? _navigatorKey;
  static void setNavigatorKey(GlobalKey<NavigatorState> key) =>
      _navigatorKey = key;

  // Verhindert dass mehrere Fehler gleichzeitig mehrere Dialoge öffnen
  static bool _dialogOpen = false;

  // ── Automatisch bei abgefangenem Fehler aufrufen ────────────
  static Future<void> showAutoErrorDialog() async {
    if (_dialogOpen) return;
    final ctx = _navigatorKey?.currentContext;
    if (ctx == null) return;
    _dialogOpen = true;
    try {
      await showReportDialog(ctx, isAutoError: true);
    } finally {
      _dialogOpen = false;
    }
  }

  // ── Protokoll-Eintrag ───────────────────────────────────────
  static void log(String message) {
    final now = DateTime.now();
    final h = now.hour.toString().padLeft(2, '0');
    final m = now.minute.toString().padLeft(2, '0');
    final s = now.second.toString().padLeft(2, '0');
    final entry = '[$h:$m:$s] $message';
    _log.add(entry);
    if (_log.length > 200) _log.removeAt(0);
    debugPrint(entry);
  }

  // ── Automatischen Screenshot erfassen ──────────────────────
  static Future<String?> _captureScreenshot() async {
    if (kIsWeb) { log('Screenshot: Web nicht unterstützt'); return null; }
    if (_repaintKey == null) { log('Screenshot: RepaintKey nicht gesetzt'); return null; }
    for (var attempt = 1; attempt <= 3; attempt++) {
      try {
        final ctx = _repaintKey!.currentContext;
        if (ctx == null) { log('Screenshot: context ist null'); return null; }
        final boundary = ctx.findRenderObject() as RenderRepaintBoundary?;
        if (boundary == null) { log('Screenshot: RenderRepaintBoundary nicht gefunden'); return null; }

        final image = await boundary.toImage(pixelRatio: 2.0);
        final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
        if (byteData == null) { log('Screenshot: byteData ist null'); continue; }

        final dir = await getTemporaryDirectory();
        final file = File('${dir.path}/feedback_${DateTime.now().millisecondsSinceEpoch}.png');
        await file.writeAsBytes(byteData.buffer.asUint8List());
        log('Screenshot gespeichert (${(byteData.lengthInBytes / 1024).round()} KB, Versuch $attempt)');
        return file.path;
      } catch (e) {
        log('Screenshot Versuch $attempt fehlgeschlagen: $e');
        await Future.delayed(const Duration(milliseconds: 100));
      }
    }
    return null;
  }

  // ── Melde-Dialog öffnen ────────────────────────────────────
  static Future<void> showReportDialog(
    BuildContext context, {
    bool isAutoError = false,
  }) async {
    if (_currentScreen.isNotEmpty) {
      log('${isAutoError ? 'Auto-Fehler' : 'Manueller Fehlerbericht'} auf Screen: $_currentScreen');
    }
    await Future.delayed(Duration.zero);
    final screenshotPath = await _captureScreenshot();
    if (!context.mounted) return;
    await showDialog(
      context: context,
      barrierDismissible: !isAutoError,
      builder: (_) => _FeedbackDialog(
        notionAvailable: _notionConfigured,
        isAutoError: isAutoError,
        supportEmail: _supportEmail,
        initialPhotoPaths: screenshotPath != null ? [screenshotPath] : [],
        onSend: (note, photoPaths) => sendReport(
          userNote: note,
          photoPaths: photoPaths,
          forceEmail: isAutoError && !_notionConfigured,
        ),
      ),
    );
  }

  // ── Fehlerbericht senden ───────────────────────────────────
  static Future<bool> sendReport({
    String? userNote,
    List<String>? photoPaths,
    bool forceEmail = false,
  }) async {
    if (_notionConfigured) {
      final ok = await _notionSend(userNote);
      if (ok) return true;
      log('Notion fehlgeschlagen – öffne E-Mail-Fallback');
      return _sendEmailWithAttachments(_buildPlain(userNote), photoPaths ?? []);
    }
    return _sendEmailWithAttachments(_buildPlain(userNote), photoPaths ?? []);
  }

  // ── Notion: Fehlerbericht als Seite anlegen ─────────────────
  static Future<bool> _notionSend(String? userNote) async {
    try {
      final now = DateTime.now();
      String pad(int n) => n.toString().padLeft(2, '0');
      final titel = 'Fehlerbericht ${pad(now.day)}.${pad(now.month)}.${now.year} '
          '${pad(now.hour)}:${pad(now.minute)}';

      final protokoll = _log.join('\n');
      final protokollTrunc = protokoll.length > 1990
          ? '…${protokoll.substring(protokoll.length - 1989)}'
          : protokoll;

      String os = 'Web';
      if (!kIsWeb) {
        try { os = '${Platform.operatingSystem} ${Platform.operatingSystemVersion}'; }
        catch (_) {}
      }

      final props = <String, dynamic>{
        'Titel':      {'title':     [{'text': {'content': titel}}]},
        'Status':     {'select':    {'name': 'Offen'}},
        'App-Version':{'rich_text': [{'text': {'content': 'Build $kBuildNumber'}}]},
        'Protokoll':  {'rich_text': [{'text': {'content': protokollTrunc}}]},
        'OS':         {'rich_text': [{'text': {'content': os}}]},
        'Zeitstempel':{'date':      {'start': now.toIso8601String()}},
      };
      if (userNote != null && userNote.isNotEmpty) {
        final desc = userNote.length > 2000 ? userNote.substring(0, 2000) : userNote;
        props['Beschreibung'] = {'rich_text': [{'text': {'content': desc}}]};
      }

      final res = await http.post(
        Uri.parse('https://api.notion.com/v1/pages'),
        headers: {
          'Authorization': 'Bearer $_notionToken',
          'Notion-Version': '2022-06-28',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'parent': {'database_id': _notionDbId}, 'properties': props}),
      ).timeout(const Duration(seconds: 15));

      log('Notion: ${res.statusCode}');
      return res.statusCode == 200;
    } catch (e) {
      log('Notion Fehler: $e');
      return false;
    }
  }

  // ── E-Mail mit Anhängen öffnen (Android + iOS) ─────────────
  static Future<bool> _sendEmailWithAttachments(
      String body, List<String> attachments) async {
    if (kIsWeb) return _sendEmailFallback(body);
    try {
      final email = Email(
        recipients: [_supportEmail],
        subject: '[Kalender App] Fehlerbericht',
        body: body,
        attachmentPaths: attachments,
      );
      await FlutterEmailSender.send(email);
      log('E-Mail geöffnet (${attachments.length} Anhang/Anhänge)');
      return true;
    } catch (e) {
      log('E-Mail öffnen fehlgeschlagen: $e – versuche Fallback');
      return _sendEmailFallback(body);
    }
  }

  // ── E-Mail-Fallback ohne Anhang (Web / Fehlerfall) ──────────
  static Future<bool> _sendEmailFallback(String body) async {
    final uri = Uri(
      scheme: 'mailto',
      path: _supportEmail,
      queryParameters: {
        'subject': '[Kalender App] Fehlerbericht',
        'body': body,
      },
    );
    try {
      await launchUrl(uri);
      return true;
    } catch (e) {
      log('E-Mail Fallback fehlgeschlagen: $e');
      return false;
    }
  }

  /// Gibt lesbaren Report-Text zurück (für Kopier-Button im Dialog)
  static String buildReportText(String? userNote) => _buildPlain(userNote);

  /// Gibt die aktuellen Log-Einträge zurück (neueste zuletzt)
  static List<String> get logEntries => List.unmodifiable(_log);

  static String _buildHtml(String? userNote) {
    final b = StringBuffer();
    if (userNote != null && userNote.isNotEmpty) {
      b.writeln('<b>🐛 FEHLERBESCHREIBUNG</b>');
      b.writeln(_esc(userNote));
      b.writeln();
    }
    b.writeln('<b>📋 PROTOKOLL</b>');
    if (_log.isEmpty) {
      b.writeln('(keine Einträge)');
    } else {
      for (final e in _log) {
        b.writeln(_esc(e));
      }
    }
    b.writeln();
    b.writeln('<b>📱 SYSTEM</b>');
    b.writeln('Zeit: ${DateTime.now()}');
    if (!kIsWeb) {
      try {
        b.writeln('OS: ${Platform.operatingSystem} ${Platform.operatingSystemVersion}');
      } catch (_) {}
    }
    return b.toString();
  }

  static String _buildPlain(String? userNote) => _buildHtml(userNote)
      .replaceAll('<b>', '')
      .replaceAll('</b>', '')
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>');

  static String _esc(String s) => s
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;');
}

// ═══════════════════════════════════════════════════════════════
//  FEEDBACK DIALOG
// ═══════════════════════════════════════════════════════════════

class _FeedbackDialog extends StatefulWidget {
  final bool notionAvailable;
  final bool isAutoError;
  final String supportEmail;
  final List<String> initialPhotoPaths;
  final Future<bool> Function(String? note, List<String>? photoPaths) onSend;

  const _FeedbackDialog({
    required this.notionAvailable,
    required this.onSend,
    required this.supportEmail,
    this.isAutoError = false,
    this.initialPhotoPaths = const [],
  });

  @override
  State<_FeedbackDialog> createState() => _FeedbackDialogState();
}

class _FeedbackDialogState extends State<_FeedbackDialog> {
  final _controller = TextEditingController();
  late List<String> _photoPaths;
  bool _sending = false;
  bool _logExpanded = false;
  bool _copied = false;

  @override
  void initState() {
    super.initState();
    _photoPaths = List.from(widget.initialPhotoPaths);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picked = await ImagePicker()
          .pickImage(source: source, imageQuality: 80, maxWidth: 1200);
      if (picked != null) setState(() => _photoPaths.add(picked.path));
    } catch (_) {}
  }

  Future<void> _send() async {
    setState(() => _sending = true);
    final note = _controller.text.trim();
    final paths = (!kIsWeb && _photoPaths.isNotEmpty) ? _photoPaths : null;
    final navigator  = Navigator.of(context);
    final messenger  = ScaffoldMessenger.of(context);
    final ok = await widget.onSend(note.isEmpty ? null : note, paths);
    if (!mounted) return;
    navigator.pop();
    messenger.showSnackBar(
      SnackBar(
        content: Text(ok
            ? (widget.notionAvailable
                ? '✓ Fehlerbericht gesendet.'
                : '✓ E-Mail-App geöffnet.')
            : '✗ Senden fehlgeschlagen – Verbindung prüfen.'),
        backgroundColor: ok ? AppColors.started : AppColors.fixedTag,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      title: Row(
        children: [
          Icon(
            widget.isAutoError ? Icons.warning_amber_rounded : Icons.bug_report,
            color: widget.isAutoError ? AppColors.personal : AppColors.vacation,
            size: 20,
          ),
          const SizedBox(width: 8),
          Text(
            widget.isAutoError ? 'Fehler erkannt' : 'Fehler melden',
            style: TextStyle(
              color: widget.isAutoError ? AppColors.personal : AppColors.vacation,
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _InfoBanner(
              notion: widget.notionAvailable,
              hasPhotos: _photoPaths.isNotEmpty,
              isAutoError: widget.isAutoError,
              supportEmail: widget.supportEmail,
            ),
            const SizedBox(height: 12),

            // Screenshots
            Row(
              children: [
                const Text('Screenshots',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                const Spacer(),
                if (!kIsWeb && !widget.isAutoError) ...[
                  _SmallIconBtn(
                    icon: Icons.camera_alt,
                    onTap: () => _pickImage(ImageSource.camera),
                  ),
                  const SizedBox(width: 4),
                  _SmallIconBtn(
                    icon: Icons.photo_library,
                    onTap: () => _pickImage(ImageSource.gallery),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 6),
            if (!kIsWeb && _photoPaths.isNotEmpty)
              SizedBox(
                height: 90,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _photoPaths.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 6),
                  itemBuilder: (_, i) => Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.file(
                          File(_photoPaths[i]),
                          width: 90,
                          height: 90,
                          fit: BoxFit.cover,
                        ),
                      ),
                      Positioned(
                        top: 2,
                        right: 2,
                        child: GestureDetector(
                          onTap: () => setState(() => _photoPaths.removeAt(i)),
                          child: Container(
                            decoration: const BoxDecoration(
                              color: Colors.black54,
                              shape: BoxShape.circle,
                            ),
                            padding: const EdgeInsets.all(3),
                            child: const Icon(Icons.close,
                                color: Colors.white, size: 13),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else if (!kIsWeb)
              Text(
                'Kamera- oder Galerie-Symbol antippen zum Hinzufügen.',
                style: TextStyle(
                    color: AppColors.textDisabled.withValues(alpha: 0.7),
                    fontSize: 11),
              ),
            const SizedBox(height: 12),

            // Fehlerbeschreibung
            const Text('Was ist passiert?',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
            const SizedBox(height: 6),
            TextField(
              controller: _controller,
              maxLines: 3,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: InputDecoration(
                hintText: 'z.B. "Termin lässt sich nicht verschieben"',
                hintStyle: const TextStyle(
                    color: AppColors.textDisabled, fontSize: 12),
                filled: true,
                fillColor: AppColors.background,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: AppColors.divider),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: AppColors.divider),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Protokoll-Anzeige
            GestureDetector(
              onTap: () => setState(() => _logExpanded = !_logExpanded),
              child: Row(children: [
                const Text('📋 Protokoll',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                const Spacer(),
                Icon(
                  _logExpanded ? Icons.expand_less : Icons.expand_more,
                  color: AppColors.textDisabled,
                  size: 18,
                ),
              ]),
            ),
            if (_logExpanded) ...[
              const SizedBox(height: 6),
              Container(
                height: 150,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.divider),
                ),
                child: ListView.builder(
                  itemCount: FeedbackService.logEntries.length,
                  itemBuilder: (_, i) => Text(
                    FeedbackService.logEntries[i],
                    style: const TextStyle(
                        color: AppColors.textDisabled,
                        fontSize: 10,
                        fontFamily: 'monospace'),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 6),
            Row(children: [
              Expanded(
                child: Text(
                  '${FeedbackService.logEntries.length} Einträge · wird automatisch angehängt',
                  style: const TextStyle(color: AppColors.textDisabled, fontSize: 11),
                ),
              ),
              GestureDetector(
                onTap: () async {
                  final text = FeedbackService.buildReportText(
                      _controller.text.trim().isEmpty ? null : _controller.text.trim());
                  await Clipboard.setData(ClipboardData(text: text));
                  if (!mounted) return;
                  setState(() => _copied = true);
                  Future.delayed(const Duration(seconds: 2),
                      () { if (mounted) setState(() => _copied = false); });
                },
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: _copied
                      ? const Row(key: ValueKey('ok'), mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.check, color: AppColors.started, size: 14),
                          SizedBox(width: 4),
                          Text('Kopiert!',
                              style: TextStyle(color: AppColors.started, fontSize: 11)),
                        ])
                      : const Row(key: ValueKey('copy'), mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.copy, color: AppColors.textDisabled, size: 14),
                          SizedBox(width: 4),
                          Text('Kopieren',
                              style: TextStyle(color: AppColors.textDisabled, fontSize: 11)),
                        ]),
                ),
              ),
            ]),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _sending ? null : () => Navigator.pop(context),
          child: const Text('Abbrechen',
              style: TextStyle(color: AppColors.textSecondary)),
        ),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
          ),
          onPressed: _sending ? null : _send,
          icon: _sending
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                )
              : Icon(
                  widget.notionAvailable ? Icons.send : Icons.email,
                  size: 16,
                ),
          label: Text(_sending
              ? 'Sende...'
              : widget.notionAvailable ? 'Senden' : 'Per E-Mail senden'),
        ),
      ],
    );
  }
}

// ── Hilfsmittel ─────────────────────────────────────────────────

class _InfoBanner extends StatelessWidget {
  final bool notion;
  final bool hasPhotos;
  final bool isAutoError;
  final String supportEmail;
  const _InfoBanner({
    required this.notion,
    required this.hasPhotos,
    required this.isAutoError,
    required this.supportEmail,
  });

  @override
  Widget build(BuildContext context) {
    final IconData icon;
    final String text;
    final Color color;
    if (notion) {
      color = AppColors.started;
      icon = Icons.send;
      text = 'Wird direkt aus der App gesendet – kein Login nötig';
    } else if (isAutoError) {
      color = AppColors.personal;
      icon = Icons.email_outlined;
      text = 'Wird per E-Mail gesendet an: $supportEmail';
    } else if (hasPhotos) {
      color = AppColors.work;
      icon = Icons.email_outlined;
      text = 'Öffnet E-Mail-App mit Screenshot als Anhang';
    } else {
      color = AppColors.work;
      icon = Icons.email_outlined;
      text = 'Öffnet deine E-Mail-App – Adresse & Text sind bereits eingetragen';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 6),
          Expanded(
            child: Text(text, style: TextStyle(color: color, fontSize: 11)),
          ),
        ],
      ),
    );
  }
}

class _SmallIconBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _SmallIconBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.black54,
          borderRadius: BorderRadius.circular(6),
        ),
        padding: const EdgeInsets.all(5),
        child: Icon(icon, color: Colors.white, size: 15),
      ),
    );
  }
}

// ── Screen-Observer ─────────────────────────────────────────────
class _ScreenObserver extends NavigatorObserver {
  static String? _routeName(Route route) {
    final name = route.settings.name;
    if (name != null && name.isNotEmpty) return name;
    return null;
  }

  @override
  void didPush(Route route, Route? previousRoute) {
    final name = _routeName(route);
    if (name != null) FeedbackService.setCurrentScreen(name);
  }

  @override
  void didPop(Route route, Route? previousRoute) {
    final name = previousRoute != null ? _routeName(previousRoute) : null;
    if (name != null) FeedbackService.setCurrentScreen(name);
  }

  @override
  void didReplace({Route? newRoute, Route? oldRoute}) {
    final name = newRoute != null ? _routeName(newRoute) : null;
    if (name != null) FeedbackService.setCurrentScreen(name);
  }
}
