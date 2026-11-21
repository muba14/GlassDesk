import 'dart:convert';
import 'dart:io';

import 'package:material_ui/material_ui.dart';

/// Bir şehir / konum.
class GeoPlace {
  const GeoPlace({
    required this.name,
    required this.latitude,
    required this.longitude,
    this.region = '',
    this.country = '',
  });

  static const istanbul = GeoPlace(
    name: 'İstanbul',
    latitude: 41.0138,
    longitude: 28.9497,
    region: 'İstanbul',
    country: 'Türkiye',
  );

  final String name;
  final double latitude;
  final double longitude;
  final String region;
  final String country;

  String get subtitle =>
      [region, country].where((s) => s.isNotEmpty && s != name).join(', ');

  Map<String, dynamic> toJson() => {
        'name': name,
        'lat': latitude,
        'lon': longitude,
        'region': region,
        'country': country,
      };

  static GeoPlace? fromJson(Object? json) {
    if (json is! Map) return null;
    final name = json['name'];
    final lat = json['lat'];
    final lon = json['lon'];
    if (name is! String || lat is! num || lon is! num) return null;
    return GeoPlace(
      name: name,
      latitude: lat.toDouble(),
      longitude: lon.toDouble(),
      region: json['region'] is String ? json['region'] as String : '',
      country: json['country'] is String ? json['country'] as String : '',
    );
  }
}

class DailyForecast {
  const DailyForecast({
    required this.date,
    required this.code,
    required this.max,
    required this.min,
  });

  final DateTime date;
  final int code;
  final double max;
  final double min;
}

class WeatherData {
  const WeatherData({
    required this.place,
    required this.temperature,
    required this.feelsLike,
    required this.humidity,
    required this.wind,
    required this.code,
    required this.isDay,
    required this.days,
  });

  final GeoPlace place;
  final double temperature;
  final double feelsLike;
  final int humidity;
  final double wind;
  final int code;
  final bool isDay;
  final List<DailyForecast> days;

  /// Open-Meteo forecast yanıtını çözer.
  static WeatherData parse(Map<String, dynamic> json, GeoPlace place) {
    final current = (json['current'] as Map).cast<String, dynamic>();
    final daily = (json['daily'] as Map).cast<String, dynamic>();
    final times = (daily['time'] as List).cast<Object?>();
    final codes = (daily['weather_code'] as List).cast<Object?>();
    final maxes = (daily['temperature_2m_max'] as List).cast<Object?>();
    final mins = (daily['temperature_2m_min'] as List).cast<Object?>();

    double num0(Object? v) => v is num ? v.toDouble() : 0;

    final days = <DailyForecast>[];
    for (var i = 0; i < times.length; i++) {
      final date = DateTime.tryParse('${times[i]}');
      if (date == null) continue;
      days.add(DailyForecast(
        date: date,
        code: i < codes.length ? num0(codes[i]).round() : 0,
        max: i < maxes.length ? num0(maxes[i]) : 0,
        min: i < mins.length ? num0(mins[i]) : 0,
      ));
    }

    return WeatherData(
      place: place,
      temperature: num0(current['temperature_2m']),
      feelsLike: num0(current['apparent_temperature']),
      humidity: num0(current['relative_humidity_2m']).round(),
      wind: num0(current['wind_speed_10m']),
      code: num0(current['weather_code']).round(),
      isDay: num0(current['is_day']) != 0,
      days: days,
    );
  }

  static List<GeoPlace> parsePlaces(Map<String, dynamic> json) {
    final results = json['results'];
    if (results is! List) return const [];
    final places = <GeoPlace>[];
    for (final r in results) {
      if (r is! Map) continue;
      final name = r['name'];
      final lat = r['latitude'];
      final lon = r['longitude'];
      if (name is! String || lat is! num || lon is! num) continue;
      places.add(GeoPlace(
        name: name,
        latitude: lat.toDouble(),
        longitude: lon.toDouble(),
        region: r['admin1'] is String ? r['admin1'] as String : '',
        country: r['country'] is String ? r['country'] as String : '',
      ));
    }
    return places;
  }
}

/// Open-Meteo istemcisi (ücretsiz, API anahtarı gerekmez).
class WeatherApi {
  const WeatherApi();

