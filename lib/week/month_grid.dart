import 'package:flutter/material.dart';
import '../app_colors.dart';
import '../models/calendar_event.dart';

const List<String> monthNames = [
  'Januar', 'Februar', 'März', 'April', 'Mai', 'Juni',
  'Juli', 'August', 'September', 'Oktober', 'November', 'Dezember',
];

/// Tage zaehlen ueber das Kalenderdatum, nicht in 24-Stunden-Schritten: in
/// der Nacht der Zeitumstellung hat ein Tag 23 oder 25 Stunden, und
/// `DateTime.add(Duration(days: 1))` landet dann wieder im selben Tag.
DateTime addDays(DateTime day, int count) =>
    DateTime(day.year, day.month, day.day + count);

/// Farbe eines Termins im Monatsraster: die Farbe seines Kalenders, sonst
/// die seiner Kategorie. Dieselbe Regel wie in der Ganztags-Zeile der Woche.
Color monthEntryColor(CalendarEvent event) => event.calendarColor != null
    ? Color(event.calendarColor!)
    : AppColors.forCategory(event.category);

/// Die sichtbaren Tage eines Monats: immer ganze Wochen von Montag bis
/// Sonntag, vorn und hinten mit den Randtagen der Nachbarmonate aufgefuellt.
List<DateTime> monthGridDays(DateTime month) {
  final first = DateTime(month.year, month.month, 1);
  final start = addDays(first, -(first.weekday - 1));
  // Tag 0 des Folgemonats ist der letzte Tag dieses Monats.
  final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
  final weeks = (((first.weekday - 1) + daysInMonth) / 7).ceil();
  return List.generate(weeks * 7, (i) => addDays(start, i));
}

/// Monatsraster. Jede Zelle zeigt die Tageszahl und je Termin einen farbigen
/// Balken; was nicht mehr hineinpasst, steht als "+n" darunter. Ein Tippen
/// auf einen Tag gibt diesen nach oben weiter — die Wochenansicht springt
/// damit in die Tagesansicht.
class MonthGrid extends StatelessWidget {
  final DateTime month;
  final DateTime selectedDay;
  final List<DateTime> days;

  /// Alles, was an diesem Tag ansteht, in Anzeigereihenfolge.
  final List<CalendarEvent> Function(DateTime day) entriesForDay;
  final void Function(DateTime day) onDayTap;

  const MonthGrid({
    super.key,
    required this.month,
    required this.selectedDay,
    required this.days,
    required this.entriesForDay,
    required this.onDayTap,
  });

