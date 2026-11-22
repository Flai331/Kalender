import 'package:flutter/material.dart';

enum RepeatType { none, daily, weekly, monthly, yearly }

enum EventStatus { pending, started, paused, done }

class CalendarEvent {
  final String id;
  final String title;
  final String description;
  final DateTime startTime;
  final DateTime endTime;
  final bool isFixed;
  final bool isAllDay;
  final RepeatType repeatType;
  final String? repeatNote;
  /// Schluessel der Kategorie. Name und Farbe kommen aus dem
  /// CategoryService — frueher war das ein enum, die Kategorien sind jetzt
  /// vom Benutzer bestimmt.
  final String category;
  final String source; // 'app' | 'outlook'
  final String? outlookEventId; // Graph API event ID für PATCH-Calls
  final EventStatus status;
  final DateTime? actualStart;
  final DateTime? actualEnd;
  final int pausedMinutes;
  final DateTime? pauseStart;
  final int? calendarColor; // ARGB int für ICS-Events, null = Kategorie-Farbe
  final String? address;

  /// Eigene An-/Abfahrtszeit dieses Termins in Minuten, `null` = es gilt die
  /// Vorgabe des Kalenders (siehe TravelService). Ein gesetztes `0` ist eine
  /// Aussage: hier ausdruecklich keine Zeit, auch wenn der Kalender eine
  /// vorgibt. Importierte Termine tragen hier nichts — ihre Zeiten liegen im
  /// TravelService, weil sie bei jedem Abruf neu gelesen werden.
  final int? travelBeforeOverride;
  final int? travelAfterOverride;

  /// Die tatsaechlich geltenden Zeiten — aus eigenem Wert, Serie und Kalender
  /// aufgeloest. ABGELEITET: TravelService.resolve setzt sie beim Anzeigen,
  /// [toJson] speichert sie nicht. Wuerden sie gespeichert, fror der erste
  /// Abruf die damalige Kalender-Vorgabe am Termin ein und eine spaetere
  /// Aenderung der Vorgabe wuerde ihn nicht mehr erreichen.
  final int travelMinutesBefore;
  final int travelMinutesAfter;
  final String? icsSourceId;

  /// Nur zur Kenntnis — z. B. der Dienstplan eines anderen Menschen.
  ///
  /// So ein Termin wird angezeigt, **nimmt aber an nichts teil**: er
  /// blockiert keine Zeit, verhindert kein To-do, bekommt keine An- und
  /// Abfahrt und meldet sich nicht. Er steht da, damit man sieht, wann der
  /// andere arbeitet — mehr soll er nicht.
  final bool infoOnly;

  /// Die Ortsgruppe, aus der dieser Termin seinen Ort bekommt — z. B.
  /// „Fitnessstudio". Welches Studio es wird, entscheidet die App erst,
  /// wenn der Termin naeher rueckt: dann zaehlen Öffnungszeiten, Rangliste
  /// und wo man gerade ist. Null heisst: kein Ortsvorschlag.
  final String? placeGroup;

  CalendarEvent({
    required this.id,
    required this.title,
    this.description = '',
    required this.startTime,
    required this.endTime,
    this.isFixed = false,
    this.isAllDay = false,
    this.repeatType = RepeatType.none,
    this.repeatNote,
    this.category = 'personal',
    this.source = 'app',
    this.outlookEventId,
    this.status = EventStatus.pending,
    this.actualStart,
    this.actualEnd,
    this.pausedMinutes = 0,
    this.pauseStart,
    this.calendarColor,
    this.address,
    int? travelBeforeOverride,
    int? travelAfterOverride,
    int? travelMinutesBefore,
    int? travelMinutesAfter,
    this.icsSourceId,
    this.placeGroup,
    this.infoOnly = false,
  })  : travelBeforeOverride = travelBeforeOverride,
        travelAfterOverride = travelAfterOverride,
        // Ohne Auflösung gilt der eigene Wert; ohne eigenen Wert nichts.
        travelMinutesBefore =
            travelMinutesBefore ?? travelBeforeOverride ?? 0,
        travelMinutesAfter = travelMinutesAfter ?? travelAfterOverride ?? 0;

  Duration get scheduledDuration => endTime.difference(startTime);

  int get timeSavedMinutes {
    if (status != EventStatus.done || actualEnd == null) return 0;
    final scheduled = endTime;
    final actual = actualEnd!.add(Duration(minutes: pausedMinutes));
    final diff = scheduled.difference(actual).inMinutes;
    return diff > 0 ? diff : 0;
  }

  static const _unset = Object();

