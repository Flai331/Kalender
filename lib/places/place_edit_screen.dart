import 'package:flutter/material.dart';

import '../app_colors.dart';
import '../models/place.dart';
import '../services/geo_service.dart';
import '../services/place_service.dart';
import '../widgets/save_feedback.dart';
import 'places_screen.dart' show wochentagKurz;

const _wochentagLang = [
  '',
  'Montag',
  'Dienstag',
  'Mittwoch',
  'Donnerstag',
  'Freitag',
  'Samstag',
  'Sonntag',
];

/// Einen Ort anlegen oder ändern: Name, Gruppe, Adresse, Öffnungszeiten.
///
/// Gibt `true` zurueck, wenn etwas gespeichert oder geloescht wurde.
class PlaceEditScreen extends StatefulWidget {
  final Place? ort;
  final List<String> vorhandeneGruppen;
  final String? vorschlagGruppe;

  const PlaceEditScreen({
    super.key,
    this.ort,
    this.vorhandeneGruppen = const [],
    this.vorschlagGruppe,
  });

  @override
  State<PlaceEditScreen> createState() => _PlaceEditScreenState();
}

class _PlaceEditScreenState extends State<PlaceEditScreen> {
  late final TextEditingController _name;
  late final TextEditingController _adresse;
  late final TextEditingController _notiz;
  late final TextEditingController _neueGruppe;

  /// Null heisst: eine neue Gruppe wird getippt.
  String? _gruppe;

  /// Eigene Kopie — die Liste des Aufrufers bleibt unangetastet.
  late List<String> _gruppen;
  double? _lat;
  double? _lon;
  late List<OpeningHours> _zeiten;
  bool _sucht = false;
  bool _speichert = false;

  bool get _istNeu => widget.ort == null;

