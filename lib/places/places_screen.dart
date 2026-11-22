import 'package:flutter/material.dart';

import '../app_colors.dart';
import '../models/place.dart';
import '../services/place_service.dart';
import '../widgets/save_feedback.dart';
import 'place_edit_screen.dart';

/// Die Wochentage, wie sie in der Liste stehen.
const wochentagKurz = ['', 'Mo', 'Di', 'Mi', 'Do', 'Fr', 'Sa', 'So'];

/// Orte mit Öffnungszeiten, nach Gruppen und je Gruppe als Rangliste.
///
/// Die Rangliste ist der Kern: oben steht, wo man am liebsten hingeht. Wenn
/// ein Termin näher rückt, nimmt die App den obersten, der offen hat.
class PlacesScreen extends StatefulWidget {
  const PlacesScreen({super.key});

  @override
  State<PlacesScreen> createState() => _PlacesScreenState();
}

class _PlacesScreenState extends State<PlacesScreen> {
  List<Place> _orte = [];
  bool _laedt = true;

  @override
  void initState() {
    super.initState();
    _laden();
  }

  Future<void> _laden() async {
    final orte = await PlaceService.all();
    if (!mounted) return;
    setState(() {
      _orte = orte;
      _laedt = false;
    });
  }

  /// Nach Gruppe sortiert, in jeder Gruppe nach Rang.
  Map<String, List<Place>> get _gruppen {
    final out = <String, List<Place>>{};
    for (final p in _orte) {
      out.putIfAbsent(p.group, () => []).add(p);
    }
    for (final liste in out.values) {
      liste.sort((a, b) {
        final r = a.rank.compareTo(b.rank);
        return r != 0 ? r : a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });
    }
    final sortiert = out.keys.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return {for (final g in sortiert) g: out[g]!};
  }

  Future<void> _neu() async {
    final gruppen = _gruppen.keys.toList();
    final geaendert = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => PlaceEditScreen(
          vorhandeneGruppen: gruppen,
          // Der zweite Ort gehoert meistens in eine Gruppe, die es schon
          // gibt — das ist ja der Sinn der Sache. Eine neue Gruppe steht
          // in der Auswahl trotzdem bereit.
          vorschlagGruppe: gruppen.isEmpty ? null : gruppen.first,
        ),
      ),
    );
    if (geaendert == true) await _laden();
  }

  Future<void> _bearbeiten(Place ort) async {
    final geaendert = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => PlaceEditScreen(
          ort: ort,
          vorhandeneGruppen: _gruppen.keys.toList(),
        ),
      ),
    );
    if (geaendert == true) await _laden();
  }

  Future<void> _umsortieren(String gruppe, int von, int nach) async {
    final liste = _gruppen[gruppe]!.map((p) => p.id).toList();
    final id = liste.removeAt(von);
    liste.insert(nach.clamp(0, liste.length), id);
    await PlaceService.reorder(gruppe, liste);
    await _laden();
    if (mounted) showInfoSnack(context, 'Rangliste gespeichert.');
  }

  @override
  Widget build(BuildContext context) {
    final gruppen = _gruppen;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        title: const Text('Orte',
            style: TextStyle(color: AppColors.textPrimary)),
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
      ),
      body: _laedt
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: gruppen.isEmpty
                      ? const _LeerText()
                      : ListView(
                          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                          children: [
                            const Padding(
                              padding: EdgeInsets.fromLTRB(4, 8, 4, 12),
                              child: Text(
                                'Orte einer Gruppe treten gegeneinander an. '
                                'Gedrückt halten und ziehen ändert die '
                                'Rangliste — oben ist am liebsten.',
                                style: TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 13),
                              ),
                            ),
                            for (final eintrag in gruppen.entries)
                              _GruppenAbschnitt(
                                gruppe: eintrag.key,
                                orte: eintrag.value,
                                onTap: _bearbeiten,
                                onReorder: (von, nach) =>
                                    _umsortieren(eintrag.key, von, nach),
                              ),
                          ],
                        ),
                ),
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: SizedBox(
                      width: double.infinity,
                      child: TextButton.icon(
                        icon: const Icon(Icons.add_location_alt_outlined,
                            color: AppColors.primary),
                        label: const Text('Ort hinzufügen',
                            style: TextStyle(color: AppColors.primary)),
                        onPressed: _neu,
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

class _LeerText extends StatelessWidget {
  const _LeerText();

  @override
  Widget build(BuildContext context) => const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text(
            'Noch keine Orte.\n\n'
            'Ein Ort ist zum Beispiel ein Fitnessstudio: Name, '
            'Öffnungszeiten, Adresse. Mehrere Studios kommen in dieselbe '
            'Gruppe und bekommen eine Rangliste — dann sagt der Kalender, '
            'in welches du heute kannst.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textSecondary, height: 1.5),
          ),
        ),
      );
}

