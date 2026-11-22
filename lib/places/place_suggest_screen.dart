import 'package:flutter/material.dart';

import '../app_colors.dart';
import '../models/calendar_event.dart';
import '../models/place.dart';
import '../services/geo_service.dart';
import '../services/local_service.dart';
import '../services/place_service.dart';
import '../widgets/save_feedback.dart';
import 'places_screen.dart' show wochentagKurz;

/// „In welches Studio kann ich heute?" — die Antwort, wenn der Termin
/// ansteht.
///
/// Gerechnet wird erst hier: Öffnungszeiten zur Terminzeit, Rangliste, und
/// die Entfernung von da, wo man gerade ist. Beim Anlegen des Termins stand
/// nur die Gruppe fest.
class PlaceSuggestScreen extends StatefulWidget {
  final CalendarEvent event;

  const PlaceSuggestScreen({super.key, required this.event});

  @override
  State<PlaceSuggestScreen> createState() => _PlaceSuggestScreenState();
}

class _PlaceSuggestScreenState extends State<PlaceSuggestScreen> {
  List<PlaceSuggestion> _vorschlaege = [];
  List<Place> _orte = [];
  GeoPoint? _standort;
  String? _standortFehler;
  bool _laedt = true;
  bool _suchtStandort = true;

  String get _gruppe => widget.event.placeGroup ?? '';

  @override
  void initState() {
    super.initState();
    _laden();
  }

  Future<void> _laden() async {
    _orte = await PlaceService.inGroup(_gruppe);
    await _rechnen();
    if (mounted) setState(() => _laedt = false);
    // Der Standort darf dauern — die Rangliste steht schon vorher.
    await _standortHolen();
  }

  Future<void> _standortHolen() async {
    if (mounted) {
      setState(() {
        _suchtStandort = true;
        _standortFehler = null;
      });
    }
    try {
      final punkt = await GeoService.currentPosition();
      _standort = punkt;
    } on GeoFehler catch (e) {
      _standortFehler = e.nachricht;
    } catch (e) {
      _standortFehler = 'Der Standort war nicht zu bekommen.';
    }
    await _rechnen();
    if (mounted) setState(() => _suchtStandort = false);
  }

  Future<void> _rechnen() async {
    final liste = await PlaceService.suggest(
      group: _gruppe,
      from: widget.event.startTime,
      to: widget.event.endTime,
      myLatitude: _standort?.latitude,
      myLongitude: _standort?.longitude,
      places: _orte,
    );
    if (mounted) setState(() => _vorschlaege = liste);
  }

  /// Übernimmt den Ort in den Termin — damit steht in der Wochenansicht,
  /// wo man hin wollte.
  Future<void> _uebernehmen(Place ort) async {
    final text =
        ort.address.trim().isEmpty ? ort.name : '${ort.name}, ${ort.address}';
    try {
      await LocalService.saveEvent(widget.event.copyWith(address: text));
      if (!mounted) return;
      showInfoSnack(context, '„${ort.name}" im Termin eingetragen.');
      Navigator.pop(context, ort);
    } catch (e) {
      if (mounted) showErrorSnack(context, 'Eintragen ging nicht: $e');
    }
  }

  static String _uhr(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  String _wann(DateTime t) {
    final heute = DateTime.now();
    final tag = DateTime(t.year, t.month, t.day);
    final heuteTag = DateTime(heute.year, heute.month, heute.day);
    if (tag == heuteTag) return _uhr(t);
    if (tag == DateTime(heuteTag.year, heuteTag.month, heuteTag.day + 1)) {
      return 'morgen ${_uhr(t)}';
    }
    return '${wochentagKurz[t.weekday]} ${_uhr(t)}';
  }

  @override
  Widget build(BuildContext context) {
    final e = widget.event;
    final offene = _vorschlaege.where((s) => s.open).toList();
    final zu = _vorschlaege.where((s) => !s.open).toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_gruppe.isEmpty ? 'Wohin?' : _gruppe,
                style: const TextStyle(
                    color: AppColors.textPrimary, fontSize: 17)),
            Text(
              '${e.title} · ${_uhr(e.startTime)}–${_uhr(e.endTime)}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  color: AppColors.textSecondary, fontSize: 12),
            ),
          ],
        ),
      ),
      body: _laedt
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
              children: [
                _standortZeile(),
                const SizedBox(height: 12),
                if (_vorschlaege.isEmpty)
                  _hinweis('In der Gruppe „$_gruppe" steht noch kein Ort. '
                      'Unter Einstellungen → Orte anlegen.')
                else if (offene.isEmpty)
                  _hinweis(_vorschlaege.any((s) => s.closesDuring)
                      ? 'Keiner hat den ganzen Termin über offen. Unten '
                          'steht, wo du wenigstens anfangen kannst.'
                      : 'Zur Terminzeit hat keiner offen.')
                else ...[
                  _Empfehlung(
                    vorschlag: offene.first,
                    wann: _wann,
                    onUebernehmen: () => _uebernehmen(offene.first.place),
                  ),
                  if (offene.length > 1) ...[
                    const SizedBox(height: 20),
                    _ueberschrift('Hat auch offen'),
                    for (final s in offene.skip(1))
                      _Zeile(
                        vorschlag: s,
                        wann: _wann,
                        onTap: () => _uebernehmen(s.place),
                      ),
                  ],
                ],
                if (zu.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  _ueberschrift(zu.any((s) => s.closesDuring)
                      ? 'Reicht nicht ganz'
                      : 'Hat zu'),
                  for (final s in zu)
                    _Zeile(
                      vorschlag: s,
                      wann: _wann,
                      onTap: () => _uebernehmen(s.place),
                    ),
                ],
              ],
            ),
    );
  }

  Widget _ueberschrift(String text) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
        child: Text(
          text.toUpperCase(),
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.8,
          ),
        ),
      );

  Widget _hinweis(String text) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(text,
            style: const TextStyle(
                color: AppColors.textSecondary, height: 1.4)),
      );

  Widget _standortZeile() {
    final IconData icon;
    final String text;
    final Color farbe;
    if (_suchtStandort) {
      icon = Icons.my_location;
      text = 'Standort wird geholt …';
      farbe = AppColors.textSecondary;
    } else if (_standort != null) {
      icon = Icons.my_location;
      text = 'Entfernung ab deinem Standort';
      farbe = AppColors.sport;
    } else {
      icon = Icons.location_disabled;
      text = _standortFehler ?? 'Ohne Standort — es gilt die Rangliste.';
      farbe = AppColors.textSecondary;
    }
    return Row(
      children: [
        Icon(icon, size: 16, color: farbe),
        const SizedBox(width: 8),
        Expanded(
          child: Text(text, style: TextStyle(color: farbe, fontSize: 12)),
        ),
        if (!_suchtStandort && _standort == null)
          TextButton(
            onPressed: _standortHolen,
            child: const Text('Nochmal',
                style: TextStyle(color: AppColors.primary, fontSize: 12)),
          ),
      ],
    );
  }
}

