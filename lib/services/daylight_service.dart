import 'dart:math' as math;
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DaylightService {
  static double? _cachedLat;
  static double? _cachedLng;
  static DateTime? _cacheTime;

  static int fallbackSunriseHour = 6;
  static int fallbackSunsetHour = 20;

  static Future<void> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    fallbackSunriseHour = prefs.getInt('daylight_sunrise') ?? 6;
    fallbackSunsetHour = prefs.getInt('daylight_sunset') ?? 20;
  }

  static Future<void> saveSettings(int sunrise, int sunset) async {
    fallbackSunriseHour = sunrise;
    fallbackSunsetHour = sunset;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('daylight_sunrise', sunrise);
    await prefs.setInt('daylight_sunset', sunset);
  }

  static Future<(int, int)> getDaylightWindow(DateTime day) async {
    final pos = await _getPosition();
    if (pos == null) {
      // Kein frischer GPS — Cache verwenden falls vorhanden
      if (_cachedLat != null) {
        return _calculate(_cachedLat!, _cachedLng!, day);
      }
      return (fallbackSunriseHour * 60, fallbackSunsetHour * 60);
    }
    _cachedLat = pos.latitude;
    _cachedLng = pos.longitude;
    _cacheTime = DateTime.now();
    return _calculate(pos.latitude, pos.longitude, day);
  }

  static (int, int) getDaylightWindowSync(DateTime day) {
    if (_cachedLat == null) {
      return (fallbackSunriseHour * 60, fallbackSunsetHour * 60);
    }
    return _calculate(_cachedLat!, _cachedLng!, day);
  }

  static Future<void> prefetchLocation() async {
    if (_cachedLat != null &&
        _cacheTime != null &&
        DateTime.now().difference(_cacheTime!).inHours < 1) {
      return;
    }
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.low),
      ).timeout(const Duration(seconds: 5));
      _cachedLat = pos.latitude;
      _cachedLng = pos.longitude;
      _cacheTime = DateTime.now();
    } catch (_) {
      // Fallback bleibt aktiv
    }
  }

  static Future<Position?> _getPosition() async {
    if (_cachedLat != null &&
        _cacheTime != null &&
        DateTime.now().difference(_cacheTime!).inHours < 1) {
      return null;
    }
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return null;
      }
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.low),
      ).timeout(const Duration(seconds: 5));
    } catch (_) {
      return null;
    }
  }

  /// NOAA vereinfachter Sonnenauf/-untergang-Algorithmus. Genauigkeit ±1 Min.
  static (int, int) _calculate(double lat, double lng, DateTime date) {
    final n = date.toUtc().difference(DateTime.utc(2000, 1, 1, 12)).inDays.toDouble();
    final L = (280.460 + 0.9856474 * n) % 360;
    final g = (357.528 + 0.9856003 * n) % 360 * math.pi / 180;
    final lambda = (L + 1.915 * math.sin(g) + 0.020 * math.sin(2 * g)) * math.pi / 180;
    final eps = 23.439 * math.pi / 180;
    final sinDec = math.sin(eps) * math.sin(lambda);
    final dec = math.asin(sinDec);
    final latRad = lat * math.pi / 180;
    final cosH = (math.cos(90.833 * math.pi / 180) - math.sin(latRad) * sinDec) /
        (math.cos(latRad) * math.cos(dec));
    if (cosH < -1) return (0, 24 * 60);      // Mitternachtssonne
    if (cosH > 1) return (0, 0); // Polarnacht: kein Tageslicht
    final H = math.acos(cosH) * 180 / math.pi;
    final eqTime = (L - lambda * 180 / math.pi) / 15.0;
    final utcOffsetMin = date.timeZoneOffset.inMinutes;
    final lonOffset = lng / 15.0 * 60;
    final noon = 720 - lonOffset - eqTime * 60 + utcOffsetMin;
    final rise = (noon - H * 4).round().clamp(0, 24 * 60 - 1);
    final set = (noon + H * 4).round().clamp(0, 24 * 60 - 1);
    return (rise, set);
  }
}
