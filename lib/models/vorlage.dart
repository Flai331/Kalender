import '../models/calendar_event.dart';
import '../models/todo.dart';

enum Vorlagenart { termin, todo }

/// Ein fertig eingestellter Termin oder ein fertiges To-do, ohne Datum.
///
/// „Dienst Spaet" ist immer acht Stunden lang, hat 20 Minuten Anfahrt und
/// zehn zurueck, Kategorie Arbeit. Das jedes Mal neu einzustellen ist Arbeit
/// fuer nichts — die Vorlage traegt es, der Titel ruft es ab.
///
/// ## Warum ein JSON-Beutel und keine Felderliste
///
/// [felder] ist das `toJson()` des Modells, aus dem die Vorlage gemacht
/// wurde, abzueglich dessen, was nur zu *diesem einen* Eintrag gehoert
/// ([_nurEinmalig]). Damit traegt eine Vorlage **alles**, was man einstellen
/// kann, auch das, was es heute noch nicht gibt: ein neues Feld am Modell
/// ist ohne Zutun dabei.
///
/// Der Preis steht in [_nurEinmalig]: ein neues Feld, das NICHT in eine
/// Vorlage gehoert, muss dort eingetragen werden. Sonst traegt die Vorlage
/// zum Beispiel einen Status mit sich herum.
class Vorlage {
  final String id;
  final Vorlagenart art;

  /// Zugleich der Titel, den sie setzt — danach wird getippt und gesucht.
  final String name;

  /// Die Einstellungen als Modell-JSON, ohne das Einmalige.
  final Map<String, dynamic> felder;

  /// Wie lang der Termin dauert. Nur bei [Vorlagenart.termin]: Start und
  /// Ende sind einmalig, die **Dauer** ist es nicht — „acht Stunden" ist
  /// gerade das, was an einem Dienst immer gleich ist. Ein To-do traegt
  /// seine Dauer schon in `estimatedMinutes`.
  final int? dauerMinuten;

  final DateTime zuletztBenutzt;
  final int benutzt;

  const Vorlage({
    required this.id,
    required this.art,
    required this.name,
    required this.felder,
    required this.zuletztBenutzt,
    this.dauerMinuten,
    this.benutzt = 0,
  });

  /// Was nie in eine Vorlage gehoert: alles, was diesen **einen** Eintrag
  /// ausmacht — seine Kennung, seine Zeit, sein Stand, seine Herkunft.
  static const _nurEinmalig = {
    'id',
    'startTime',
    'endTime',
    'scheduledDate',
    'scheduledStartHour',
    'scheduledStartMinute',
    'createdAt',
    'status',
    'isCompleted',
    'actualStart',
    'actualEnd',
    'pausedMinutes',
    'pauseStart',
    'durationHistory',
    'source',
    'outlookEventId',
    'outlookTaskId',
    'outlookListId',
    'icsSourceId',
    'calendarColor',
  };

  static Map<String, dynamic> _gesiebt(Map<String, dynamic> json) {
    final raus = <String, dynamic>{};
    for (final e in json.entries) {
      if (_nurEinmalig.contains(e.key)) continue;
      raus[e.key] = e.value;
    }
    // Der Titel steht in [name] und nur dort. Stuende er auch hier, wuerde
    // eine umbenannte Vorlage den alten Titel setzen: im Dropdown „Dienst
    // Nacht", im Kalender „Dienst Spaet".
    raus.remove('title');
    // Haken gehoeren nicht in eine Vorlage: eine frische Liste ist leer.
    final teile = raus['subTasks'];
    if (teile is List) {
      raus['subTasks'] = teile
          .whereType<Map>()
          .map((t) => {...t.cast<String, dynamic>(), 'isDone': false})
          .toList();
    }
    return raus;
  }

  factory Vorlage.ausTermin(CalendarEvent termin,
          {required String id, required DateTime jetzt}) =>
      Vorlage(
        id: id,
        art: Vorlagenart.termin,
        name: termin.title.trim(),
        felder: _gesiebt(termin.toJson()),
        dauerMinuten: termin.endTime.difference(termin.startTime).inMinutes,
        zuletztBenutzt: jetzt,
      );

  factory Vorlage.ausTodo(Todo todo,
          {required String id, required DateTime jetzt}) =>
      Vorlage(
        id: id,
        art: Vorlagenart.todo,
        name: todo.title.trim(),
        felder: _gesiebt(todo.toJson()),
        zuletztBenutzt: jetzt,
      );

  /// Legt die Vorlage ueber einen bestehenden Termin: Zeit und Kennung
  /// bleiben, alles Eingestellte kommt aus der Vorlage.
  ///
  /// Die Dauer zaehlt ab dem bisherigen Start — wer den Termin auf 14 Uhr
  /// gelegt hat und dann „Dienst Spaet" waehlt, will 14 bis 22 Uhr, nicht
  /// die Uhrzeit von irgendwann.
  CalendarEvent aufTermin(CalendarEvent bestand) {
    final roh = {
      ...bestand.toJson(),
      ...felder,
      'id': bestand.id,
      'title': name,
      'startTime': bestand.startTime.toUtc().toIso8601String(),
      'endTime': (dauerMinuten == null
              ? bestand.endTime
              : bestand.startTime.add(Duration(minutes: dauerMinuten!)))
          .toUtc()
          .toIso8601String(),
    };
    return CalendarEvent.fromJson(roh);
  }

  /// Dasselbe fuer ein To-do: Kennung, Anlagedatum und ein etwaiger Platz im
  /// Kalender bleiben.
  Todo aufTodo(Todo bestand) {
    final roh = {
      ...bestand.toJson(),
      ...felder,
      'id': bestand.id,
      'title': name,
      'createdAt': bestand.createdAt.toUtc().toIso8601String(),
      'scheduledDate': bestand.scheduledDate?.toUtc().toIso8601String(),
      'scheduledStartHour': bestand.scheduledStartHour,
      'scheduledStartMinute': bestand.scheduledStartMinute,
    };
    return Todo.fromJson(roh);
  }

  /// Nur der Name wird anders — der Name ist zugleich der Titel, den die
  /// Vorlage setzt.
  Vorlage umbenannt(String name) => Vorlage(
        id: id,
        art: art,
        name: name,
        felder: felder,
        dauerMinuten: dauerMinuten,
        zuletztBenutzt: zuletztBenutzt,
        benutzt: benutzt,
      );

  Vorlage benutztJetzt(DateTime jetzt) => Vorlage(
        id: id,
        art: art,
        name: name,
        felder: felder,
        dauerMinuten: dauerMinuten,
        zuletztBenutzt: jetzt,
        benutzt: benutzt + 1,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'art': art.name,
        'name': name,
        'felder': felder,
        'dauerMinuten': dauerMinuten,
        'zuletztBenutzt': zuletztBenutzt.toUtc().toIso8601String(),
        'benutzt': benutzt,
      };

  factory Vorlage.fromJson(Map<String, dynamic> json) => Vorlage(
        id: json['id'] as String,
        art: Vorlagenart.values.firstWhere(
          (a) => a.name == json['art'],
          orElse: () => Vorlagenart.termin,
        ),
        name: json['name'] as String? ?? '',
        felder: (json['felder'] as Map?)?.cast<String, dynamic>() ?? const {},
        dauerMinuten: json['dauerMinuten'] as int?,
        zuletztBenutzt:
            DateTime.tryParse(json['zuletztBenutzt'] as String? ?? '')
                    ?.toLocal() ??
                DateTime.fromMillisecondsSinceEpoch(0),
        benutzt: json['benutzt'] as int? ?? 0,
      );
}
