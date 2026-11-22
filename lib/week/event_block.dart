import 'package:flutter/material.dart';
import '../app_colors.dart';
import '../models/calendar_event.dart';
import '../models/todo.dart';

/// Visueller Block für einen Termin oder ein Todo in der Wochenansicht
class EventBlock extends StatelessWidget {
  final CalendarEvent? event;
  final Todo? todo;
  final VoidCallback? onTap;

  /// Hakt das To-do mit einem Tipp ab oder wieder auf. Ohne das blieb nur
  /// der Umweg ueber den Status-Dialog.
  final VoidCallback? onToggleDone;
  final double heightPerMinute;
  final bool isDropTarget;

  const EventBlock({
    super.key,
    this.event,
    this.todo,
    this.onTap,
    this.onToggleDone,
    this.heightPerMinute = 1.0,
    this.isDropTarget = false,
  }) : assert(event != null || todo != null);

  @override
  Widget build(BuildContext context) {
    final title = event?.title ?? todo?.title ?? '';
    final isFixed = event?.isFixed ?? todo?.isFixed ?? false;
    final category = event?.category ?? todo?.category ?? 'personal';
    final hasAddress = (event?.address ?? todo?.address) != null;
    final status = event?.status ?? _todoStatus;
    final durationMinutes = event != null
        ? event!.scheduledDuration.inMinutes
        : (todo?.estimatedMinutes ?? 30);

    final color = event?.calendarColor != null
        ? Color(event!.calendarColor!)
        : _colorForStatus(status, category);
    final height = (durationMinutes * heightPerMinute).clamp(24.0, 200.0);
    final showTime = height >= 36;
    final timeStr = _timeString();

    return LayoutBuilder(builder: (context, constraints) {
      // Eine Tagesspalte der Wochenansicht ist am Handy rund 52 px breit.
      // Ein Haken in der Titelzeile liesse dort 17 px fuer den Titel uebrig
      // — aus "Keller aufraeumen" wird "K". Darum wandert er bei schmalen
      // Bloecken in eine eigene Zeile, und die Uhrzeit weicht: die ist auf
      // 38 px ohnehin nicht lesbar.
      final schmal = constraints.maxWidth < 64;
      final hatHaken = onToggleDone != null;
      // Schmal und kurz zugleich: dann bliebe nach Haken und Ortsnadel kein
      // Zeichen Titel uebrig. Dort bleibt es beim Status-Dialog.
      final hakenUnten = hatHaken && schmal && height >= 44;
      final hakenInTitelzeile = hatHaken && !schmal;
      final zeigeZeit = showTime && timeStr != null && !hakenUnten;

      return GestureDetector(
        onTap: onTap,
        child: Container(
          height: height,
          margin: const EdgeInsets.symmetric(horizontal: 1, vertical: 1),
          clipBehavior: Clip.hardEdge,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(6),
            border: isDropTarget
                ? Border.all(color: Colors.white.withValues(alpha: 0.8), width: 2)
                : Border.all(color: color, width: 1.5),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  if (isFixed)
                    const Padding(
                      padding: EdgeInsets.only(right: 3),
                      child: Icon(Icons.lock, size: 10, color: AppColors.fixedTag),
                    ),
                  if (hasAddress)
                    Padding(
                      padding: const EdgeInsets.only(right: 3),
                      child: Icon(Icons.location_on, size: 10, color: color.withValues(alpha: 0.8)),
                    ),
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        fontSize: 12,
                        // Das Theme gibt 1.43 vor: 17 px Zeile in einem Block,
                        // der bei 20 Minuten nur 15 px Platz hat. Der Titel
                        // wurde damit unten abgeschnitten.
                        height: 1.15,
                        color: color,
                        fontWeight: FontWeight.w600,
                        decoration: status == EventStatus.done
                            ? TextDecoration.lineThrough
                            : null,
                      ),
                      maxLines: (showTime || durationMinutes >= 45) ? 2 : 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (hakenInTitelzeile)
                    _haken(status, color, height)
                  else if (!hakenUnten)
                    _statusIcon(status),
                ],
              ),
              if (zeigeZeit)
                Text(
                  timeStr,
                  style: TextStyle(
                    fontSize: 9,
                    height: 1.15,
                    color: color.withValues(alpha: 0.85),
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              if (hakenUnten)
                Align(
                  alignment: Alignment.centerRight,
                  child: _haken(status, color, height),
                ),
            ],
          ),
        ),
      );
    });
  }

  String? _timeString() {
    if (event != null) {
      final s = event!.startTime;
      final e = event!.endTime;
      final start = _hm(s.hour, s.minute);
      final end   = _hm(e.hour, e.minute);
      final before = event!.travelMinutesBefore;
      final after  = event!.travelMinutesAfter;
      final depart = before > 0
          ? _addMin(s.hour * 60 + s.minute - before)
          : null;
      final returnArrival = after > 0
          ? _addMin(e.hour * 60 + e.minute + after)
          : null;
      final parts = [
        if (depart != null) '🚗$depart',
        '$start – $end',
        if (returnArrival != null) '🏠$returnArrival',
      ];
      return parts.join('  ');
    }
    if (todo != null && todo!.scheduledStartHour != null) {
      final sh = todo!.scheduledStartHour!;
      final sm = todo!.scheduledStartMinute ?? 0;
      final total = sh * 60 + sm + todo!.estimatedMinutes;
      final eh = total ~/ 60;
      final em = total % 60;
      final start = _hm(sh, sm);
      final end   = _hm(eh % 24, em);
      final before = todo!.travelMinutesBefore;
      final after  = todo!.travelMinutesAfter;
      final depart = before > 0
          ? _addMin(sh * 60 + sm - before)
          : null;
      final returnArrival = after > 0
          ? _addMin(total + after)
          : null;
      final parts = [
        if (depart != null) '🚗$depart',
        '$start – $end',
        if (returnArrival != null) '🏠$returnArrival',
      ];
      return parts.join('  ');
    }
    return null;
  }

  static String _hm(int h, int m) =>
      '${(h % 24).toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';

  static String _addMin(int totalMin) {
    final h = (totalMin ~/ 60) % 24;
    final m = totalMin % 60;
    if (h < 0 || m < 0) {
      // negative = before midnight
      final abs = totalMin.abs();
      return _hm(24 - abs ~/ 60 - (abs % 60 > 0 ? 1 : 0), (60 - abs % 60) % 60);
    }
    return _hm(h, m);
  }

  EventStatus? get _todoStatus {
    switch (todo?.status) {
      case TodoStatus.started:
        return EventStatus.started;
      case TodoStatus.paused:
        return EventStatus.paused;
      case TodoStatus.done:
        return EventStatus.done;
      default:
        return EventStatus.pending;
    }
  }

  Color _colorForStatus(EventStatus? status, String category) {
    switch (status) {
      case EventStatus.started:
        return AppColors.started;
      case EventStatus.paused:
        return AppColors.paused;
      case EventStatus.done:
        return AppColors.done;
      default:
        return AppColors.forCategory(category);
    }
  }

  /// Der Haken zum Antippen. Wird nur gebaut, wo Platz dafuer ist.
  Widget _haken(EventStatus? status, Color color, double height) {
    final erledigt = status == EventStatus.done;
    // Ein 20-Minuten-Block ist nur 24 px hoch: dort darf der Haken keine
    // Luft nach oben und unten nehmen, sonst laeuft die Zeile ueber.
    final luft = height >= 36 ? 3.0 : 0.0;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onToggleDone,
      child: Padding(
        // Breiter als hoch: die Flaeche wird treffbar, ohne dem Titel
        // Hoehe zu nehmen.
        padding: EdgeInsets.fromLTRB(6, luft, 1, luft),
        child: Icon(
          erledigt ? Icons.check_circle : Icons.radio_button_unchecked,
          size: 14,
          color: erledigt ? AppColors.done : color.withValues(alpha: 0.7),
        ),
      ),
    );
  }

  Widget _statusIcon(EventStatus? status) {
    switch (status) {
      case EventStatus.started:
        return const Icon(Icons.play_arrow, size: 12, color: AppColors.started);
      case EventStatus.paused:
        return const Icon(Icons.pause, size: 12, color: AppColors.paused);
      case EventStatus.done:
        return const Icon(Icons.check, size: 12, color: AppColors.done);
      default:
        return const SizedBox.shrink();
    }
  }
}