  CalendarEvent copyWith({
    String? id,
    String? title,
    String? description,
    DateTime? startTime,
    DateTime? endTime,
    bool? isFixed,
    bool? isAllDay,
    RepeatType? repeatType,
    String? repeatNote,
    String? category,
    String? source,
    String? outlookEventId,
    EventStatus? status,
    DateTime? actualStart,
    DateTime? actualEnd,
    int? pausedMinutes,
    DateTime? pauseStart,
    int? calendarColor,
    Object? address = _unset,
    Object? travelBeforeOverride = _unset,
    Object? travelAfterOverride = _unset,
    int? travelMinutesBefore,
    int? travelMinutesAfter,
    Object? icsSourceId = _unset,
    Object? placeGroup = _unset,
    bool? infoOnly,
  }) {
    return CalendarEvent(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      isFixed: isFixed ?? this.isFixed,
      isAllDay: isAllDay ?? this.isAllDay,
      repeatType: repeatType ?? this.repeatType,
      repeatNote: repeatNote ?? this.repeatNote,
      category: category ?? this.category,
      source: source ?? this.source,
      outlookEventId: outlookEventId ?? this.outlookEventId,
      status: status ?? this.status,
      actualStart: actualStart ?? this.actualStart,
      actualEnd: actualEnd ?? this.actualEnd,
      pausedMinutes: pausedMinutes ?? this.pausedMinutes,
      pauseStart: pauseStart ?? this.pauseStart,
      calendarColor: calendarColor ?? this.calendarColor,
      address: address == _unset ? this.address : address as String?,
      travelBeforeOverride: travelBeforeOverride == _unset
          ? this.travelBeforeOverride
          : travelBeforeOverride as int?,
      travelAfterOverride: travelAfterOverride == _unset
          ? this.travelAfterOverride
          : travelAfterOverride as int?,
      travelMinutesBefore: travelMinutesBefore ?? this.travelMinutesBefore,
      travelMinutesAfter: travelMinutesAfter ?? this.travelMinutesAfter,
      icsSourceId: icsSourceId == _unset ? this.icsSourceId : icsSourceId as String?,
      placeGroup:
          placeGroup == _unset ? this.placeGroup : placeGroup as String?,
      infoOnly: infoOnly ?? this.infoOnly,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'startTime': startTime.toUtc().toIso8601String(),
        'endTime': endTime.toUtc().toIso8601String(),
        'isFixed': isFixed,
        'isAllDay': isAllDay,
        'repeatType': repeatType.name,
        'repeatNote': repeatNote,
        'category': category,
        'source': source,
        'outlookEventId': outlookEventId,
        'status': status.name,
        'actualStart': actualStart?.toUtc().toIso8601String(),
        'actualEnd': actualEnd?.toUtc().toIso8601String(),
        'pausedMinutes': pausedMinutes,
        'pauseStart': pauseStart?.toUtc().toIso8601String(),
        'address': address,
        // Bewusst nur die eigenen Werte: travelMinutesBefore/After sind
        // abgeleitet und haben in der Datenbank nichts zu suchen.
        'travelBeforeOverride': travelBeforeOverride,
        'travelAfterOverride': travelAfterOverride,
        'icsSourceId': icsSourceId,
        'placeGroup': placeGroup,
        'infoOnly': infoOnly,
      };

  factory CalendarEvent.fromJson(Map<String, dynamic> json) => CalendarEvent(
        id: json['id'] as String,
        title: json['title'] as String,
        description: json['description'] as String? ?? '',
        startTime: DateTime.parse(json['startTime'] as String).toLocal(),
        endTime: DateTime.parse(json['endTime'] as String).toLocal(),
        isFixed: json['isFixed'] as bool? ?? false,
        isAllDay: json['isAllDay'] as bool? ?? false,
        repeatType: RepeatType.values.firstWhere(
          (e) => e.name == json['repeatType'],
          orElse: () => RepeatType.none,
        ),
        repeatNote: json['repeatNote'] as String?,
        category: json['category'] as String? ?? 'personal',
        source: json['source'] as String? ?? 'app',
        outlookEventId: json['outlookEventId'] as String?,
        status: EventStatus.values.firstWhere(
          (e) => e.name == json['status'],
          orElse: () => EventStatus.pending,
        ),
        actualStart: json['actualStart'] != null
            ? DateTime.parse(json['actualStart'] as String).toLocal()
            : null,
        actualEnd: json['actualEnd'] != null
            ? DateTime.parse(json['actualEnd'] as String).toLocal()
            : null,
        pausedMinutes: json['pausedMinutes'] as int? ?? 0,
        pauseStart: json['pauseStart'] != null
            ? DateTime.parse(json['pauseStart'] as String).toLocal()
            : null,
        address: json['address'] as String?,
        // Altbestand: vor der Vererbung war travelMinutesBefore/After der
        // eigene Wert des Termins. Er wird als solcher uebernommen, damit sich
        // fuer bestehende Termine nichts aendert — auch nicht bei 0, das
        // damals „keine Anfahrt" hiess und das weiter heissen soll.
        travelBeforeOverride: json.containsKey('travelBeforeOverride')
            ? (json['travelBeforeOverride'] as num?)?.toInt()
            : (json['travelMinutesBefore'] as num?)?.toInt(),
        travelAfterOverride: json.containsKey('travelAfterOverride')
            ? (json['travelAfterOverride'] as num?)?.toInt()
            : (json['travelMinutesAfter'] as num?)?.toInt(),
        icsSourceId: json['icsSourceId'] as String?,
        placeGroup: json['placeGroup'] as String?,
        infoOnly: json['infoOnly'] as bool? ?? false,
      );

  // Hilfsmethode: TimeOfDay aus startTime
  TimeOfDay get startTimeOfDay =>
      TimeOfDay(hour: startTime.hour, minute: startTime.minute);
}