  Future<WeatherData> fetch(GeoPlace place) async {
    final uri = Uri.https('api.open-meteo.com', '/v1/forecast', {
      'latitude': '${place.latitude}',
      'longitude': '${place.longitude}',
      'current': 'temperature_2m,relative_humidity_2m,apparent_temperature,'
          'weather_code,wind_speed_10m,is_day',
      'daily': 'weather_code,temperature_2m_max,temperature_2m_min',
      'timezone': 'auto',
      'forecast_days': '5',
    });
    return WeatherData.parse(await _getJson(uri), place);
  }

  Future<List<GeoPlace>> search(String query) async {
    final q = query.trim();
    if (q.length < 2) return const [];
    final uri = Uri.https('geocoding-api.open-meteo.com', '/v1/search', {
      'name': q,
      'count': '5',
      'language': 'tr',
      'format': 'json',
    });
    return WeatherData.parsePlaces(await _getJson(uri));
  }

  Future<Map<String, dynamic>> _getJson(Uri uri) async {
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 10);
    try {
      final request = await client.getUrl(uri);
      final response =
          await request.close().timeout(const Duration(seconds: 15));
      final body = await response.transform(utf8.decoder).join();
      if (response.statusCode != 200) {
        throw HttpException('HTTP ${response.statusCode}', uri: uri);
      }
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) return decoded;
      throw const FormatException('Beklenmeyen yanıt');
    } finally {
      client.close(force: true);
    }
  }
}

/// WMO hava kodu → Türkçe açıklama.
String weatherLabel(int code) {
  switch (code) {
    case 0:
      return 'Açık';
    case 1:
      return 'Çoğunlukla açık';
    case 2:
      return 'Parçalı bulutlu';
    case 3:
      return 'Kapalı';
    case 45:
    case 48:
      return 'Sisli';
    case 51:
    case 53:
    case 55:
      return 'Çisenti';
    case 56:
    case 57:
      return 'Dondurucu çisenti';
    case 61:
      return 'Hafif yağmur';
    case 63:
      return 'Yağmurlu';
    case 65:
      return 'Şiddetli yağmur';
    case 66:
    case 67:
      return 'Dondurucu yağmur';
    case 71:
      return 'Hafif kar';
    case 73:
      return 'Karlı';
    case 75:
      return 'Yoğun kar';
    case 77:
      return 'Kar taneleri';
    case 80:
    case 81:
      return 'Sağanak yağış';
    case 82:
      return 'Şiddetli sağanak';
    case 85:
    case 86:
      return 'Kar sağanağı';
    case 95:
      return 'Gök gürültülü fırtına';
    case 96:
    case 99:
      return 'Dolu ile fırtına';
  }
  return 'Bilinmiyor';
}

/// WMO hava kodu → ikon.
IconData weatherIcon(int code, {bool isDay = true}) {
  if (code == 0 || code == 1) {
    return isDay ? Icons.wb_sunny_rounded : Icons.nights_stay_rounded;
  }
  if (code == 2) return Icons.wb_cloudy_rounded;
  if (code == 3) return Icons.cloud_rounded;
  if (code == 45 || code == 48) return Icons.foggy;
  if (code >= 51 && code <= 57) return Icons.grain_rounded;
  if (code >= 61 && code <= 67) return Icons.umbrella_rounded;
  if (code >= 71 && code <= 77) return Icons.ac_unit_rounded;
  if (code >= 80 && code <= 82) return Icons.umbrella_rounded;
  if (code == 85 || code == 86) return Icons.ac_unit_rounded;
  if (code >= 95) return Icons.thunderstorm_rounded;
  return Icons.cloud_rounded;
}

Color weatherColor(int code, {bool isDay = true}) {
  if (code <= 1) {
    return isDay ? const Color(0xFFFFD166) : const Color(0xFFC9C3FF);
  }
  if (code >= 95) return const Color(0xFFB79CFF);
  if ((code >= 71 && code <= 77) || code == 85 || code == 86) {
    return Colors.white;
  }
  if (code >= 51 && code <= 82) return const Color(0xFF7CC8FF);
  return const Color(0xFFD8E2F0);
}