class _GruppenAbschnitt extends StatelessWidget {
  final String gruppe;
  final List<Place> orte;
  final void Function(Place) onTap;
  final void Function(int von, int nach) onReorder;

  const _GruppenAbschnitt({
    required this.gruppe,
    required this.orte,
    required this.onTap,
    required this.onReorder,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 8, 4, 6),
          child: Text(
            gruppe.isEmpty ? 'Ohne Gruppe' : gruppe.toUpperCase(),
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.8,
            ),
          ),
        ),
        ReorderableListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: orte.length,
          onReorderItem: onReorder,
          itemBuilder: (context, i) => _OrtZeile(
            key: ValueKey(orte[i].id),
            platz: i + 1,
            ort: orte[i],
            onTap: () => onTap(orte[i]),
          ),
        ),
        const SizedBox(height: 4),
      ],
    );
  }
}

class _OrtZeile extends StatelessWidget {
  final int platz;
  final Place ort;
  final VoidCallback onTap;

  const _OrtZeile({
    super.key,
    required this.platz,
    required this.ort,
    required this.onTap,
  });

  /// Was gerade gilt — das ist die Zeile, die man wirklich liest.
  String _stand() {
    final jetzt = DateTime.now();
    if (!ort.hasHours) return 'Keine Öffnungszeiten — gilt als immer offen';
    final zu = ort.closingAfter(jetzt);
    if (zu != null) {
      return 'Jetzt offen bis ${_uhr(zu)}';
    }
    final auf = ort.nextOpening(jetzt);
    if (auf == null) return 'Geschlossen';
    final heute = DateTime(jetzt.year, jetzt.month, jetzt.day);
    final tag = DateTime(auf.year, auf.month, auf.day);
    if (tag == heute) return 'Zu — wieder ab ${_uhr(auf)}';
    if (tag == DateTime(heute.year, heute.month, heute.day + 1)) {
      return 'Zu — morgen ab ${_uhr(auf)}';
    }
    return 'Zu — ${wochentagKurz[auf.weekday]} ab ${_uhr(auf)}';
  }

  static String _uhr(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final offen = ort.isOpenAt(DateTime.now());
    return Card(
      color: AppColors.card,
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        contentPadding: const EdgeInsets.fromLTRB(12, 4, 8, 4),
        leading: Container(
          width: 28,
          height: 28,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: platz == 1
                ? AppColors.primary
                : AppColors.primary.withValues(alpha: 0.18),
          ),
          child: Text(
            '$platz',
            style: TextStyle(
              color: platz == 1 ? Colors.white : AppColors.primaryLight,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
        ),
        title: Text(ort.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: AppColors.textPrimary)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 2),
            Text(
              _stand(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: offen ? AppColors.sport : AppColors.textDisabled,
                fontSize: 12,
              ),
            ),
            if (!ort.hasPosition)
              const Text(
                'Ohne Koordinaten — keine Entfernung',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: AppColors.textDisabled, fontSize: 11),
              ),
          ],
        ),
        trailing: const Icon(Icons.chevron_right,
            color: AppColors.textSecondary, size: 20),
        onTap: onTap,
      ),
    );
  }
}
