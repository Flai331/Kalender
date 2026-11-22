import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:shared_preferences/shared_preferences.dart';
import '../app_colors.dart';
import '../models/reminder_urgency.dart';
import '../services/category_service.dart';
import '../services/departure_reminder_service.dart';
import 'categories_screen.dart';
import '../places/places_screen.dart';
import '../services/place_reminder_service.dart';
import '../services/place_service.dart';
import '../models/ics_source.dart';
import '../services/backup_service.dart';
import '../services/daylight_service.dart';
import '../services/feedback_service.dart';
import '../services/ics_service.dart';
import '../services/reminder_service.dart';
import '../services/travel_service.dart';
import '../models/travel_times.dart';
import '../services/update_service.dart';
import '../widgets/save_feedback.dart';
import '../widgets/feedback_button.dart';
import '../widgets/travel_time_picker.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _checkingUpdate = false;
  double? _updateProgress; // null = laeuft nicht, sonst 0..1
  List<IcsSource> _sources = [];
  bool _sourcesLoading = true;
  bool _outlookAllowTodoDrop = false;
  bool _backupLaeuft = false;
  List<AutoSicherung> _autoStaende = [];
  DateTime? _letzteManuelle;
  String _orteZeile = 'Wird geladen …';
  int _vorlaufMinuten = PlaceReminderService.defaultLeadMinutes;

  bool _abfahrtAn = true;
  int _abfahrtVorlauf = DepartureReminderService.defaultLeadMinutes;
  ReminderUrgency _abfahrtStufe = DepartureReminderService.defaultUrgency;

  List<String> _blockingAllDayCats = ['vacation'];
  int _daylightSunrise = 6;
  int _daylightSunset = 20;

  @override
  void initState() {
    super.initState();
    _loadSources();
    _loadConstraintSettings();
    _loadBackupInfo();
    _ladeOrteZeile();
    _ladeAbfahrt();
    // Echten versionCode holen, statt der beim Bauen eingetragenen Konstante.
    UpdateService.refreshInstalledBuild().then((_) {
      if (mounted) setState(() {});
    });
  }

  Future<void> _loadBackupInfo() async {
    // Nur eine Anzeige: laesst sich der Ordner nicht lesen, bleibt die Zeile
    // leer, statt den ganzen Bildschirm zu verhindern.
    List<AutoSicherung> staende = [];
    DateTime? manuell;
    try {
      staende = await BackupService.autoSicherungen();
      manuell = await BackupService.letzteManuelle();
    } catch (_) {
      staende = [];
    }
    if (mounted) {
      setState(() {
        _autoStaende = staende;
        _letzteManuelle = manuell;
      });
    }
  }

  /// Eine Zeile darueber, wie es um die automatischen Staende steht.
  String _autoInfo() {
    if (_autoStaende.isEmpty) {
      return 'Die App legt beim Start täglich einen Stand ab';
    }
    final anzahl = _autoStaende.length;
    return 'Letzter Stand ${_autoStaende.first.datumKurz} · '
        '$anzahl ${anzahl == 1 ? 'Stand' : 'Stände'} in der App';
  }

  /// Und eine darueber, wann zuletzt eine Datei das Geraet verlassen hat.
  String _manuellInfo() {
    final letzte = _letzteManuelle;
    if (letzte == null) {
      return 'Noch nie — mit dem Gerät wäre alles weg';
    }
    final tage = DateTime.now().difference(letzte).inDays;
    final wann = '${letzte.day}.${letzte.month}.${letzte.year}';
    return tage > 30 ? 'Zuletzt $wann, also $tage Tage her' : 'Zuletzt $wann';
  }

  Future<void> _loadSources() async {
    final sources = await IcsService.getSources();
    final outlook = await IcsService.getOutlookAllowTodoDrop();
    if (mounted) {
      setState(() {
        _sources = sources;
        _sourcesLoading = false;
        _outlookAllowTodoDrop = outlook;
      });
    }
  }

  Future<void> _setCalendarTravel(String calendarId, TravelTimes times) async {
    await TravelService.setCalendarTimes(calendarId, times);
    if (mounted) setState(() {});
  }

  /// Eine Zeile je Kalender: Name und die beiden Vorgaben.
  ///
  /// Über einer Kalender-Vorgabe steht nichts mehr, deshalb heißt der leere
  /// Zustand hier „Keine Vorgabe" und nicht „Vorgabe".
  Widget _travelTile(String calendarId, String name, IconData icon) {
    final t = TravelService.calendarTimes(calendarId);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: AppColors.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(name,
                    style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TravelTimePicker(
            label: 'Anfahrt',
            minutes: t.before,
            inheritLabel: 'Keine Vorgabe',
            onChanged: (v) =>
                _setCalendarTravel(calendarId, t.copyWith(before: v)),
          ),
          const SizedBox(height: 6),
          TravelTimePicker(
            label: 'Abfahrt',
            minutes: t.after,
            inheritLabel: 'Keine Vorgabe',
            onChanged: (v) =>
                _setCalendarTravel(calendarId, t.copyWith(after: v)),
          ),
        ],
      ),
    );
  }

  Future<void> _createBackup() async {
    setState(() => _backupLaeuft = true);
    try {
      final pfad = await BackupService.saveToFile();
      if (!mounted) return;
      showInfoSnack(
          context,
          pfad == null
              ? 'Abgebrochen — es wurde nichts geschrieben.'
              : 'Sicherung gespeichert.');
      await _loadBackupInfo();
    } catch (e) {
      if (!mounted) return;
      showErrorSnack(context, 'Sicherung fehlgeschlagen: $e');
    } finally {
      if (mounted) setState(() => _backupLaeuft = false);
    }
  }

  Future<void> _restoreBackup() async {
    Map<String, dynamic>? daten;
    try {
      daten = await BackupService.pickFile();
    } on BackupFehler catch (e) {
      if (!mounted) return;
      showErrorSnack(context, e.nachricht);
      return;
    } catch (e) {
      if (!mounted) return;
      showErrorSnack(context, 'Die Datei liess sich nicht lesen: $e');
      return;
    }
    if (daten == null || !mounted) return;
    await _applyRestore(daten);
  }

  /// Zeigt die automatischen Staende und spielt den gewaehlten ein.
  Future<void> _showAutoBackups() async {
    List<AutoSicherung> staende;
    try {
      staende = await BackupService.autoSicherungen();
    } catch (e) {
      if (!mounted) return;
      showErrorSnack(context, 'Die Stände liessen sich nicht lesen: $e');
      return;
    }
    if (!mounted) return;
    if (staende.isEmpty) {
      showInfoSnack(context,
          'Noch kein automatischer Stand — der erste entsteht beim nächsten Start der App.');
      return;
    }
    final gewaehlt = await showDialog<AutoSicherung>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Automatische Stände',
            style: TextStyle(color: AppColors.textPrimary, fontSize: 15)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
                'Die App behält die letzten ${BackupService.behalten} Stände. '
                'Sie liegen im Speicher der App — mit dem Gerät sind auch sie weg.',
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 12)),
            const SizedBox(height: 8),
            for (final stand in staende)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.history,
                    color: AppColors.textSecondary, size: 20),
                title: Text(stand.datumKurz,
                    style: const TextStyle(
                        color: AppColors.textPrimary, fontSize: 14)),
                subtitle: Text(stand.groesseKurz,
                    style: const TextStyle(
                        color: AppColors.textSecondary, fontSize: 11)),
                onTap: () => Navigator.pop(ctx, stand),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Abbrechen',
                style: TextStyle(color: AppColors.textSecondary)),
          ),
        ],
      ),
    );
    if (gewaehlt == null || !mounted) return;

    Map<String, dynamic> daten;
    try {
      daten = await BackupService.leseStand(gewaehlt.pfad);
    } on BackupFehler catch (e) {
      if (!mounted) return;
      showErrorSnack(context, e.nachricht);
      return;
    } catch (e) {
      if (!mounted) return;
      showErrorSnack(context, 'Der Stand liess sich nicht lesen: $e');
      return;
    }
    if (!mounted) return;
    await _applyRestore(daten);
  }

  /// Rueckfrage und Einspielen — egal, woher die Daten kommen.
  Future<void> _applyRestore(Map<String, dynamic> daten) async {
    final inhalt = BackupService.summarize(daten);
    final ok = await _confirmRestore(inhalt);
    if (ok != true || !mounted) return;

    setState(() => _backupLaeuft = true);
    try {
      await BackupService.restore(daten);
      if (!mounted) return;
      await _loadConstraintSettings();
      await _loadSources();
      if (!mounted) return;
      showInfoSnack(
          context,
          'Eingespielt. Schließe die App einmal ganz und öffne sie neu, '
          'damit überall der neue Stand steht.');
    } catch (e) {
      if (!mounted) return;
      showErrorSnack(context, 'Einspielen fehlgeschlagen: $e');
    } finally {
      if (mounted) setState(() => _backupLaeuft = false);
    }
  }

  Future<bool?> _confirmRestore(BackupSummary inhalt) {
    final erstellt = inhalt.erstellt;
    final wann = erstellt == null
        ? 'ohne Datum'
        : 'vom ${erstellt.day}.${erstellt.month}.${erstellt.year}';
    final zeilen = inhalt.zeilen;
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Sicherung einspielen?',
            style: TextStyle(color: AppColors.textPrimary)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Die Sicherung $wann enthält:',
                style: const TextStyle(color: AppColors.textSecondary)),
            const SizedBox(height: 8),
            if (zeilen.isEmpty)
              const Text('— nichts. Die Datei ist leer.',
                  style: TextStyle(color: AppColors.fixedTag))
            else
              ...zeilen.map((z) => Text('• $z',
                  style: const TextStyle(color: AppColors.textPrimary))),
            const SizedBox(height: 12),
            const Text(
                'Alles, was jetzt auf diesem Gerät steht, wird dadurch '
                'ersetzt — nicht ergänzt.',
                style: TextStyle(color: AppColors.fixedTag, fontSize: 13)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Abbrechen',
                style: TextStyle(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Einspielen',
                style: TextStyle(
                    color: AppColors.fixedTag, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _openPlaces() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const PlacesScreen()),
    );
    if (!mounted) return;
    await _ladeOrteZeile();
  }

  /// Die Unterzeile sagt, was eingetragen ist — sonst weiss man nicht, ob
  /// sich das Oeffnen lohnt.
  Future<void> _ladeOrteZeile() async {
    final orte = await PlaceService.all();
    final vorlauf = await PlaceReminderService.leadMinutes();
    if (!mounted) return;
    setState(() {
      _vorlaufMinuten = vorlauf;
      if (orte.isEmpty) {
        _orteZeile = 'Noch keine Orte';
        return;
      }
      final gruppen = orte.map((p) => p.group).toSet().length;
      _orteZeile = '${orte.length} ${orte.length == 1 ? "Ort" : "Orte"} '
          'in $gruppen ${gruppen == 1 ? "Gruppe" : "Gruppen"}';
    });
  }

  // ── Ans Losfahren erinnern ────────────────────────────────────────────────

  Future<void> _ladeAbfahrt() async {
    final an = await DepartureReminderService.istAn();
    final vorlauf = await DepartureReminderService.leadMinutes();
    final stufe = await DepartureReminderService.urgency();
    if (!mounted) return;
    setState(() {
      _abfahrtAn = an;
      _abfahrtVorlauf = vorlauf;
      _abfahrtStufe = stufe;
    });
  }

  /// Den Messenger vor dem Warten holen: danach ist der Context vielleicht
  /// nicht mehr da.
  void _gespeichert() {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(
        content: Text('Gespeichert.', style: TextStyle(color: Colors.white)),
        backgroundColor: AppColors.card,
        duration: Duration(seconds: 2),
      ));
  }

  Widget _abfahrtZeile(String titel, Widget auswahl) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        child: Row(
          children: [
            Expanded(
              child: Text(titel,
                  style: const TextStyle(color: AppColors.textPrimary)),
            ),
            auswahl,
          ],
        ),
      );

  Future<void> _openCategories() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CategoriesScreen()),
    );
    if (!mounted) return;
    // Eine geloeschte Kategorie kann die blockierenden Ganztags-Kategorien
    // veraendert haben.
    await _loadConstraintSettings();
    if (mounted) setState(() {});
  }

  Future<void> _loadConstraintSettings() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _blockingAllDayCats =
          prefs.getStringList('blocking_allday_cats') ?? ['vacation'];
      _daylightSunrise = prefs.getInt('daylight_sunrise') ?? 6;
      _daylightSunset = prefs.getInt('daylight_sunset') ?? 20;
    });
  }

  Future<void> _saveBlockingCats() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('blocking_allday_cats', _blockingAllDayCats);
  }

  Future<void> _toggleIcsAllowTodoDrop(IcsSource src, bool value) async {
    final sources = await IcsService.getSources();
    final updated = sources.map((s) =>
        s.id == src.id ? s.copyWith(allowTodoDrop: value) : s).toList();
    await IcsService.saveSources(updated);
    await _loadSources();
  }

  /// Ein ganzer Kalender nur zur Kenntnis — der Dienstplan eines anderen
  /// Menschen. Die Termine daraus werden angezeigt, belegen aber keine Zeit.
  Future<void> _toggleIcsInfoOnly(IcsSource src, bool value) async {
    final sources = await IcsService.getSources();
    final updated = sources
        .map((s) => s.id == src.id ? s.copyWith(infoOnly: value) : s)
        .toList();
    await IcsService.saveSources(updated);
    await _loadSources();
  }

  Future<void> _toggleOutlookAllowTodoDrop(bool value) async {
    await IcsService.setOutlookAllowTodoDrop(value);
    setState(() => _outlookAllowTodoDrop = value);
  }

  Future<void> _addUrl() async {
    final nameCtrl = TextEditingController();
    final urlCtrl = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('URL hinzufügen',
            style: TextStyle(color: AppColors.textPrimary)),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
                decoration: _inputDeco('Name (z.B. Outlook)'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: urlCtrl,
                style: const TextStyle(color: AppColors.textPrimary, fontSize: 12),
                decoration: _inputDeco('webcal://outlook.live.com/...'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Abbrechen',
                style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white),
            child: const Text('Hinzufügen'),
          ),
        ],
      ),
    );
    if (result != true) return;
    final url = urlCtrl.text.trim();
    if (url.isEmpty) return;
    setState(() => _sourcesLoading = true);
    await IcsService.addUrl(url, nameCtrl.text.trim());
    await _loadSources();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Kalender hinzugefügt'),
            backgroundColor: AppColors.started),
      );
    }
  }

  Future<void> _addFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['ics'],
    );
    if (result == null || result.files.isEmpty) return;
    final path = result.files.single.path;
    if (path == null) return;
    if (!mounted) return;

    final nameCtrl = TextEditingController(
        text: result.files.single.name.replaceAll('.ics', ''));
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Datei hinzufügen',
            style: TextStyle(color: AppColors.textPrimary)),
        content: SizedBox(
          width: double.maxFinite,
          child: TextField(
            controller: nameCtrl,
            style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
            decoration: _inputDeco('Name'),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Abbrechen',
                style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white),
            child: const Text('Hinzufügen'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _sourcesLoading = true);
    await IcsService.addFile(path, nameCtrl.text.trim());
    await _loadSources();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ICS-Datei hinzugefügt'),
            backgroundColor: AppColors.started),
      );
    }
  }

  static const List<int> _presetColors = [
    0xFF6C63FF, 0xFF448AFF, 0xFF00BCD4, 0xFF4CAF50,
    0xFF8BC34A, 0xFFFFD740, 0xFFFF9800, 0xFFFF5252,
    0xFFE040FB, 0xFFFF4081, 0xFF795548, 0xFF607D8B,
  ];

  /// Alles, was zu einem Kalender einstellbar ist. Das Ein- und Ausblenden
  /// sitzt als Schalter in der Zeile selbst — das ist das, was man dort
  /// erwartet.
  Future<void> _openCalendarOptions(IcsSource src) async {
    var aktuell = src;
    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          backgroundColor: AppColors.surface,
          title: Text(aktuell.name,
              style:
                  const TextStyle(color: AppColors.textPrimary, fontSize: 15)),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Farbe im Kalender',
                    style:
                        TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    for (final c in _presetColors)
                      GestureDetector(
                        onTap: () async {
                          await _setColor(aktuell, c);
                          setLocal(() => aktuell = aktuell.copyWith(color: c));
                        },
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: Color(c),
                            shape: BoxShape.circle,
                            border: aktuell.color == c
                                ? Border.all(color: Colors.white, width: 2.5)
                                : null,
                          ),
                        ),
                      ),
                  ],
                ),
                const Divider(height: 26, color: AppColors.background),
                Row(
                  children: [
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Todos hineinziehen',
                              style: TextStyle(
                                  color: AppColors.textPrimary, fontSize: 13)),
                          Text(
                              'To-dos lassen sich auf Termine dieses Kalenders ziehen',
                              style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 11)),
                        ],
                      ),
                    ),
                    Switch(
                      value: aktuell.allowTodoDrop,
                      activeThumbColor: AppColors.primary,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      onChanged: (v) async {
                        await _toggleIcsAllowTodoDrop(aktuell, v);
                        setLocal(() =>
                            aktuell = aktuell.copyWith(allowTodoDrop: v));
                      },
                    ),
                  ],
                ),
                const Divider(height: 26, color: AppColors.background),
                Row(
                  children: [
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Nur zur Info',
                              style: TextStyle(
                                  color: AppColors.textPrimary, fontSize: 13)),
                          Text(
                              'Dienstplan eines anderen Menschen: wird '
                              'angezeigt, belegt aber keine Zeit und '
                              'verhindert kein To-do',
                              style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 11)),
                        ],
                      ),
                    ),
                    Switch(
                      value: aktuell.infoOnly,
                      activeThumbColor: AppColors.primary,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      onChanged: (v) async {
                        await _toggleIcsInfoOnly(aktuell, v);
                        setLocal(
                            () => aktuell = aktuell.copyWith(infoOnly: v));
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () async {
                await _setColor(aktuell, null);
                setLocal(() => aktuell = aktuell.copyWith(clearColor: true));
              },
              child: const Text('Standardfarbe',
                  style: TextStyle(color: AppColors.textSecondary)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Fertig',
                  style: TextStyle(color: AppColors.primary)),
            ),
          ],
        ),
      ),
    );
  }

  /// Setzt die Farbe eines Kalenders; null nimmt die eigene Farbe weg.
  Future<void> _setColor(IcsSource src, int? farbe) async {
    final sources = await IcsService.getSources();
    final updated = sources
        .map((s) => s.id != src.id
            ? s
            : (farbe == null
                ? s.copyWith(clearColor: true)
                : s.copyWith(color: farbe)))
        .toList();
    await IcsService.saveSources(updated);
    await _loadSources();
  }

  /// Blendet einen Kalender aus oder wieder ein. Der Eintrag bleibt stehen.
  Future<void> _toggleIcsVisible(IcsSource src, bool value) async {
    final sources = await IcsService.getSources();
    final updated = sources
        .map((s) => s.id == src.id ? s.copyWith(visible: value) : s)
        .toList();
    await IcsService.saveSources(updated);
    await _loadSources();
  }

  Future<void> _removeSource(String id) async {
    await IcsService.removeSource(id);
    await _loadSources();
  }

  InputDecoration _inputDeco(String hint) => InputDecoration(
        hintText: hint,
        hintStyle:
            const TextStyle(color: AppColors.textDisabled, fontSize: 12),
        filled: true,
        fillColor: AppColors.background,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
      );

  /// Zwei Meldungen, und das mit Absicht.
  ///
  /// Die sofortige sagt nur: die App darf überhaupt melden. Die geplante geht
  /// den Weg, den jede echte Erinnerung geht — Wecker über den AlarmManager,
  /// Empfänger, Kanal. Kommt die erste und die zweite nicht, liegt es nicht
  /// am Recht, sondern am Wecker.
  Future<void> _testNotification() async {
    await ReminderService.showTestNotification(
      'Test-Erinnerung',
      'Die App darf melden. Gleich kommt die zweite.',
    );
    await DepartureReminderService.probeStellen(_abfahrtStufe);
    if (!mounted) return;
    showInfoSnack(
        context,
        'Die zweite Meldung kommt in 15 Sekunden — die ist der eigentliche '
        'Test.');
  }

  // ── Update-Prüfung ────────────────────────────────────────────
  Future<void> _checkForUpdate() async {
    if (_checkingUpdate) return;
    setState(() => _checkingUpdate = true);
    UpdateCheckResult result;
    try {
      result = await UpdateService.check();
    } finally {
      // Auch im Fehlerfall zurücksetzen, sonst bleibt der Knopf blockiert.
      if (mounted) setState(() => _checkingUpdate = false);
    }
    if (!mounted) return;

    switch (result.status) {
      case UpdateStatus.fehler:
        showErrorSnack(
            context, result.message ?? 'Update-Prüfung fehlgeschlagen.');
      case UpdateStatus.aktuell:
        showInfoSnack(context,
            'Du hast die neueste Version (Build ${UpdateService.installedBuild}).');
      case UpdateStatus.verfuegbar:
        await _showUpdateDialog(result.release!);
    }
  }

  Future<void> _showUpdateDialog(ReleaseInfo release) async {
    final kanal = release.channel == 'vorschau' ? 'Vorschau' : 'Aktuell';
    final laden = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Update verfügbar',
            style: TextStyle(color: AppColors.textPrimary)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Build ${release.buildNumber} statt ${UpdateService.installedBuild}',
              style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              'Kanal: $kanal'
              '${release.branch.isNotEmpty ? '\nBranch: ${release.branch}' : ''}'
              '${release.commit.isNotEmpty ? '\nCommit: ${release.commit}' : ''}',
              style: const TextStyle(
                  color: AppColors.textSecondary, fontSize: 12),
            ),
            const SizedBox(height: 12),
            const Text(
              'Die App lädt das Update selbst und öffnet danach die '
              'Installation. Deine Daten bleiben erhalten.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Später',
                style: TextStyle(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Jetzt aktualisieren',
                style: TextStyle(
                    color: AppColors.primary, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
    if (laden != true || !mounted) return;
    await _downloadAndInstall(release);
  }

  /// Lädt die APK und übergibt sie dem Installer — wie in RHS Einsatz.
  ///
  /// Android zeigt am Ende immer sein eigenes Installationsfenster; eine App
  /// ohne Systemrechte kann sich nicht still selbst installieren.
  Future<void> _downloadAndInstall(ReleaseInfo release) async {
    setState(() => _updateProgress = 0);
    String? pfad;
    try {
      pfad = await UpdateService.downloadApk(
        release,
        onProgress: (received, total) {
          if (!mounted || total == null || total <= 0) return;
          final anteil = received / total;
          // Nur bei sichtbarer Änderung neu zeichnen.
          if (_updateProgress == null ||
              (anteil - _updateProgress!).abs() >= 0.01) {
            setState(() => _updateProgress = anteil);
          }
        },
      );
      // Vor dem Installieren prüfen: gültiges Paket, gleicher Paketname,
      // höhere Version. Sonst würde der Installer eine kaputte oder fremde
      // Datei angeboten bekommen.
      await UpdateService.verifyApk(pfad);
    } catch (e) {
      FeedbackService.log('Update-Download fehlgeschlagen: $e');
      if (mounted) {
        setState(() => _updateProgress = null);
        showErrorSnack(
          context,
          isOfflineError(e)
              ? 'Keine Verbindung — Update nicht geladen.'
              : 'Update fehlgeschlagen: ${e is PlatformException ? e.message : e}',
        );
      }
      return;
    }
    if (!mounted) return;
    setState(() => _updateProgress = null);

    final ergebnis = await UpdateService.install(pfad);
    if (!mounted) return;
    switch (ergebnis) {
      case 'installer':
        break; // Android übernimmt ab hier
      case 'settings':
        showInfoSnack(
            context,
            'Bitte "Unbekannte Apps installieren" für den Kalender erlauben, '
            'dann erneut auf Aktualisieren tippen.');
      default:
        showErrorSnack(context,
            'Installation konnte nicht gestartet werden. Release: ${release.releaseUrl}');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        title: const Text('Einstellungen',
            style: TextStyle(
                color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
        actions: const [FeedbackIconButton()],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ICS Kalender
          _Section(
            title: 'Kalender (ICS)',
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 10, 16, 2),
                child: Text(
                    'Der Schalter blendet einen Kalender aus, ohne ihn zu '
                    'löschen. Farbe und weitere Einstellungen gibt es über '
                    'den Namen.',
                    style: TextStyle(
                        color: AppColors.textSecondary, fontSize: 12)),
              ),
              if (_sourcesLoading)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(
                      child: CircularProgressIndicator(
                          color: AppColors.primary, strokeWidth: 2)),
                )
              else if (_sources.isEmpty)
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: Text('Noch kein Kalender hinzugefügt',
                      style: TextStyle(
                          color: AppColors.textDisabled, fontSize: 13)),
                )
              else
                ..._sources.map((src) {
                  final srcColor = src.color != null
                      ? Color(src.color!)
                      : AppColors.primary;
                  // Ausgeblendete Kalender bleiben stehen, treten aber zurueck.
                  final aus = !src.visible;
                  return ListTile(
                    onTap: () => _openCalendarOptions(src),
                    leading: GestureDetector(
                      onTap: () => _openCalendarOptions(src),
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: aus
                              ? srcColor.withValues(alpha: 0.25)
                              : srcColor,
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: Colors.white24, width: 1),
                        ),
                        child: Icon(
                          src.isFile
                              ? Icons.insert_drive_file_outlined
                              : Icons.calendar_month_outlined,
                          color: Colors.white,
                          size: 14,
                        ),
                      ),
                    ),
                    title: Text(src.name,
                        style: TextStyle(
                            color: aus
                                ? AppColors.textDisabled
                                : AppColors.textPrimary,
                            fontSize: 14)),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          aus
                              ? 'Ausgeblendet'
                              : src.infoOnly
                                  ? 'Nur zur Info · ${src.url}'
                                  : src.url,
                          style: TextStyle(
                              color: src.infoOnly && !aus
                                  ? AppColors.primaryLight
                                  : AppColors.textSecondary,
                              fontSize: 10),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        // Die Farbe hing bisher unsichtbar am Kreis links.
                        GestureDetector(
                          onTap: () => _openCalendarOptions(src),
                          child: Padding(
                            padding: const EdgeInsets.only(top: 3, bottom: 2),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 10,
                                  height: 10,
                                  decoration: BoxDecoration(
                                      color: srcColor, shape: BoxShape.circle),
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  src.color != null
                                      ? 'Farbe ändern'
                                      : 'Farbe wählen',
                                  style: const TextStyle(
                                      color: AppColors.primary,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Der Schalter macht das, was man an dieser Stelle
                        // erwartet: den Kalender an und aus. Alles Weitere
                        // steckt hinter dem Namen.
                        Tooltip(
                          message: src.visible
                              ? 'Kalender ausblenden'
                              : 'Kalender einblenden',
                          child: Switch(
                            value: src.visible,
                            onChanged: (v) => _toggleIcsVisible(src, v),
                            activeThumbColor: AppColors.primary,
                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline,
                              color: Colors.redAccent, size: 20),
                          onPressed: () => _removeSource(src.id),
                          tooltip: 'Entfernen',
                        ),
                      ],
                    ),
                  );
                }),
              const Divider(height: 1, color: AppColors.background),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _addUrl,
                        icon: const Icon(Icons.link, size: 16),
                        label: const Text('URL', style: TextStyle(fontSize: 13)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primary,
                          side: const BorderSide(color: AppColors.primary),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _addFile,
                        icon: const Icon(Icons.upload_file, size: 16),
                        label: const Text('Datei', style: TextStyle(fontSize: 13)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primary,
                          side: const BorderSide(color: AppColors.primary),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // An-/Abfahrtszeiten je Kalender
          _Section(
            title: 'An- und Abfahrtszeiten',
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Text(
                    'Gilt für alle Termine des jeweiligen Kalenders. '
                    'Einzelne Termine und ganze Serien können davon abweichen '
                    '— das stellt man am Termin selbst ein.',
                    style: TextStyle(
                        color: AppColors.textSecondary, fontSize: 12)),
              ),
              _travelTile(TravelService.ownCalendarId, 'Eigene Termine',
                  Icons.phone_android),
              if (_sourcesLoading)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(
                      child: CircularProgressIndicator(
                          color: AppColors.primary, strokeWidth: 2)),
                )
              else
                ..._sources.map((src) =>
                    _travelTile(src.id, src.name, Icons.cloud_outlined)),
            ],
          ),
          const SizedBox(height: 16),

          // Outlook
          _Section(
            title: 'Outlook',
            children: [
              SwitchListTile(
                secondary: const Icon(Icons.mail_outline,
                    color: AppColors.primary, size: 22),
                title: const Text('Todo-Drop erlauben',
                    style: TextStyle(
                        color: AppColors.textPrimary, fontSize: 14)),
                subtitle: const Text(
                    'Todos in Outlook-Termine ziehen erlauben',
                    style: TextStyle(
                        color: AppColors.textSecondary, fontSize: 12)),
                value: _outlookAllowTodoDrop,
                onChanged: _toggleOutlookAllowTodoDrop,
                activeThumbColor: AppColors.primary,
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Benachrichtigungen
          _Section(
            title: 'Benachrichtigungen',
            children: [
              SwitchListTile(
                secondary: const Icon(Icons.directions_car_outlined,
                    color: AppColors.primary, size: 22),
                title: const Text('Ans Losfahren erinnern',
                    style:
                        TextStyle(color: AppColors.textPrimary, fontSize: 14)),
                subtitle: const Text(
                    'Meldet sich vor der Abfahrt, nicht vor dem Termin. Nur '
                    'wo eine Anfahrtszeit steht — ohne Fahrt gibt es nichts '
                    'loszufahren.',
                    style: TextStyle(
                        color: AppColors.textSecondary, fontSize: 12)),
                value: _abfahrtAn,
                onChanged: (wert) async {
                  setState(() => _abfahrtAn = wert);
                  await DepartureReminderService.setAn(wert);
                  if (!mounted) return;
                  _gespeichert();
                },
                activeThumbColor: AppColors.primary,
              ),
              if (_abfahrtAn) ...[
                _abfahrtZeile(
                  'Wie lange vorher',
                  DropdownButton<int>(
                    value: _abfahrtVorlauf,
                    dropdownColor: AppColors.card,
                    underline: const SizedBox.shrink(),
                    items: [
                      for (final m in [0, 2, 5, 10, 15, 20, 30])
                        DropdownMenuItem(
                          value: m,
                          child: Text(
                            m == 0 ? 'Genau dann' : '$m Min.',
                            style:
                                const TextStyle(color: AppColors.textPrimary),
                          ),
                        ),
                    ],
                    onChanged: (wert) async {
                      if (wert == null) return;
                      setState(() => _abfahrtVorlauf = wert);
                      await DepartureReminderService.setLeadMinutes(wert);
                      if (!mounted) return;
                      _gespeichert();
                    },
                  ),
                ),
                _abfahrtZeile(
                  'Wie eindringlich',
                  DropdownButton<ReminderUrgency>(
                    value: _abfahrtStufe,
                    dropdownColor: AppColors.card,
                    underline: const SizedBox.shrink(),
                    items: [
                      for (final stufe in ReminderUrgency.values)
                        DropdownMenuItem(
                          value: stufe,
                          child: Text(stufe.label,
                              style: const TextStyle(
                                  color: AppColors.textPrimary)),
                        ),
                    ],
                    onChanged: (wert) async {
                      if (wert == null) return;
                      setState(() => _abfahrtStufe = wert);
                      await DepartureReminderService.setUrgency(wert);
                      if (!mounted) return;
                      _gespeichert();
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: Text(
                    // Was die Stufe tut, und wer das letzte Wort hat.
                    '${_abfahrtStufe.beschreibung}. Wie laut es wirklich '
                    'wird, entscheidet am Ende das Handy — jede Stufe hat '
                    'in den Android-Einstellungen einen eigenen Kanal.',
                    style: const TextStyle(
                        color: AppColors.textSecondary, fontSize: 12),
                  ),
                ),
              ],
              _ActionTile(
                icon: Icons.notifications_outlined,
                iconColor: AppColors.primary,
                title: 'Test-Benachrichtigung',
                subtitle: 'Eine sofort, eine geplante 15 Sekunden später',
                actionLabel: 'Testen',
                actionColor: AppColors.primary,
                onAction: _testNotification,
              ),
            ],
          ),
          const SizedBox(height: 16),

          // App / Update
          _Section(
            title: 'App',
            children: [
              _ActionTile(
                icon: Icons.system_update_outlined,
                iconColor: AppColors.accent,
                title: 'Nach Update suchen',
                subtitle: _updateProgress != null
                    ? 'Lade Update... ${(_updateProgress! * 100).round()} %'
                    : _checkingUpdate
                        ? 'Prüfe GitHub-Release...'
                        : 'Installiert: Build ${UpdateService.installedBuild}',
                actionLabel: _updateProgress != null
                    ? '${(_updateProgress! * 100).round()} %'
                    : _checkingUpdate
                        ? '...'
                        : 'Prüfen',
                actionColor: AppColors.accent,
                onAction: (_checkingUpdate || _updateProgress != null)
                    ? () {}
                    : _checkForUpdate,
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Kategorien
          _Section(
            title: 'Kategorien',
            children: [
              _ActionTile(
                icon: Icons.label_outline,
                iconColor: AppColors.primary,
                title: 'Kategorien bearbeiten',
                subtitle: CategoryService.all.map((c) => c.label).join(', '),
                actionLabel: 'Öffnen',
                actionColor: AppColors.primary,
                onAction: _openCategories,
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Orte mit Öffnungszeiten
          _Section(
            title: 'Orte',
            children: [
              _ActionTile(
                icon: Icons.storefront_outlined,
                iconColor: AppColors.primary,
                title: 'Orte und Öffnungszeiten',
                subtitle: _orteZeile,
                actionLabel: 'Öffnen',
                actionColor: AppColors.primary,
                onAction: _openPlaces,
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Text(
                  'Mehrere Fitnessstudios in eine Gruppe, Öffnungszeiten '
                  'dazu, Rangliste festlegen — wenn ein Termin näher rückt, '
                  'sagt die App, in welches du kannst.',
                  style: TextStyle(
                      color: AppColors.textSecondary, fontSize: 12),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text('Wie lange vorher melden',
                          style: TextStyle(color: AppColors.textPrimary)),
                    ),
                    DropdownButton<int>(
                      value: _vorlaufMinuten,
                      dropdownColor: AppColors.card,
                      underline: const SizedBox.shrink(),
                      items: [
                        for (final m in [15, 30, 60, 90, 120, 180])
                          DropdownMenuItem(
                            value: m,
                            child: Text(
                              m < 60
                                  ? '$m Min.'
                                  : '${m ~/ 60} ${m == 60 ? "Stunde" : "Stunden"}',
                              style: const TextStyle(
                                  color: AppColors.textPrimary),
                            ),
                          ),
                      ],
                      onChanged: (wert) async {
                        if (wert == null) return;
                        // Den Messenger vor dem Warten holen: danach ist
                        // der Context vielleicht nicht mehr da.
                        final messenger = ScaffoldMessenger.of(context);
                        setState(() => _vorlaufMinuten = wert);
                        await PlaceReminderService.setLeadMinutes(wert);
                        messenger
                          ..hideCurrentSnackBar()
                          ..showSnackBar(const SnackBar(
                            content: Text('Gespeichert.',
                                style: TextStyle(color: Colors.white)),
                            backgroundColor: AppColors.card,
                            duration: Duration(seconds: 2),
                          ));
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Sicherung
          _Section(
            title: 'Sicherung',
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Text(
                    'Alles in einer Datei: Termine, To-dos, Jahres-Events, '
                    'Erinnerungen, Notizen, Kategorien und Einstellungen. '
                    'Leg sie auf den PC oder in deine Cloud — ohne eine '
                    'solche Datei ist mit dem Gerät auch alles andere weg. '
                    'Die Outlook-Zugangsdaten bleiben bewusst draußen.',
                    style: TextStyle(
                        color: AppColors.textSecondary, fontSize: 12)),
              ),
              _ActionTile(
                icon: Icons.history,
                iconColor: AppColors.primary,
                title: 'Automatische Sicherung',
                subtitle: _autoInfo(),
                actionLabel: 'Stände',
                actionColor: AppColors.primary,
                onAction: _backupLaeuft ? () {} : _showAutoBackups,
              ),
              _ActionTile(
                icon: Icons.save_alt,
                iconColor: AppColors.started,
                title: 'Sicherung erstellen',
                subtitle: _manuellInfo(),
                actionLabel: _backupLaeuft ? '...' : 'Erstellen',
                actionColor: AppColors.started,
                onAction: _backupLaeuft ? () {} : _createBackup,
              ),
              _ActionTile(
                icon: Icons.settings_backup_restore,
                iconColor: AppColors.paused,
                title: 'Sicherung einspielen',
                subtitle: 'Ersetzt alles auf diesem Gerät durch die Datei',
                actionLabel: _backupLaeuft ? '...' : 'Einspielen',
                actionColor: AppColors.paused,
                onAction: _backupLaeuft ? () {} : _restoreBackup,
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Feedback
          _Section(
            title: 'Support',
            children: [
              _ActionTile(
                icon: Icons.bug_report_outlined,
                iconColor: AppColors.vacation,
                title: 'Fehler melden',
                subtitle: 'Screenshot + Protokoll automatisch angehängt',
                actionLabel: 'Melden',
                actionColor: AppColors.vacation,
                onAction: () => FeedbackService.showReportDialog(context),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // ── Planungseinschränkungen ──────────────────────────────
          const Divider(color: AppColors.divider),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              'Auto-Shift Einschränkungen',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),

          // Blockierende Ganztags-Kategorien
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Ganztags-Termine blockieren Auto-Shift:',
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 14,
              ),
            ),
          ),
          ...CategoryService.all.map((cat) {
            final name = cat.key;
            return CheckboxListTile(
              title: Text(cat.label,
                  style: const TextStyle(color: AppColors.textPrimary)),
              secondary: Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                    shape: BoxShape.circle, color: cat.color),
              ),
              value: _blockingAllDayCats.contains(name),
              activeColor: AppColors.primary,
              tileColor: AppColors.card,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
              onChanged: (on) {
                setState(() {
                  if (on == true) {
                    _blockingAllDayCats.add(name);
                  } else {
                    _blockingAllDayCats.remove(name);
                  }
                });
                _saveBlockingCats();
              },
            );
          }),

          const SizedBox(height: 12),

          // Tageslicht-Fallback
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Tageslicht-Fallback (wenn kein GPS):',
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 14,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<int>(
                    initialValue: _daylightSunrise,
                    decoration: InputDecoration(
                      labelText: 'Sonnenaufgang',
                      labelStyle:
                          const TextStyle(color: AppColors.textSecondary),
                      filled: true,
                      fillColor: AppColors.card,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    dropdownColor: AppColors.surface,
                    style: const TextStyle(color: AppColors.textPrimary),
                    items: List.generate(24, (h) => DropdownMenuItem(
                      value: h,
                      child: Text('${h.toString().padLeft(2, '0')}:00'),
                    )),
                    onChanged: (h) {
                      if (h == null) return;
                      setState(() => _daylightSunrise = h);
                      DaylightService.saveSettings(_daylightSunrise, _daylightSunset);
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<int>(
                    initialValue: _daylightSunset,
                    decoration: InputDecoration(
                      labelText: 'Sonnenuntergang',
                      labelStyle:
                          const TextStyle(color: AppColors.textSecondary),
                      filled: true,
                      fillColor: AppColors.card,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    dropdownColor: AppColors.surface,
                    style: const TextStyle(color: AppColors.textPrimary),
                    items: List.generate(24, (h) => DropdownMenuItem(
                      value: h,
                      child: Text('${h.toString().padLeft(2, '0')}:00'),
                    )),
                    onChanged: (h) {
                      if (h == null) return;
                      setState(() => _daylightSunset = h);
                      DaylightService.saveSettings(_daylightSunrise, _daylightSunset);
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

// ── Subwidgets ──────────────────────────────────────────────────────────────

class _Section extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _Section({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title.toUpperCase(),
          style: const TextStyle(
              color: AppColors.textDisabled,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(children: children),
        ),
      ],
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final String actionLabel;
  final Color actionColor;
  final VoidCallback onAction;

  const _ActionTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.actionLabel,
    required this.actionColor,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: iconColor, size: 22),
      title: Text(title,
          style: const TextStyle(color: AppColors.textPrimary, fontSize: 14)),
      subtitle: Text(subtitle,
          style:
              const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
      trailing: TextButton(
        onPressed: onAction,
        child: Text(actionLabel,
            style: TextStyle(
                color: actionColor, fontWeight: FontWeight.bold)),
      ),
    );
  }
}
