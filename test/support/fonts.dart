import 'dart:io';

import 'package:flutter/services.dart';

bool _loaded = false;

/// Testlerde metinlerin gerçek yazı tipiyle çizilmesi için Flutter
/// SDK'sındaki Roboto ve Material Icons yazı tiplerini yükler.
///
/// flutter_tester `<flutter>/bin/cache/artifacts/engine/<platform>/`
/// içinde çalışır; yazı tipleri `<flutter>/bin/cache/artifacts/material_fonts`
/// klasöründedir. İstenirse `--dart-define=FONT_DIR=...` ile başka bir
/// klasör verilebilir.
Future<bool> loadTestFonts() async {
  if (_loaded) return true;
  final dir = _findFontDir();
  if (dir == null) return false;

  final roboto = FontLoader('Roboto');
  final icons = FontLoader('MaterialIcons');
  var robotoCount = 0;
  var iconCount = 0;
  for (final entity in dir.listSync()) {
    if (entity is! File) continue;
    final name = entity.uri.pathSegments.last;
    final lower = name.toLowerCase();
    if (!(lower.endsWith('.ttf') || lower.endsWith('.otf'))) continue;
    final bytes = entity.readAsBytesSync();
    final data = Future<ByteData>.value(ByteData.sublistView(bytes));
    if (name.startsWith('Roboto')) {
      roboto.addFont(data);
      robotoCount++;
    } else if (name.startsWith('MaterialIcons')) {
      icons.addFont(data);
      iconCount++;
    }
  }
  if (robotoCount > 0) await roboto.load();
  if (iconCount > 0) await icons.load();
  _loaded = robotoCount > 0;
  return _loaded;
}

Directory? _findFontDir() {
  const custom = String.fromEnvironment('FONT_DIR');
  if (custom.isNotEmpty && Directory(custom).existsSync()) {
    return Directory(custom);
  }
  var dir = File(Platform.resolvedExecutable).parent;
  for (var i = 0; i < 5; i++) {
    final candidate = Directory(
      '${dir.path}${Platform.pathSeparator}material_fonts',
    );
    if (candidate.existsSync()) return candidate;
    dir = dir.parent;
  }
  return null;
}
