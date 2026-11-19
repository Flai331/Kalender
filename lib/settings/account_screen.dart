import 'package:flutter/material.dart';

import '../app_colors.dart';
import '../services/auth_service.dart';
import '../services/local_service.dart';
import '../services/sync_service.dart';
import '../supabase_config.dart';
import '../widgets/save_feedback.dart';

/// Das Konto an eine E-Mail-Adresse binden — und auf einem neuen Geraet
/// wieder daran kommen.
///
/// Ohne hinterlegte Adresse ist das Konto eine anonyme Sitzung, die nur in
/// dieser Installation lebt. Neues Handy, neu installierte App, geleerter
/// App-Speicher: die Kennung ist weg, und mit ihr der Zugang zu allem, was
/// unter ihr in Supabase liegt. Die Daten stehen dort weiter, nur kommt
/// niemand mehr an sie.
class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  final _bindEmail = TextEditingController();
  final _bindPassword = TextEditingController();
  final _bindRepeat = TextEditingController();
  final _loginEmail = TextEditingController();
  final _loginPassword = TextEditingController();
  final _newPassword = TextEditingController();

  bool _busy = false;
  bool _signedInAgain = false;

  @override
  void dispose() {
    _bindEmail.dispose();
    _bindPassword.dispose();
    _bindRepeat.dispose();
    _loginEmail.dispose();
    _loginPassword.dispose();
    _newPassword.dispose();
    super.dispose();
  }

  // ── Adresse hinterlegen ───────────────────────────────────────────────────

  Future<void> _bind() async {
    final address = _bindEmail.text.trim();
    final password = _bindPassword.text;

    if (!AuthService.looksLikeEmail(address)) {
      showInfoSnack(context, 'Das sieht nicht wie eine E-Mail-Adresse aus.');
      return;
    }
    if (password.length < AuthService.minPasswordLength) {
      showInfoSnack(context,
          'Das Passwort braucht mindestens ${AuthService.minPasswordLength} Zeichen.');
      return;
    }
    if (password != _bindRepeat.text) {
      showInfoSnack(context, 'Die beiden Passwörter sind nicht gleich.');
      return;
    }

    setState(() => _busy = true);
    try {
      await AuthService.bindEmail(address, password);
      if (!mounted) return;
      _bindPassword.clear();
      _bindRepeat.clear();
      showInfoSnack(context,
          'Bestätigungsmail an $address verschickt. Klick den Link darin.');
    } catch (e) {
      if (!mounted) return;
      showErrorSnack(context, 'Hat nicht geklappt: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _refresh() async {
    setState(() => _busy = true);
    try {
      await AuthService.refresh();
      if (!mounted) return;
      showInfoSnack(
          context,
          AuthService.hasEmail
              ? 'Bestätigt — dein Konto hängt jetzt an ${AuthService.email}.'
              : 'Noch nicht bestätigt. Der Link in der Mail fehlt noch.');
    } catch (e) {
      if (!mounted) return;
      showErrorSnack(context, 'Abfrage fehlgeschlagen: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _changePassword() async {
    final password = _newPassword.text;
    if (password.length < AuthService.minPasswordLength) {
      showInfoSnack(context,
          'Das Passwort braucht mindestens ${AuthService.minPasswordLength} Zeichen.');
      return;
    }
    setState(() => _busy = true);
    try {
      await AuthService.setPassword(password);
      if (!mounted) return;
      _newPassword.clear();
      showInfoSnack(context, 'Passwort geändert.');
    } catch (e) {
      if (!mounted) return;
      showErrorSnack(context, 'Hat nicht geklappt: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // ── Auf einem neuen Geraet anmelden ───────────────────────────────────────

  Future<void> _login() async {
    final address = _loginEmail.text.trim();
    final password = _loginPassword.text;

    if (!AuthService.looksLikeEmail(address) || password.isEmpty) {
      showInfoSnack(context, 'Adresse und Passwort eintragen.');
      return;
    }

    // Wartende Auftraege gehoeren zum jetzigen Konto. Nach dem Wechsel wuerden
    // sie unter der neuen Kennung hochgeladen und landeten im falschen Konto.
    final pending = await LocalService.getPendingQueue();
    if (!mounted) return;
    if (pending.isNotEmpty) {
      showInfoSnack(
          context,
          '${pending.length} Änderungen sind noch nicht hochgeladen. '
          'Erst online gehen und synchronisieren.');
      return;
    }

    final ok = await _confirmSwitch();
    if (ok != true || !mounted) return;

    setState(() => _busy = true);
    try {
      await AuthService.signInWithPassword(address, password);
      // Der Zwischenspeicher gehoert jetzt zum falschen Konto: unter der neuen
      // Kennung liegt lokal nichts. Ohne dieses Laden stuende die App leer da.
      await SyncService.seedFromServer(force: true);
      if (!mounted) return;
      _loginPassword.clear();
      setState(() => _signedInAgain = true);
    } catch (e) {
      if (!mounted) return;
      showErrorSnack(context, 'Anmeldung fehlgeschlagen: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<bool?> _confirmSwitch() {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Konto wechseln?',
            style: TextStyle(color: AppColors.textPrimary)),
        content: const Text(
            'Die App zeigt danach die Daten des angemeldeten Kontos. Was '
            'jetzt auf diesem Gerät liegt, bleibt gespeichert, ist aber nicht '
            'mehr zu sehen.\n\nSinnvoll auf einem neuen oder neu '
            'aufgesetzten Gerät — nicht auf dem, auf dem du arbeitest.',
            style: TextStyle(color: AppColors.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Abbrechen',
                style: TextStyle(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Anmelden',
                style: TextStyle(
                    color: AppColors.primary, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // ── Aufbau ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
        title: const Text('Konto',
            style: TextStyle(
                color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
      ),
      body: !SupabaseConfig.isConfigured
          ? const _Hinweis(
              icon: Icons.cloud_off,
              color: AppColors.textDisabled,
              title: 'Keine Cloud eingerichtet',
              text: 'Ohne Supabase-Zugang gibt es kein Konto. Die App '
                  'speichert dann nur auf diesem Gerät.',
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _zustand(),
                const SizedBox(height: 16),
                if (_signedInAgain) ...[
                  const _Hinweis(
                    icon: Icons.restart_alt,
                    color: AppColors.started,
                    title: 'Angemeldet',
                    text: 'Deine Daten sind geladen. Schließe die App einmal '
                        'ganz und öffne sie neu, damit überall der neue Stand '
                        'steht.',
                  ),
                  const SizedBox(height: 16),
                ],
                if (!AuthService.hasEmail) _hinterlegen(),
                if (AuthService.hasEmail) _passwortAendern(),
                const SizedBox(height: 16),
                _anmelden(),
                const SizedBox(height: 24),
                _kennung(),
              ],
            ),
    );
  }

  Widget _zustand() {
    if (AuthService.hasEmail) {
      return _Hinweis(
        icon: Icons.verified_user_outlined,
        color: AppColors.started,
        title: 'Gesichert',
        text: 'Dein Konto hängt an ${AuthService.email}. Auf einem neuen '
            'Gerät meldest du dich damit an und hast alles zurück.',
      );
    }
    final pending = AuthService.pendingEmail;
    if (pending != null) {
      return _Karte(children: [
        const _Kopf(
          icon: Icons.mark_email_unread_outlined,
          color: AppColors.paused,
          title: 'Bestätigung offen',
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Text(
              'An $pending ist eine Mail unterwegs. Erst mit dem Klick auf '
              'den Link darin gilt die Adresse — bis dahin hängt dein Konto '
              'weiter allein an diesem Gerät.',
              style: const TextStyle(
                  color: AppColors.textSecondary, fontSize: 13)),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
          child: Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: _busy ? null : _refresh,
              child: const Text('Habe bestätigt',
                  style: TextStyle(
                      color: AppColors.primary, fontWeight: FontWeight.bold)),
            ),
          ),
        ),
      ]);
    }
    return const _Hinweis(
      icon: Icons.warning_amber_rounded,
      color: AppColors.personal,
      title: 'Nur auf diesem Gerät',
      text: 'Dein Konto ist eine anonyme Sitzung — sie lebt allein in dieser '
          'Installation. Neues Handy, neu installierte App oder geleerter '
          'App-Speicher: die Kennung ist weg. Deine Daten bleiben in der '
          'Cloud liegen, aber niemand kommt mehr an sie heran.',
    );
  }

  Widget _hinterlegen() {
    return _Karte(children: [
      const _Kopf(
          icon: Icons.alternate_email,
          color: AppColors.primary,
          title: 'E-Mail hinterlegen'),
      const Padding(
        padding: EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: Text(
            'Dasselbe Konto, dieselben Daten — es bekommt nur einen Namen, '
            'unter dem du es wiederfindest. Du musst dich danach nicht '
            'anmelden; es bleibt alles, wie es ist.',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
      ),
      _feld(_bindEmail, 'E-Mail', keyboard: TextInputType.emailAddress),
      _feld(_bindPassword, 'Passwort', obscure: true),
      _feld(_bindRepeat, 'Passwort wiederholen', obscure: true),
      _knopf('Hinterlegen', _bind),
    ]);
  }

  Widget _passwortAendern() {
    return _Karte(children: [
      const _Kopf(
          icon: Icons.password,
          color: AppColors.primary,
          title: 'Passwort ändern'),
      _feld(_newPassword, 'Neues Passwort', obscure: true),
      _knopf('Ändern', _changePassword),
    ]);
  }

  Widget _anmelden() {
    return _Karte(children: [
      const _Kopf(
          icon: Icons.login,
          color: AppColors.accent,
          title: 'Auf diesem Gerät anmelden'),
      const Padding(
        padding: EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: Text(
            'Nach einer Neuinstallation: hier anmelden, dann holt die App '
            'deine Daten zurück.',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
      ),
      _feld(_loginEmail, 'E-Mail', keyboard: TextInputType.emailAddress),
      _feld(_loginPassword, 'Passwort', obscure: true),
      _knopf('Anmelden', _login, color: AppColors.accent),
    ]);
  }

  Widget _kennung() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Text('Kennung: ${AuthService.userId ?? 'nicht angemeldet'}',
          style: const TextStyle(color: AppColors.textDisabled, fontSize: 11)),
    );
  }

  Widget _feld(TextEditingController c, String label,
      {bool obscure = false, TextInputType? keyboard}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: TextField(
        controller: c,
        obscureText: obscure,
        keyboardType: keyboard,
        enabled: !_busy,
        autocorrect: false,
        enableSuggestions: false,
        style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
        decoration: InputDecoration(
          labelText: label,
          labelStyle:
              const TextStyle(color: AppColors.textSecondary, fontSize: 13),
          filled: true,
          fillColor: AppColors.background,
          border: const OutlineInputBorder(),
          enabledBorder: const OutlineInputBorder(
              borderSide: BorderSide(color: AppColors.divider)),
          focusedBorder: const OutlineInputBorder(
              borderSide: BorderSide(color: AppColors.primary)),
          isDense: true,
        ),
      ),
    );
  }

  Widget _knopf(String label, Future<void> Function() action, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: SizedBox(
        width: double.infinity,
        child: FilledButton(
          style: FilledButton.styleFrom(
              backgroundColor: color ?? AppColors.primary,
              foregroundColor: Colors.white),
          onPressed: _busy ? null : () => action(),
          child: _busy
              ? const SizedBox(
                  height: 16,
                  width: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
              : Text(label,
                  style: const TextStyle(fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }
}

class _Karte extends StatelessWidget {
  final List<Widget> children;
  const _Karte({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
          color: AppColors.surface, borderRadius: BorderRadius.circular(12)),
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start, children: children),
    );
  }
}

class _Kopf extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  const _Kopf({required this.icon, required this.color, required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
      child: Row(children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 10),
        Text(title,
            style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.bold)),
      ]),
    );
  }
}

class _Hinweis extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String text;
  const _Hinweis(
      {required this.icon,
      required this.color,
      required this.title,
      required this.text});

  @override
  Widget build(BuildContext context) {
    return _Karte(children: [
      _Kopf(icon: icon, color: color, title: title),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
        child: Text(text,
            style:
                const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
      ),
    ]);
  }
}