  static const List<String> _weekdays = ['Mo', 'Di', 'Mi', 'Do', 'Fr', 'Sa', 'So'];

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final weeks = days.length ~/ 7;
    return Column(
      children: [
        Container(
          color: AppColors.surface,
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              for (final wd in _weekdays)
                Expanded(
                  child: Text(wd,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5)),
                ),
            ],
          ),
        ),
        Expanded(
          child: Column(
            children: [
              for (int w = 0; w < weeks; w++)
                Expanded(
                  child: Row(
                    children: [
                      for (int d = 0; d < 7; d++)
                        Expanded(
                          child: _MonthCell(
                            day: days[w * 7 + d],
                            inMonth: days[w * 7 + d].month == month.month &&
                                days[w * 7 + d].year == month.year,
                            isToday: _isSameDay(days[w * 7 + d], today),
                            isSelected: _isSameDay(days[w * 7 + d], selectedDay),
                            entries: entriesForDay(days[w * 7 + d]),
                            onTap: () => onDayTap(days[w * 7 + d]),
                          ),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MonthCell extends StatelessWidget {
  final DateTime day;
  final bool inMonth;
  final bool isToday;
  final bool isSelected;
  final List<CalendarEvent> entries;
  final VoidCallback onTap;

  const _MonthCell({
    required this.day,
    required this.inMonth,
    required this.isToday,
    required this.isSelected,
    required this.entries,
    required this.onTap,
  });

  /// Hoehe eines Balkens samt Abstand darunter.
  static const double _barHeight = 13.0;
  static const double _barGap = 2.0;
  static const double _numberHeight = 17.0;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      // Auch leere Zellen sollen das Tippen annehmen.
      behavior: HitTestBehavior.opaque,
      child: Container(
        decoration: BoxDecoration(
          // Die Tage der Nachbarmonate treten zurueck: dieselbe dunkle
          // Flaeche, nur die Zahl ist blasser. Heller waeren sie auffaelliger
          // als der Monat, um den es geht.
          color: isSelected
              ? AppColors.primary.withValues(alpha: 0.12)
              : AppColors.background,
          border: Border(
            right: const BorderSide(color: AppColors.divider, width: 0.5),
            bottom: const BorderSide(color: AppColors.divider, width: 0.5),
          ),
        ),
        child: LayoutBuilder(builder: (ctx, constraints) {
          // Wie viele Balken passen unter die Tageszahl?
          final free = constraints.maxHeight - _numberHeight;
          var fits = (free / (_barHeight + _barGap)).floor();
          if (fits < 0) fits = 0;
          // Passt nicht alles, braucht die letzte Zeile Platz fuer "+n".
          final showMore = entries.length > fits;
          final shown = showMore ? (fits > 0 ? fits - 1 : 0) : entries.length;
          final hidden = entries.length - shown;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: _numberHeight,
                child: Center(
                  child: Container(
                    width: 19,
                    height: 15,
                    alignment: Alignment.center,
                    decoration: isToday
                        ? const BoxDecoration(
                            color: AppColors.primary, shape: BoxShape.circle)
                        : null,
                    child: Text(
                      '${day.day}',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: isToday ? FontWeight.w700 : FontWeight.w500,
                        color: isToday
                            ? Colors.white
                            : (inMonth
                                ? AppColors.textPrimary
                                : AppColors.textDisabled),
                      ),
                    ),
                  ),
                ),
              ),
              for (int i = 0; i < shown; i++)
                Padding(
                  padding: const EdgeInsets.only(left: 1, right: 1, bottom: _barGap),
                  child: _EntryBar(event: entries[i]),
                ),
              if (showMore && hidden > 0)
                SizedBox(
                  height: _barHeight,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 2),
                    child: Text('+$hidden',
                        style: const TextStyle(
                            fontSize: 8.5,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary)),
                  ),
                ),
            ],
          );
        }),
      ),
    );
  }
}

class _EntryBar extends StatelessWidget {
  final CalendarEvent event;
  const _EntryBar({required this.event});

  @override
  Widget build(BuildContext context) {
    final color = monthEntryColor(event);
    return Container(
      height: _MonthCell._barHeight,
      padding: const EdgeInsets.symmetric(horizontal: 2),
      alignment: Alignment.centerLeft,
      decoration: BoxDecoration(
        // Nur zur Kenntnis tritt zurueck: in der Monatsansicht steht je
        // Tag wenig Platz, und der eigene Termin gehoert nach vorn.
        color: color.withValues(
            alpha: event.infoOnly
                ? (event.isAllDay ? 0.35 : 0.12)
                : (event.isAllDay ? 0.85 : 0.28)),
        border: event.isAllDay
            ? null
            : Border(
                left: BorderSide(
                    color: event.infoOnly
                        ? color.withValues(alpha: 0.5)
                        : color,
                    width: 2)),
        borderRadius: BorderRadius.circular(2),
      ),
      child: Text(
        event.title,
        maxLines: 1,
        overflow: TextOverflow.clip,
        softWrap: false,
        style: TextStyle(
          fontSize: 8.5,
          height: 1.1,
          fontWeight: event.infoOnly ? FontWeight.w400 : FontWeight.w500,
          color: event.infoOnly
              ? AppColors.textSecondary
              : (event.isAllDay ? Colors.white : AppColors.textPrimary),
        ),
      ),
    );
  }
}
