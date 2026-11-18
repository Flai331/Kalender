import 'package:flutter/material.dart';
import '../app_colors.dart';
import '../models/calendar_event.dart';
import '../models/travel_times.dart';
import '../services/travel_service.dart';
import '../widgets/travel_time_picker.dart';

enum _Scope { einzeln, serie }

/// An-/Abfahrtszeit eines importierten Termins einstellen.
///
/// Eigene Termine tragen ihre Zeit selbst, dafür genügt der Termin-Dialog.
/// Importierte können das nicht: sie werden bei jedem Abruf neu aus dem
/// Abonnement gelesen. Bisher musste man sie zum Bearbeiten in die App
/// übernehmen — danach folgten sie dem fremden Kalender nicht mehr. Dieser
/// Dialog schreibt die Zeit daneben, in die Einstellungen, und lässt den
/// Termin am Abonnement.
class TravelOverrideDialog extends StatefulWidget {
  final CalendarEvent event;
  final String calendarName;

  const TravelOverrideDialog({
    super.key,
    required this.event,
    required this.calendarName,
  });

  /// Gibt true zurück, wenn etwas geändert wurde.
  static Future<bool?> show(
      BuildContext context, CalendarEvent event, String calendarName) {
    return showDialog<bool>(
      context: context,
      builder: (_) =>
          TravelOverrideDialog(event: event, calendarName: calendarName),
    );
  }

  @override
  State<TravelOverrideDialog> createState() => _TravelOverrideDialogState();
}

class _TravelOverrideDialogState extends State<TravelOverrideDialog> {
  late _Scope _scope;
  int? _before;
  int? _after;

  String? get _seriesKey => TravelService.seriesKeyOf(widget.event);
  bool get _hasSeries => _seriesKey != null;

  @override
  void initState() {
    super.initState();
    final eigen = TravelService.eventTimes(widget.event.id);
    // Steht für diesen einen Termin schon etwas, ist das der Zustand, den der
    // Nutzer sieht — dann dort weitermachen. Sonst bei einer Serie die Serie
    // anbieten, denn das ist bei wiederkehrenden Terminen fast immer gemeint.
    _scope = (!eigen.isEmpty || !_hasSeries) ? _Scope.einzeln : _Scope.serie;
    _loadScope();
  }

  void _loadScope() {
    final t = _scope == _Scope.serie
        ? TravelService.seriesTimes(_seriesKey!)
        : TravelService.eventTimes(widget.event.id);
    _before = t.before;
    _after = t.after;
  }

  /// Was gelten würde, wenn auf der gewählten Ebene nichts steht.
  TravelTimes get _inherited {
    final cal = TravelService.calendarTimes(
        TravelService.calendarIdOf(widget.event));
    if (_scope == _Scope.serie) return cal;
    final serie =
        _hasSeries ? TravelService.seriesTimes(_seriesKey!) : TravelTimes.none;
    return TravelTimes(
      before: serie.before ?? cal.before,
      after: serie.after ?? cal.after,
    );
  }

  String get _inheritLabel =>
      _scope == _Scope.serie ? 'Kalender' : (_hasSeries ? 'Serie' : 'Kalender');

  Future<void> _save() async {
    final t = TravelTimes(before: _before, after: _after);
    if (_scope == _Scope.serie) {
      await TravelService.setSeriesTimes(_seriesKey!, t);
    } else {
      await TravelService.setEventTimes(widget.event.id, t);
    }
    if (mounted) Navigator.pop(context, true);
  }

  Widget _scopeChip(String text, _Scope scope) {
    final selected = _scope == scope;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: () => setState(() {
          _scope = scope;
          _loadScope();
        }),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.primary.withValues(alpha: 0.2)
                : AppColors.card,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
                color: selected ? AppColors.primary : AppColors.divider),
          ),
          child: Text(text,
              style: TextStyle(
                fontSize: 12,
                color:
                    selected ? AppColors.primary : AppColors.textSecondary,
                fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
              )),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final inherited = _inherited;
    return AlertDialog(
      backgroundColor: AppColors.surface,
      title: const Text('An- und Abfahrt',
          style: TextStyle(color: AppColors.textPrimary, fontSize: 17)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.event.title,
                style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 2),
            Text('aus „${widget.calendarName}"',
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 12)),
            const SizedBox(height: 14),
            if (_hasSeries) ...[
              const Text('Gilt für',
                  style: TextStyle(
                      color: AppColors.textSecondary, fontSize: 12)),
              const SizedBox(height: 6),
              Row(
                children: [
                  _scopeChip('Nur diesen Termin', _Scope.einzeln),
                  _scopeChip('Ganze Serie', _Scope.serie),
                ],
              ),
              const SizedBox(height: 14),
            ],
            TravelTimePicker(
              label: 'Anfahrt',
              minutes: _before,
              inherited: inherited.before,
              inheritLabel: _inheritLabel,
              onChanged: (v) => setState(() => _before = v),
            ),
            const SizedBox(height: 8),
            TravelTimePicker(
              label: 'Abfahrt',
              minutes: _after,
              inherited: inherited.after,
              inheritLabel: _inheritLabel,
              onChanged: (v) => setState(() => _after = v),
            ),
            const SizedBox(height: 12),
            const Text(
                'Der Termin bleibt am Abonnement und folgt weiter '
                'Änderungen aus dem fremden Kalender.',
                style: TextStyle(
                    color: AppColors.textDisabled, fontSize: 11)),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Abbrechen',
              style: TextStyle(color: AppColors.textSecondary)),
        ),
        TextButton(
          onPressed: _save,
          child: const Text('Speichern',
              style: TextStyle(
                  color: AppColors.primary, fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}
