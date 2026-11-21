import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:material_ui/material_ui.dart';
import 'package:glassdesk/src/config.dart';
import 'package:glassdesk/src/glass_panel.dart';
import 'package:glassdesk/src/launcher/launcher.dart';
import 'package:glassdesk/src/launcher/launcher_view.dart';
import 'package:glassdesk/src/widget_kind.dart';
import 'package:glassdesk/src/widgets/clock/clock_widget.dart';
import 'package:glassdesk/src/widgets/notes/notes_store.dart';
import 'package:glassdesk/src/widgets/notes/notes_widget.dart';
import 'package:glassdesk/src/widgets/system/system_stats.dart';
import 'package:glassdesk/src/widgets/system/system_widget.dart';
import 'package:glassdesk/src/widgets/weather/weather_api.dart';
import 'package:glassdesk/src/widgets/weather/weather_widget.dart';

// Testlerde ve ekran görüntülerinde kullanılan örnek veriler.

final sampleTime = DateTime(2026, 11, 21, 18, 45, 32);

WeatherData sampleWeather() => WeatherData(
      place: GeoPlace.istanbul,
      temperature: 14.3,
      feelsLike: 12.1,
      humidity: 68,
      wind: 13.4,
      code: 2,
      isDay: true,
      days: [
        for (final (i, code, max, min) in const [
          (0, 2, 15.0, 9.0),
          (1, 61, 13.0, 10.0),
          (2, 3, 12.0, 8.0),
          (3, 0, 16.0, 7.0),
          (4, 1, 17.0, 9.0),
        ])
          DailyForecast(
            date: DateTime(2026, 11, 21 + i),
            code: code,
            max: max,
            min: min,
          ),
      ],
    );

const sampleSystem = SystemSnapshot(
  cpu: 0.27,
  memUsed: 10307921510,
  memTotal: 17179869184,
  diskUsed: 335007449088,
  diskTotal: 512110190592,
  battery: 78,
  diskLabel: 'Disk (C:)',
);

final sampleCpuHistory = [
  for (var i = 0; i < 60; i++)
    (0.22 +
            0.12 * math.sin(i / 4.5) +
            0.07 * math.sin(i / 1.7 + 1) +
            (i > 40 && i < 46 ? 0.25 : 0))
        .clamp(0.03, 0.95)
        .toDouble(),
];

NotesStore sampleNotes() => NotesStore(
      note: 'Hafta sonu planı\n\n'
          '• GlassDesk README\'yi bitir\n'
          '• Calculus: türev soruları\n'
          '• Akşam 21:00 maç izle\n\n'
          'Fikir: widget\'lara tema seçici ekle',
      todos: [
        TodoItem('Flutter desktop kurulumu', done: true),
        TodoItem('Cam efekti (akrilik)', done: true),
        TodoItem('Hava durumu API\'si', done: true),
        TodoItem('Ekran görüntülerini ekle'),
        TodoItem('GitHub Actions ile derle'),
      ],
    );

Widget sampleContent(WidgetKind kind, {bool analog = false, int notesTab = 0}) {
  switch (kind) {
    case WidgetKind.clock:
      return ClockWidget(
        now: () => sampleTime,
        live: false,
        initialAnalog: analog,
      );
    case WidgetKind.system:
      return SystemWidget(
        source: FakeStatsSource(sampleSystem),
        live: false,
        initialHistory: sampleCpuHistory,
      );
    case WidgetKind.weather:
      return WeatherWidget(live: false, initialData: sampleWeather());
    case WidgetKind.notes:
      return NotesWidget(store: sampleNotes(), initialTab: notesTab);
  }
}

/// Örnek masaüstü duvar kağıdı.
class Wallpaper extends StatelessWidget {
  const Wallpaper({super.key});

  @override
  Widget build(BuildContext context) =>
      const CustomPaint(painter: _WallpaperPainter(), child: SizedBox.expand());
}

