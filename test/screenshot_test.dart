import 'dart:io';
import 'dart:ui' as ui;

import 'package:material_ui/material_ui.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glassdesk/src/theme.dart';

import 'support/fonts.dart';
import 'support/scene.dart';

/// README ekran görüntülerini uygulamanın gerçek widget'larından üretir:
///
///   flutter test test/screenshot_test.dart --dart-define=SCREENSHOTS=true
///
/// Görseller docs/screenshots/ klasörüne yazılır.
const _enabled = bool.fromEnvironment('SCREENSHOTS');
const _pixelRatio = 1.5;

Future<void> _capture(
  WidgetTester tester,
  String name,
  Size size,
  Widget scene,
) async {
  tester.view.physicalSize = size * _pixelRatio;
  tester.view.devicePixelRatio = _pixelRatio;
  addTearDown(tester.view.reset);

  final key = GlobalKey();
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: buildGlassTheme(fontFamily: 'Roboto'),
      home: RepaintBoundary(key: key, child: scene),
    ),
  );

  // Logo gibi görsellerin çözülmesini bekle.
  await tester.runAsync(() async {
    for (final element in find.byType(Image).evaluate()) {
      final image = element.widget as Image;
      await precacheImage(image.image, element);
    }
  });
  await tester.pump(const Duration(milliseconds: 200));

  final boundary =
      key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: _pixelRatio);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File('docs/screenshots/$name.png');
    file.parent.createSync(recursive: true);
    file.writeAsBytesSync(bytes!.buffer.asUint8List());
  });
}

void main() {
  setUpAll(() async {
    final ok = await loadTestFonts();
    if (_enabled && !ok) {
      throw StateError('Yazı tipleri bulunamadı (FONT_DIR ile verilebilir).');
    }
  });

  testWidgets('masaüstü', (tester) async {
    await _capture(tester, 'desktop', const Size(1280, 720), const DesktopScene());
  }, skip: !_enabled);

  testWidgets('kontrol paneli', (tester) async {
    await _capture(tester, 'launcher', const Size(760, 760), const LauncherScene());
  }, skip: !_enabled);

  testWidgets('analog saat ve yapılacaklar', (tester) async {
    await _capture(tester, 'variants', const Size(728, 480), const VariantsScene());
  }, skip: !_enabled);
}
