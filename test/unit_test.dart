import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:glassdesk/src/config.dart';
import 'package:glassdesk/src/storage.dart';
import 'package:glassdesk/src/widget_kind.dart';
import 'package:glassdesk/src/widgets/clock/calendar.dart';
import 'package:glassdesk/src/widgets/notes/notes_store.dart';
import 'package:glassdesk/src/widgets/system/system_stats.dart';
import 'package:glassdesk/src/widgets/weather/weather_api.dart';

void main() {
  late Directory tmp;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('glassdesk_test_');
    AppPaths.useRoot(tmp);
  });

  tearDown(() {
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
  });

  group('WidgetKind', () {
    test('argümandan widget seçer', () {
      expect(WidgetKind.fromLaunch(['--widget=clock'], {}), WidgetKind.clock);
      expect(WidgetKind.fromLaunch(['--widget=notes'], {}), WidgetKind.notes);
    });

    test('ortam değişkeninden widget seçer', () {
      expect(
        WidgetKind.fromLaunch([], {'GLASSDESK_WIDGET': 'weather'}),
        WidgetKind.weather,
      );
    });

    test('argüman yoksa başlatıcı açılır', () {
      expect(WidgetKind.fromLaunch([], {}), isNull);
      expect(WidgetKind.fromLaunch([], {'GLASSDESK_WIDGET': ''}), isNull);
      expect(WidgetKind.fromLaunch(['--widget=yok'], {}), isNull);
    });
  });

  group('Takvim', () {
    test('Kasım 2026 cumartesi başlar, 6 hafta sürer', () {
      final grid = monthGrid(2026, 11);
      expect(grid.length % 7, 0);
      // 1 Kasım 2026 Pazar → başta 6 boş hücre.
      expect(grid.take(6).every((d) => d == null), isTrue);
      expect(grid[6], DateTime(2026, 11, 1));
      expect(grid.whereType<DateTime>().length, 30);
    });

    test('Şubat 2027 pazartesi başlar', () {
      final grid = monthGrid(2027, 2);
      expect(grid.first, DateTime(2027, 2, 1));
      expect(grid.whereType<DateTime>().length, 28);
    });

    test('Türkçe tarih', () {
      final d = DateTime(2026, 11, 21);
      expect(TrDate.day(d), 'Cumartesi');
      expect(TrDate.longDate(d), '21 Kasım 2026');
      expect(TrDate.shortDay(d), 'Ct');
    });
  });

  group('Sistem ayrıştırıcıları', () {
    test('/proc/stat', () {
      final a = parseProcStat('cpu  100 0 100 800 0 0 0 0 0 0\ncpu0 1 2 3 4')!;
      final b = parseProcStat('cpu  150 0 150 900 0 0 0 0 0 0\n')!;
      expect(a.total, 1000);
      expect(a.idle, 800);
      expect(b.usageSince(a), closeTo(0.5, 0.0001));
      expect(parseProcStat('bozuk'), isNull);
    });

    test('/proc/meminfo', () {
      final mem = parseMeminfo(
        'MemTotal:       16000000 kB\n'
        'MemFree:         1000000 kB\n'
        'MemAvailable:    6000000 kB\n',
      )!;
      expect(mem.total, 16000000 * 1024);
      expect(mem.used, 10000000 * 1024);
    });

    test('df -k', () {
      final disk = parseDf(
        'Filesystem     1K-blocks     Used Available Use% Mounted on\n'
        '/dev/nvme0n1p2 500000000 300000000 200000000  60% /\n',
      )!;
      expect(disk.total, 500000000 * 1024);
      expect(disk.used, 300000000 * 1024);
    });

    test('bayt biçimi', () {
      expect(formatBytes(8 * 1024 * 1024 * 1024), '8,0 GB');
      expect(formatBytes(512 * 1024 * 1024), '512 MB');
      expect(formatBytes(2 * 1024 * 1024 * 1024 * 1024), '2,0 TB');
    });
  });

  group('Hava durumu', () {
    test('Open-Meteo yanıtı çözülür', () {
      final data = WeatherData.parse({
        'current': {
          'temperature_2m': 14.6,
          'apparent_temperature': 12.2,
          'relative_humidity_2m': 70,
          'wind_speed_10m': 11.0,
          'weather_code': 61,
          'is_day': 0,
        },
        'daily': {
          'time': ['2026-11-21', '2026-11-22'],
          'weather_code': [61, 0],
          'temperature_2m_max': [15.1, 17.0],
          'temperature_2m_min': [9.0, 8.4],
        },
      }, GeoPlace.istanbul);
      expect(data.temperature, 14.6);
      expect(data.humidity, 70);
      expect(data.isDay, isFalse);
      expect(data.days.length, 2);
      expect(data.days[1].date, DateTime(2026, 11, 22));
      expect(weatherLabel(data.code), 'Hafif yağmur');
    });

    test('şehir araması çözülür', () {
      final places = WeatherData.parsePlaces({
        'results': [
          {
            'name': 'Ankara',
            'latitude': 39.92,
            'longitude': 32.85,
            'admin1': 'Ankara',
            'country': 'Türkiye',
          },
          {'name': 'eksik'},
        ],
      });
      expect(places.length, 1);
      expect(places.first.name, 'Ankara');
      expect(places.first.subtitle, 'Türkiye');
      expect(WeatherData.parsePlaces({}), isEmpty);
    });

    test('her kodun bir etiketi var', () {
      for (final code in [0, 1, 2, 3, 45, 51, 61, 63, 65, 71, 80, 95, 99]) {
        expect(weatherLabel(code), isNot('Bilinmiyor'));
      }
      expect(weatherLabel(1234), 'Bilinmiyor');
    });

    test('konum JSON gidiş-dönüş', () {
      final back = GeoPlace.fromJson(GeoPlace.istanbul.toJson())!;
      expect(back.name, 'İstanbul');
      expect(back.latitude, GeoPlace.istanbul.latitude);
      expect(GeoPlace.fromJson('bozuk'), isNull);
    });
  });

  group('Ayarlar ve kalıcılık', () {
    test('config kaydedilip okunur', () {
      expect(GlassConfig.isFirstRun, isTrue);
      final config = GlassConfig()
        ..setEnabled(WidgetKind.clock, true)
        ..layer = WindowLayer.bottom
        ..blur = false
        ..tint = 0.8;
      config.save();
      expect(GlassConfig.isFirstRun, isFalse);

      final loaded = GlassConfig.load();
      expect(loaded.isEnabled(WidgetKind.clock), isTrue);
      expect(loaded.isEnabled(WidgetKind.notes), isFalse);
      expect(loaded.layer, WindowLayer.bottom);
      expect(loaded.blur, isFalse);
      expect(loaded.tint, 0.8);
    });

    test('bozuk dosya varsayılanlara döner', () {
      AppPaths.file('config.json').writeAsStringSync('{bozuk');
      final config = GlassConfig.load();
      expect(config.layer, WindowLayer.normal);
      expect(config.blur, isTrue);
    });

    test('kalp atışı', () {
      expect(Heartbeat.isAlive('clock'), isFalse);
      Heartbeat.beat('clock');
      expect(Heartbeat.alivePid('clock'), pid);
      Heartbeat.clear('clock');
      expect(Heartbeat.isAlive('clock'), isFalse);
    });

    test('notlar kaydedilip okunur', () {
      final file = JsonFile.named('notes.json');
      final store = NotesStore.load(file)
        ..note = 'merhaba'
        ..add('Görev 1')
        ..add('   ')
        ..add('Görev 2');
      store.toggle(0);
      expect(store.todos.length, 2);

      final loaded = NotesStore.load(file);
      expect(loaded.note, 'merhaba');
      expect(loaded.todos.length, 2);
      expect(loaded.doneCount, 1);
      loaded.clearDone();
      expect(NotesStore.load(file).todos.single.text, 'Görev 2');
    });
  });
}
