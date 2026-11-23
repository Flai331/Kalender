import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../models/calendar_event.dart';
import '../models/todo.dart';
import '../models/vorlage.dart';
import 'local_service.dart';

const _uuid = Uuid();

/// Die Vorlagen: anlegen, abrufen, loeschen.
///
/// Gelesen wird oft (bei jedem Tastendruck im Titelfeld), geschrieben
/// selten — darum haelt der Dienst die Liste im Speicher und laedt nur
/// einmal. [revision] meldet jede Aenderung, damit offene Bildschirme
/// nachziehen.
class VorlagenService {
  static List<Vorlage> _liste = const [];
  static bool _geladen = false;

  /// Zaehlt bei jeder Aenderung hoch — wie bei den Kategorien und den
  /// An-/Abfahrtszeiten.
  static final ValueNotifier<int> revision = ValueNotifier<int>(0);

  static List<Vorlage> get geladene => _liste;

  static Future<List<Vorlage>> laden() async {
    if (_geladen) return _liste;
    _liste = await LocalService.getVorlagen();
    _geladen = true;
    return _liste;
  }

  /// Liest die Liste neu aus der Datenbank. Nach dem Einspielen einer
  /// Sicherung steht dort etwas anderes als im Speicher.
  static Future<void> neuLaden() async {
    _geladen = false;
    await laden();
    revision.value++;
  }

  /// Nur fuer Tests: vergisst, was geladen wurde.
  static void resetForTesting() {
    _liste = const [];
    _geladen = false;
  }

  static Future<List<Vorlage>> fuer(Vorlagenart art) async =>
      (await laden()).where((v) => v.art == art).toList();

  /// Legt eine Vorlage an — oder ersetzt die gleichnamige derselben Art.
  ///
  /// Gleichnamig ersetzen, statt eine zweite danebenzustellen: wer „Dienst
  /// Spaet" zum zweiten Mal speichert, bessert nach. Zwei Vorschlaege mit
  /// demselben Titel waeren im Dropdown nicht zu unterscheiden.
  static Future<Vorlage> merke(Vorlage neu) async {
    final bestand = await laden();
    final gleich = bestand.where((v) =>
        v.art == neu.art &&
        v.name.toLowerCase().trim() == neu.name.toLowerCase().trim());
    final behaltene = gleich.isEmpty ? null : gleich.first;
    final gespeichert = behaltene == null
        ? neu
        : Vorlage(
            id: behaltene.id,
            art: neu.art,
            name: neu.name,
            felder: neu.felder,
            dauerMinuten: neu.dauerMinuten,
            zuletztBenutzt: neu.zuletztBenutzt,
            benutzt: behaltene.benutzt,
          );
    await _schreibe([
      ...bestand.where((v) => v.id != gespeichert.id),
      gespeichert,
    ]);
    return gespeichert;
  }

  static Future<Vorlage> ausTermin(CalendarEvent termin) =>
      merke(Vorlage.ausTermin(termin,
          id: _uuid.v4(), jetzt: DateTime.now()));

  static Future<Vorlage> ausTodo(Todo todo) =>
      merke(Vorlage.ausTodo(todo, id: _uuid.v4(), jetzt: DateTime.now()));

  /// Haelt fest, dass eine Vorlage benutzt wurde — danach steht sie bei
  /// gleich gutem Treffer weiter oben.
  static Future<void> benutzt(String id) async {
    final bestand = await laden();
    final jetzt = DateTime.now();
    await _schreibe([
      for (final v in bestand) v.id == id ? v.benutztJetzt(jetzt) : v,
    ]);
  }

  /// Benennt eine Vorlage um. `false` heisst: eine andere derselben Art
  /// heisst schon so — zwei gleichnamige waeren im Dropdown nicht zu
  /// unterscheiden.
  static Future<bool> umbenennen(String id, String name) async {
    final neuerName = name.trim();
    if (neuerName.isEmpty) return false;
    final bestand = await laden();
    final selbst = bestand.where((v) => v.id == id);
    if (selbst.isEmpty) return false;
    final art = selbst.first.art;
    final belegt = bestand.any((v) =>
        v.id != id &&
        v.art == art &&
        v.name.toLowerCase().trim() == neuerName.toLowerCase());
    if (belegt) return false;
    await _schreibe([
      for (final v in bestand) v.id == id ? v.umbenannt(neuerName) : v,
    ]);
    return true;
  }

  static Future<void> loeschen(String id) async {
    final bestand = await laden();
    await _schreibe(bestand.where((v) => v.id != id).toList());
  }

  static Future<void> _schreibe(List<Vorlage> liste) async {
    _liste = liste;
    _geladen = true;
    await LocalService.saveVorlagen(liste);
    revision.value++;
  }
}
