import 'dart:io';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_acrylic/flutter_acrylic.dart' as acrylic;
import 'package:window_manager/window_manager.dart';

import 'config.dart';
import 'widget_kind.dart';

/// Masaüstü pencere yardımcıları (window_manager + flutter_acrylic).
class Desktop {
  Desktop._();

  /// Akrilik (bulanık cam) efekti yalnızca Windows'ta desteklenir.
  static bool get supportsBlur => Platform.isWindows;

  static Future<void> init() async {
    if (supportsBlur) {
      try {
        await acrylic.Window.initialize();
      } catch (_) {}
    }
    await windowManager.ensureInitialized();
  }

  /// Cam efektini uygular; efekt gerçekten açıldıysa true döner.
  static Future<bool> applyGlass(bool blur) async {
    if (!supportsBlur) return false;
    try {
      await acrylic.Window.setEffect(
        effect: blur ? acrylic.WindowEffect.acrylic : acrylic.WindowEffect.disabled,
        color: blur ? const Color(0x26120F24) : Colors.transparent,
        dark: true,
      );
      return blur;
    } catch (_) {
      return false;
    }
  }

  static Future<void> applyLayer(WindowLayer layer) async {
    try {
      await windowManager.setAlwaysOnTop(layer == WindowLayer.top);
    } catch (_) {}
    try {
      await windowManager.setAlwaysOnBottom(layer == WindowLayer.bottom);
    } catch (_) {}
  }

  /// Bir widget'ı ayrı bir süreç olarak başlatır.
  static Future<void> spawnWidget(WidgetKind kind) async {
    try {
      await Process.start(
        Platform.resolvedExecutable,
        ['--widget=${kind.id}'],
        environment: {'GLASSDESK_WIDGET': kind.id},
        mode: ProcessStartMode.detached,
      );
    } catch (_) {}
  }

  /// Kontrol panelini (başlatıcıyı) açar; zaten açıksa bir şey yapmaz.
  static Future<void> openLauncher() async {
    if (Heartbeat.isAlive(Heartbeat.launcherId)) return;
    try {
      await Process.start(
        Platform.resolvedExecutable,
        const <String>[],
        environment: {'GLASSDESK_WIDGET': ''},
        mode: ProcessStartMode.detached,
      );
    } catch (_) {}
  }
}

/// İçine basılı tutup sürükleyince pencereyi taşır.
/// (window_manager'ın DragToMoveArea'sından farkı: çift tıkta pencereyi
/// büyütmez.)
class WindowDragArea extends StatelessWidget {
  const WindowDragArea({super.key, required this.child, this.enabled = true});

  final Widget child;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    if (!enabled) return child;
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onPanStart: (_) => windowManager.startDragging(),
      child: child,
    );
  }
}
