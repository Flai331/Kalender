import 'package:geocoding/geocoding.dart' as geo;
import 'package:geolocator/geolocator.dart';

/// Ein Punkt auf der Karte.
class GeoPoint {
  final double latitude;
  final double longitude;

  const GeoPoint(this.latitude, this.longitude);

  @override
  String toString() =>
      '${latitude.toStringAsFixed(4)}, ${longitude.toStringAsFixed(4)}';
}

/// Ein Fehler mit einem Satz, den man anzeigen kann. Die Oberflaeche soll
/// nicht raten muessen, was "PlatformException: null" bedeutet.
class GeoFehler implements Exception {
  final String nachricht;
  const GeoFehler(this.nachricht);

  @override
  String toString() => nachricht;
}

/// Adresse zu Koordinaten, und wo man gerade ist.
///
/// Beides laeuft ueber das Geraet: der Geocoder von Android, und der
/// Standortdienst. Kein Dienst im Netz, kein Schluessel, keine Anmeldung.
class GeoService {
  /// Sucht die Koordinaten zu einer getippten Adresse.
  ///
  /// Wirft [GeoFehler] mit einem lesbaren Satz, wenn nichts zu finden ist.
  static Future<GeoPoint> lookupAddress(String adresse) async {
    final text = adresse.trim();
    if (text.isEmpty) {
      throw const GeoFehler('Erst eine Adresse eintippen.');
    }
    List<geo.Location> treffer;
    try {
      treffer = await geo.locationFromAddress(text);
    } on geo.NoResultFoundException {
      throw GeoFehler('Zu „$text" wurde nichts gefunden. '
          'Strasse, Hausnummer und Ort hintereinander hilft meistens.');
    } catch (e) {
      throw const GeoFehler('Die Adresssuche hat nicht geantwortet. '
          'Sie braucht Internet — spaeter nochmal versuchen.');
    }
    if (treffer.isEmpty) {
      throw GeoFehler('Zu „$text" wurde nichts gefunden.');
    }
    return GeoPoint(treffer.first.latitude, treffer.first.longitude);
  }

  /// Wo bin ich gerade? Fragt notfalls nach der Erlaubnis.
  ///
  /// Wirft [GeoFehler], wenn der Standort nicht zu haben ist.
  static Future<GeoPoint> currentPosition({
    Duration timeout = const Duration(seconds: 8),
  }) async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        throw const GeoFehler(
            'Der Standort ist am Geraet ausgeschaltet. In den '
            'Android-Einstellungen unter „Standort" einschalten.');
      }
      var erlaubnis = await Geolocator.checkPermission();
      if (erlaubnis == LocationPermission.denied) {
        erlaubnis = await Geolocator.requestPermission();
      }
      if (erlaubnis == LocationPermission.deniedForever) {
        throw const GeoFehler(
            'Der Standort ist dauerhaft abgelehnt. In den App-Einstellungen '
            'von Android wieder erlauben.');
      }
      if (erlaubnis == LocationPermission.denied) {
        throw const GeoFehler('Ohne Standort kann die App die Entfernung '
            'nicht ausrechnen. Die Rangliste gilt weiter.');
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings:
            const LocationSettings(accuracy: LocationAccuracy.medium),
      ).timeout(timeout);
      return GeoPoint(pos.latitude, pos.longitude);
    } on GeoFehler {
      rethrow;
    } catch (_) {
      throw const GeoFehler(
          'Der Standort war nicht zu bekommen. Vielleicht drinnen ohne '
          'Empfang — nochmal versuchen oder ohne Entfernung weitermachen.');
    }
  }

  /// Wie [currentPosition], aber gibt null statt zu werfen — fuer Stellen,
  /// an denen der Standort nur ein Zusatz ist und kein Fehler sein soll.
  static Future<GeoPoint?> currentPositionOrNull() async {
    try {
      return await currentPosition();
    } catch (_) {
      return null;
    }
  }
}
