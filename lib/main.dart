import 'dart:io';

import 'package:flutter/widgets.dart';

import 'src/launcher/launcher.dart';
import 'src/storage.dart';
import 'src/widget_kind.dart';
import 'src/widget_window.dart';

/// GlassDesk aynı programı iki şekilde çalıştırır:
///  * argümansız → kontrol paneli (başlatıcı)
///  * `--widget=<id>` → tek bir yüzen widget penceresi
Future<void> main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppPaths.init();

  final kind = WidgetKind.fromLaunch(args, Platform.environment);
  if (kind == null) {
    await runLauncher();
  } else {
    await runWidgetWindow(kind);
  }
}
