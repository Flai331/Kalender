import 'package:flutter/material.dart';
import '../app_colors.dart';
import '../services/feedback_service.dart';
import '../services/offline_error.dart';

export '../services/offline_error.dart' show isOfflineError;

/// Zeigt eine Fehlermeldung als SnackBar.
void showErrorSnack(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(message, style: const TextStyle(color: Colors.white)),
      backgroundColor: AppColors.fixedTag,
      duration: const Duration(seconds: 5),
    ));
}

/// Zeigt einen Hinweis (z.B. fehlende Pflichtangabe) als SnackBar.
void showInfoSnack(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(message, style: const TextStyle(color: Colors.white)),
      backgroundColor: AppColors.card,
      duration: const Duration(seconds: 3),
    ));
}

/// Führt [action] aus und macht Fehler für den Nutzer sichtbar.
///
/// Ohne diesen Guard bleibt eine geworfene Exception unsichtbar: der Screen
/// bleibt offen, es erscheint keine Meldung, und ein vor dem `await` gesetztes
/// `_saving`-Flag wird nie zurückgesetzt — der Speichern-Knopf reagiert danach
/// gar nicht mehr.
///
/// Gibt `true` zurück, wenn [action] ohne Fehler durchgelaufen ist.
Future<bool> guardedAction(
  BuildContext context,
  Future<void> Function() action, {
  String offlineMessage = 'Kein Internet – konnte nicht gespeichert werden. '
      'Bitte später erneut versuchen.',
  String errorPrefix = 'Speichern fehlgeschlagen',
}) async {
  try {
    await action();
    return true;
  } catch (e) {
    FeedbackService.log('$errorPrefix: $e');
    if (context.mounted) {
      showErrorSnack(
        context,
        isOfflineError(e) ? offlineMessage : '$errorPrefix: $e',
      );
    }
    return false;
  }
}