class _Empfehlung extends StatelessWidget {
  final PlaceSuggestion vorschlag;
  final String Function(DateTime) wann;
  final VoidCallback onUebernehmen;

  const _Empfehlung({
    required this.vorschlag,
    required this.wann,
    required this.onUebernehmen,
  });

  @override
  Widget build(BuildContext context) {
    final p = vorschlag.place;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('VORSCHLAG',
              style: TextStyle(
                color: AppColors.primaryLight,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1,
              )),
          const SizedBox(height: 6),
          Text(p.name,
              style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 22,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            runSpacing: 4,
            children: [
              if (vorschlag.closesAt != null)
                _merkmal(Icons.schedule,
                    'offen bis ${wann(vorschlag.closesAt!)}', AppColors.sport),
              if (!p.hasHours)
                _merkmal(Icons.schedule, 'immer offen', AppColors.sport),
              if (vorschlag.distanceKm != null)
                _merkmal(Icons.near_me, vorschlag.distanceText,
                    AppColors.textSecondary),
              _merkmal(Icons.emoji_events_outlined,
                  'Platz ${p.rank + 1}', AppColors.textSecondary),
            ],
          ),
          if (p.address.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(p.address,
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 12)),
          ],
          if (p.note.trim().isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(p.note,
                style: const TextStyle(
                    color: AppColors.textDisabled, fontSize: 12)),
          ],
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              onPressed: onUebernehmen,
              child: const Text('In den Termin eintragen',
                  style: TextStyle(color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _merkmal(IconData icon, String text, Color farbe) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: farbe),
          const SizedBox(width: 4),
          Text(text, style: TextStyle(color: farbe, fontSize: 12)),
        ],
      );
}

class _Zeile extends StatelessWidget {
  final PlaceSuggestion vorschlag;
  final String Function(DateTime) wann;
  final VoidCallback onTap;

  const _Zeile({
    required this.vorschlag,
    required this.wann,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final p = vorschlag.place;
    final teile = <String>[
      if (vorschlag.open && vorschlag.closesAt != null)
        'bis ${wann(vorschlag.closesAt!)}'
      else if (vorschlag.open)
        'immer offen'
      else if (vorschlag.closesDuring && vorschlag.closesAt != null)
        'schließt ${wann(vorschlag.closesAt!)} — Termin geht länger'
      else if (vorschlag.nextOpening != null)
        'wieder ${wann(vorschlag.nextOpening!)}'
      else
        'geschlossen',
      if (vorschlag.distanceKm != null) vorschlag.distanceText,
    ];
    return Card(
      color: AppColors.card,
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        dense: true,
        leading: Container(
          width: 26,
          height: 26,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.primary.withValues(alpha: 0.18),
          ),
          child: Text('${p.rank + 1}',
              style: const TextStyle(
                  color: AppColors.primaryLight,
                  fontSize: 12,
                  fontWeight: FontWeight.bold)),
        ),
        title: Text(p.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                color: vorschlag.open
                    ? AppColors.textPrimary
                    : AppColors.textDisabled)),
        subtitle: Text(teile.join(' · '),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                color: vorschlag.open
                    ? AppColors.sport
                    : AppColors.textDisabled,
                fontSize: 12)),
        onTap: onTap,
      ),
    );
  }
}