  @override
  void initState() {
    super.initState();
    final o = widget.ort;
    _name = TextEditingController(text: o?.name ?? '');
    _adresse = TextEditingController(text: o?.address ?? '');
    _notiz = TextEditingController(text: o?.note ?? '');
    _neueGruppe = TextEditingController();
    _lat = o?.latitude;
    _lon = o?.longitude;
    _zeiten = [...?o?.hours];

    _gruppen = [...widget.vorhandeneGruppen];
    final start = (o?.group ?? widget.vorschlagGruppe ?? '').trim();
    _gruppe = start.isEmpty ? null : start;
    // Die eigene Gruppe gehoert in die Auswahl, auch wenn sie dort noch
    // nicht steht — sonst faellt sie beim Oeffnen heraus.
    if (_gruppe != null && !_gruppen.contains(_gruppe)) {
      _gruppen.add(_gruppe!);
      _gruppen.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _adresse.dispose();
    _notiz.dispose();
    _neueGruppe.dispose();
    super.dispose();
  }

  String get _gruppeText =>
      (_gruppe ?? _neueGruppe.text).trim();

  // ── Koordinaten ─────────────────────────────────────────────────────────

  Future<void> _adresseSuchen() async {
    setState(() => _sucht = true);
    try {
      final punkt = await GeoService.lookupAddress(_adresse.text);
      if (!mounted) return;
      setState(() {
        _lat = punkt.latitude;
        _lon = punkt.longitude;
      });
      showInfoSnack(context, 'Koordinaten gefunden: $punkt');
    } on GeoFehler catch (e) {
      if (mounted) showErrorSnack(context, e.nachricht);
    } finally {
      if (mounted) setState(() => _sucht = false);
    }
  }

  Future<void> _standortNehmen() async {
    setState(() => _sucht = true);
    try {
      final punkt = await GeoService.currentPosition();
      if (!mounted) return;
      setState(() {
        _lat = punkt.latitude;
        _lon = punkt.longitude;
      });
      showInfoSnack(context, 'Dein Standort übernommen: $punkt');
    } on GeoFehler catch (e) {
      if (mounted) showErrorSnack(context, e.nachricht);
    } finally {
      if (mounted) setState(() => _sucht = false);
    }
  }

  // ── Öffnungszeiten ──────────────────────────────────────────────────────

  List<OpeningHours> _amTag(int wochentag) =>
      (_zeiten.where((h) => h.weekday == wochentag).toList()
        ..sort((a, b) => a.fromMinute.compareTo(b.fromMinute)));

  Future<void> _zeitHinzufuegen(int wochentag) async {
    final von = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 8, minute: 0),
      helpText: '${_wochentagLang[wochentag]}: ab wann offen?',
    );
    if (von == null || !mounted) return;
    final bis = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 20, minute: 0),
      helpText: '${_wochentagLang[wochentag]}: bis wann offen?',
    );
    if (bis == null || !mounted) return;

    final vonMin = von.hour * 60 + von.minute;
    var bisMin = bis.hour * 60 + bis.minute;
    // Ein Ende vor dem Anfang heisst: es geht ueber Mitternacht.
    if (bisMin <= vonMin) bisMin += 1440;

    setState(() {
      _zeiten = [
        ..._zeiten,
        OpeningHours(
            weekday: wochentag, fromMinute: vonMin, toMinute: bisMin),
      ];
    });
  }

  void _zeitWeg(OpeningHours h) => setState(() => _zeiten.remove(h));

  /// Nimmt die Zeiten des ersten Wochentags, an dem etwas steht, und legt
  /// sie auf alle [tage]. Fuenfmal dasselbe eintippen ist die Arbeit, die
  /// hier wegfaellt.
  ///
  /// Mit Rueckgaengig: ein Fehlgriff darf nicht eine Viertelstunde
  /// Tipparbeit kosten.
  void _uebertragen(List<int> tage, String was) {
    final quellTag = [for (var t = 1; t <= 7; t++) t]
        .where((t) => _amTag(t).isNotEmpty)
        .firstOrNull;
    if (quellTag == null) {
      showErrorSnack(context, 'Erst an einem Tag eine Zeit eintragen.');
      return;
    }
    final quelle = _amTag(quellTag);
    final vorher = [..._zeiten];
    setState(() {
      _zeiten = [
        ..._zeiten.where((h) => !tage.contains(h.weekday)),
        for (final t in tage)
          for (final h in quelle) h.copyWith(weekday: t),
      ];
    });
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(
          '${_wochentagLang[quellTag]} (${quelle.map((h) => h.text).join(", ")}) '
          'auf $was übernommen.',
          style: const TextStyle(color: Colors.white),
        ),
        backgroundColor: AppColors.card,
        duration: const Duration(seconds: 5),
        action: SnackBarAction(
          label: 'Rückgängig',
          textColor: AppColors.primaryLight,
          onPressed: () => setState(() => _zeiten = vorher),
        ),
      ));
  }

  // ── Speichern ───────────────────────────────────────────────────────────

  Future<void> _speichern() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      showErrorSnack(context, 'Der Ort braucht einen Namen.');
      return;
    }
    final gruppe = _gruppeText;
    if (gruppe.isEmpty) {
      showErrorSnack(
          context,
          'Der Ort braucht eine Gruppe — nur innerhalb einer Gruppe '
          'vergleicht die App.');
      return;
    }

    setState(() => _speichert = true);
    try {
      final alt = widget.ort;
      if (alt == null) {
        // Erst anlegen, damit der Rang am Ende der Gruppe landet, dann die
        // Felder nachtragen.
        final neu = await PlaceService.add(
            name: name, group: gruppe, address: _adresse.text);
        await PlaceService.save(neu.copyWith(
          latitude: _lat,
          longitude: _lon,
          clearPosition: _lat == null || _lon == null,
          hours: _zeiten,
          note: _notiz.text.trim(),
        ));
      } else {
        await PlaceService.save(alt.copyWith(
          name: name,
          group: gruppe,
          address: _adresse.text.trim(),
          latitude: _lat,
          longitude: _lon,
          clearPosition: _lat == null || _lon == null,
          hours: _zeiten,
          note: _notiz.text.trim(),
        ));
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() => _speichert = false);
        showErrorSnack(context, 'Speichern ging nicht: $e');
      }
    }
  }

  Future<void> _loeschen() async {
    final ort = widget.ort;
    if (ort == null) return;
    final ja = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text('„${ort.name}" löschen?',
            style: const TextStyle(color: AppColors.textPrimary)),
        content: const Text(
            'Die Öffnungszeiten sind dann weg und müssen neu eingetippt '
            'werden.',
            style: TextStyle(color: AppColors.textSecondary)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Behalten',
                  style: TextStyle(color: AppColors.textSecondary))),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Löschen',
                  style: TextStyle(color: AppColors.fixedTag))),
        ],
      ),
    );
    if (ja != true) return;
    await PlaceService.remove(ort.id);
    if (mounted) Navigator.pop(context, true);
  }

  // ── Aufbau ──────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        title: Text(_istNeu ? 'Neuer Ort' : 'Ort ändern',
            style: const TextStyle(color: AppColors.textPrimary)),
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
        actions: [
          if (!_istNeu)
            IconButton(
              icon: const Icon(Icons.delete_outline,
                  color: AppColors.textSecondary),
              onPressed: _speichert ? null : _loeschen,
            ),
        ],
      ),
      body: Column(
        children: [
          if (_sucht || _speichert)
            const LinearProgressIndicator(minHeight: 2),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              children: [
                _feld(_name, 'Name', 'McFit Altona'),
                const SizedBox(height: 16),
                _gruppenAuswahl(_gruppen),
                const SizedBox(height: 24),
                _abschnitt('Adresse'),
                _feld(_adresse, 'Straße, Nummer, Ort',
                    'Hauptstraße 1, 20095 Hamburg'),
                const SizedBox(height: 8),
                _koordinatenZeile(),
                const SizedBox(height: 24),
                _abschnitt('Öffnungszeiten'),
                const Padding(
                  padding: EdgeInsets.only(bottom: 8),
                  child: Text(
                    'Ohne Angabe gilt der Ort als immer offen. Ein Ende vor '
                    'dem Anfang heißt „über Mitternacht".',
                    style: TextStyle(
                        color: AppColors.textSecondary, fontSize: 12),
                  ),
                ),
                for (var t = 1; t <= 7; t++) _tagZeile(t),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    TextButton(
                      onPressed: () =>
                          _uebertragen([1, 2, 3, 4, 5], 'Mo–Fr'),
                      child: const Text('Auf Mo–Fr übernehmen',
                          style: TextStyle(color: AppColors.primary)),
                    ),
                    TextButton(
                      onPressed: () =>
                          _uebertragen([1, 2, 3, 4, 5, 6, 7], 'alle Tage'),
                      child: const Text('Auf alle Tage',
                          style: TextStyle(color: AppColors.primary)),
                    ),
                    if (_zeiten.isNotEmpty)
                      TextButton(
                        onPressed: () => setState(() => _zeiten = []),
                        child: const Text('Alle löschen',
                            style: TextStyle(color: AppColors.textSecondary)),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                _abschnitt('Notiz'),
                _feld(_notiz, 'Was man wissen will', 'Hantelbank im Keller',
                    zeilen: 2),
              ],
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: _speichert ? null : _speichern,
                  child: const Text('Speichern',
                      style: TextStyle(color: Colors.white)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _abschnitt(String titel) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          titel.toUpperCase(),
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.8,
          ),
        ),
      );

  Widget _feld(TextEditingController ctrl, String label, String beispiel,
          {int zeilen = 1}) =>
      TextField(
        controller: ctrl,
        maxLines: zeilen,
        style: const TextStyle(color: AppColors.textPrimary),
        decoration: InputDecoration(
          labelText: label,
          hintText: beispiel,
          labelStyle: const TextStyle(color: AppColors.textSecondary),
          hintStyle: const TextStyle(color: AppColors.textDisabled),
          filled: true,
          fillColor: AppColors.card,
          border: const OutlineInputBorder(),
        ),
      );

  Widget _gruppenAuswahl(List<String> gruppen) {
    if (gruppen.isEmpty) {
      return _feld(_neueGruppe, 'Gruppe', 'Fitnessstudio');
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<String?>(
          initialValue: gruppen.contains(_gruppe) ? _gruppe : null,
          isExpanded: true,
          dropdownColor: AppColors.card,
          decoration: const InputDecoration(
            labelText: 'Gruppe',
            labelStyle: TextStyle(color: AppColors.textSecondary),
            filled: true,
            fillColor: AppColors.card,
            border: OutlineInputBorder(),
          ),
          items: [
            for (final g in gruppen)
              DropdownMenuItem(
                value: g,
                child: Text(g,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: AppColors.textPrimary)),
              ),
            const DropdownMenuItem(
              value: null,
              child: Text('Neue Gruppe …',
                  style: TextStyle(color: AppColors.primary)),
            ),
          ],
          onChanged: (wert) => setState(() => _gruppe = wert),
        ),
        if (_gruppe == null) ...[
          const SizedBox(height: 8),
          _feld(_neueGruppe, 'Neue Gruppe', 'Fitnessstudio'),
        ],
      ],
    );
  }

  Widget _koordinatenZeile() {
    final hat = _lat != null && _lon != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                hat
                    ? 'Koordinaten: ${_lat!.toStringAsFixed(4)}, '
                        '${_lon!.toStringAsFixed(4)}'
                    : 'Noch keine Koordinaten — ohne sie zeigt die App '
                        'keine Entfernung.',
                style: TextStyle(
                  color: hat ? AppColors.sport : AppColors.textSecondary,
                  fontSize: 12,
                ),
              ),
            ),
            if (hat)
              IconButton(
                icon: const Icon(Icons.close,
                    size: 18, color: AppColors.textSecondary),
                tooltip: 'Koordinaten entfernen',
                onPressed: () => setState(() {
                  _lat = null;
                  _lon = null;
                }),
              ),
          ],
        ),
        Wrap(
          spacing: 8,
          children: [
            TextButton.icon(
              icon: const Icon(Icons.search, size: 18),
              style: TextButton.styleFrom(foregroundColor: AppColors.primary),
              label: const Text('Adresse suchen'),
              onPressed: _sucht ? null : _adresseSuchen,
            ),
            TextButton.icon(
              icon: const Icon(Icons.my_location, size: 18),
              style: TextButton.styleFrom(foregroundColor: AppColors.primary),
              label: const Text('Ich bin gerade hier'),
              onPressed: _sucht ? null : _standortNehmen,
            ),
          ],
        ),
      ],
    );
  }

  Widget _tagZeile(int wochentag) {
    final zeiten = _amTag(wochentag);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: SizedBox(
              width: 32,
              child: Text(
                wochentagKurz[wochentag],
              style: TextStyle(
                  color: zeiten.isEmpty
                      ? AppColors.textDisabled
                      : AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
          ),
          Expanded(
            child: zeiten.isEmpty
                ? const Padding(
                    padding: EdgeInsets.only(top: 10),
                    child: Text('geschlossen',
                        style: TextStyle(
                            color: AppColors.textDisabled, fontSize: 12)),
                  )
                : Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      for (final h in zeiten)
                        InputChip(
                          label: Text(h.text,
                              style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textPrimary)),
                          backgroundColor: AppColors.cardElevated,
                          side: BorderSide.none,
                          deleteIconColor: AppColors.textSecondary,
                          onDeleted: () => _zeitWeg(h),
                        ),
                    ],
                  ),
          ),
          IconButton(
            icon: const Icon(Icons.add, size: 20, color: AppColors.primary),
            tooltip: 'Zeit hinzufügen',
            onPressed: () => _zeitHinzufuegen(wochentag),
          ),
        ],
      ),
    );
  }
}