class _WallpaperPainter extends CustomPainter {
  const _WallpaperPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1B1446), Color(0xFF3A1C71), Color(0xFF0F3057)],
        ).createShader(rect),
    );
    void blob(double x, double y, double r, Color c) {
      canvas.drawCircle(
        Offset(size.width * x, size.height * y),
        r,
        Paint()
          ..color = c
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 90),
      );
    }

    blob(0.15, 0.25, 220, const Color(0xCCB24BF3));
    blob(0.55, 0.85, 260, const Color(0xAA00C2D1));
    blob(0.85, 0.2, 200, const Color(0xBBFF6FB5));
    blob(0.45, 0.35, 150, const Color(0x88FFB86B));
    blob(0.95, 0.9, 180, const Color(0x996A5CFF));

    // Uzakta dağ silueti.
    final hills = Path()..moveTo(0, size.height);
    for (var x = 0.0; x <= size.width; x += 8) {
      final y = size.height * 0.78 +
          math.sin(x / 140) * 26 +
          math.sin(x / 53 + 2) * 10;
      hills.lineTo(x, y);
    }
    hills
      ..lineTo(size.width, size.height)
      ..close();
    canvas.drawPath(hills, Paint()..color = const Color(0x66090718));
  }

  @override
  bool shouldRepaint(_WallpaperPainter oldDelegate) => false;
}

/// Gerçek penceredeki akrilik efektini taklit eden çerçeve: arkasını
/// bulanıklaştırır ve üstüne cam paneli çizer.
class FakeWindow extends StatelessWidget {
  const FakeWindow({
    super.key,
    required this.size,
    required this.child,
    this.panel = true,
  });

  final Size size;
  final Widget child;
  final bool panel;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size.width,
      height: size.height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Stack(
          fit: StackFit.expand,
          children: [
            BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: 28, sigmaY: 28),
              child: const ColoredBox(color: Color(0x26120F24)),
            ),
            Material(
              type: MaterialType.transparency,
              child: panel ? GlassPanel(child: child) : child,
            ),
          ],
        ),
      ),
    );
  }
}

/// Dört widget'ın masaüstünde göründüğü sahne.
class DesktopScene extends StatelessWidget {
  const DesktopScene({super.key});

  @override
  Widget build(BuildContext context) {
    Widget place(WidgetKind kind, double left, double top) => Positioned(
          left: left,
          top: top,
          child: FakeWindow(size: kind.size, child: sampleContent(kind)),
        );

    return Stack(
      children: [
        const Positioned.fill(child: Wallpaper()),
        place(WidgetKind.clock, 48, 48),
        place(WidgetKind.weather, 376, 48),
        place(WidgetKind.system, 386, 344),
        place(WidgetKind.notes, 932, 48),
      ],
    );
  }
}

/// Analog saat ve yapılacaklar sekmesi.
class VariantsScene extends StatelessWidget {
  const VariantsScene({super.key});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const Positioned.fill(child: Wallpaper()),
        Positioned(
          left: 48,
          top: 40,
          child: FakeWindow(
            size: WidgetKind.clock.size,
            child: sampleContent(WidgetKind.clock, analog: true),
          ),
        ),
        Positioned(
          left: 380,
          top: 40,
          child: FakeWindow(
            size: WidgetKind.notes.size,
            child: sampleContent(WidgetKind.notes, notesTab: 1),
          ),
        ),
      ],
    );
  }
}

/// Kontrol paneli.
class LauncherScene extends StatelessWidget {
  const LauncherScene({super.key});

  @override
  Widget build(BuildContext context) {
    final all = {for (final k in WidgetKind.values) k: true};
    return Stack(
      children: [
        const Positioned.fill(child: Wallpaper()),
        Center(
          child: FakeWindow(
            size: launcherSize,
            panel: false,
            child: LauncherView(
              enabled: {...all, WidgetKind.system: false},
              running: {...all, WidgetKind.system: false},
              layer: WindowLayer.bottom,
              blur: true,
              blurSupported: true,
              tint: 0.5,
              translucent: true,
              onToggle: (_, __) {},
              onAll: (_) {},
              onLayer: (_) {},
              onBlur: (_) {},
              onTint: (_) {},
              onTintEnd: (_) {},
              onMinimize: () {},
              onClose: () {},
            ),
          ),
        ),
      ],
    );
  }
}
