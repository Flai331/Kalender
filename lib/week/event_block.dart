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

    // Nur zur Kenntnis — der Dienstplan eines anderen Menschen. Er wird
    // blasser gezeichnet und liegt hinter den eigenen Terminen, damit der
    // eigene Tag lesbar bleibt.
    final nurInfo = event?.infoOnly ?? false;
    final color = event?.calendarColor != null
        ? Color(event!.calendarColor!)
        : _colorForStatus(status, category);
    final height = (durationMinutes * heightPerMinute).clamp(24.0, 200.0);
    final dauerStr = dauerText(durationMinutes);
    final zeitStr = _zeitraumText();

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
      // Platz wird von oben vergeben: erst der Titel, dann die Dauer, dann
      // die Uhrzeit. Die Dauer passt auch in die schmalste Spalte ("1 Std"),
      // der Zeitraum braucht die doppelte Breite.
      // Was innen wirklich uebrig bleibt: Rand des Blocks (1 px oben und
      // unten), Rahmen (1,5 px oben und unten) und Polster gehen ab. Bei
      // einem 24-px-Block sind das 11 px Abzug — in die restlichen 13 passt
      // die 13,8 px hohe Titelzeile nicht, sie wurde unten angeschnitten.
      // Darum rueckt das Polster in kurzen Bloecken auf 1 px zusammen.
      final engesPolster = height < 36;
      final polster = engesPolster ? 1.0 : 3.0;
      // Der Halbstunden-Termin ist der haeufigste ueberhaupt und misst bei
      // Normalzoom genau 30 px — innen bleiben davon 23. Titel 13,8 plus
      // Dauer 9,0 waeren 22,8: ginge auf, aber ohne jede Reserve. Darum
      // steht die Dauer in engen Bloecken eine Spur kleiner (8 statt 9 px),
      // dann sind es 21,8 und es bleibt Luft. Mit der Uhrzeit darunter
      // sind es 31,8 bei weitem Polster, macht ab 44 px.
      final zeigeDauer = height >= 30 && !hakenUnten;
      final zeigeZeit =
          zeigeDauer && !schmal && height >= 44 && zeitStr != null;
      final titelZweizeilig = !zeigeDauer && durationMinutes >= 45;

      return GestureDetector(
        onTap: onTap,
        child: Container(
          height: height,
          margin: const EdgeInsets.symmetric(horizontal: 1, vertical: 1),
          clipBehavior: Clip.hardEdge,
          decoration: BoxDecoration(
            color: color.withValues(alpha: nurInfo ? 0.10 : 0.2),
            borderRadius: BorderRadius.circular(6),
            border: isDropTarget
                ? Border.all(color: Colors.white.withValues(alpha: 0.8), width: 2)
                : Border.all(
                    color: nurInfo ? color.withValues(alpha: 0.45) : color,
                    width: nurInfo ? 1 : 1.5),
          ),
          padding: EdgeInsets.symmetric(horizontal: 6, vertical: polster),
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
                  if (nurInfo)
                    Padding(
                      padding: const EdgeInsets.only(right: 3),
                      child: Icon(Icons.person_outline,
                          size: 10, color: color.withValues(alpha: 0.8)),
                    ),
                  if (hasAddress && !nurInfo)
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
                        color: nurInfo ? color.withValues(alpha: 0.8) : color,
                        fontWeight:
                            nurInfo ? FontWeight.w500 : FontWeight.w600,
                        decoration: status == EventStatus.done
                            ? TextDecoration.lineThrough
                            : null,
                      ),
                      maxLines: titelZweizeilig ? 2 : 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (hakenInTitelzeile)
                    _haken(status, color, height)
                  else if (!hakenUnten && !nurInfo)
                    _statusIcon(status),
                ],
              ),
              if (zeigeDauer)
                Text(
                  dauerStr,
                  style: TextStyle(
                    fontSize: engesPolster ? 8 : 9,
                    // 1.0 statt 1.15: die 1,4 px entscheiden darueber, ob
                    // ein 30-Minuten-Termin seine Dauer zeigt. Buchstaben
                    // mit Unterlaenge kommen hier nicht vor.
                    height: 1.0,
                    color: color.withValues(alpha: 0.85),
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              if (zeigeZeit)
                Text(
                  zeitStr,
                  style: TextStyle(
                    fontSize: 9,
                    height: 1.0,
                    color: color.withValues(alpha: 0.6),
                    fontWeight: FontWeight.w400,
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

  /// Wie lange der Termin dauert — ohne An- und Abfahrt.
  ///
  /// Vorher stand hier die Uhrzeit zusammen mit Abfahrt und Heimkehr in
  /// einer Zeile: "\u{1F697}07:40  08:00 \u2013 09:00  \u{1F3E0}09:20". In einer
  /// Tagesspalte von 52 px blieb davon "\u{1F697}07:40 08\u2026" stehen — man las die
  /// Abfahrt und nicht den Termin. Die Fahrzeiten stehen ohnehin als
  /// eigene Streifen ueber und unter dem Block.
  ///
  /// Geschrieben wird kurz genug fuer die schmalste Spalte: dort sind rund
  /// 37 px Platz, "1 Std 30 min" braucht 50 und wurde zu "1 Std \u2026".
  /// Viertelstunden stehen darum als Bruch — das ist exakt und passt.
  static String dauerText(int minuten) {
    if (minuten < 60) return '$minuten min';
    final std = minuten ~/ 60;
    const brueche = {0: '', 15: '\u00BC', 30: '\u00BD', 45: '\u00BE'};
    final bruch = brueche[minuten % 60];
    // Krumme Reste (1 Std 20) haben keinen Bruch: dann lieber ganz in
    // Minuten als eine gerundete, also falsche Stundenzahl.
    if (bruch == null) return '$minuten min';
    return '$std$bruch Std';
  }

  /// Von wann bis wann — wieder ohne An- und Abfahrt.
  String? _zeitraumText() {
    if (event != null) {
      final s = event!.startTime;
      final e = event!.endTime;
      return '${_hm(s.hour, s.minute)} – ${_hm(e.hour, e.minute)}';
    }
    if (todo != null && todo!.scheduledStartHour != null) {
      final sh = todo!.scheduledStartHour!;
      final sm = todo!.scheduledStartMinute ?? 0;
      final total = sh * 60 + sm + todo!.estimatedMinutes;
      return '${_hm(sh, sm)} – ${_hm(total ~/ 60, total % 60)}';
    }
    return null;
  }

  static String _hm(int h, int m) =>
      '${(h % 24).toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';

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
