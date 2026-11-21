import 'dart:async';
import 'dart:io';

import 'package:material_ui/material_ui.dart';
import 'package:window_manager/window_manager.dart';

import '../config.dart';
import '../desktop.dart';
import '../theme.dart';
import '../widget_kind.dart';
import 'launcher_view.dart';

const launcherSize = Size(440, 680);

/// Kontrol panelini açar. İlk çalıştırmada tüm widget'ları etkinleştirir.
Future<void> runLauncher() async {
  final firstRun = GlassConfig.isFirstRun;
  final config = GlassConfig.load();
  if (firstRun) {
    for (final kind in WidgetKind.values) {
      config.setEnabled(kind, true);
    }
    config.save();
  }
  Heartbeat.beat(Heartbeat.launcherId);

  await Desktop.init();
  const options = WindowOptions(
    size: launcherSize,
    minimumSize: launcherSize,
    maximumSize: launcherSize,
    center: true,
    title: 'GlassDesk',
    titleBarStyle: TitleBarStyle.hidden,
    windowButtonVisibility: false,
    backgroundColor: Colors.transparent,
  );
  windowManager.waitUntilReadyToShow(options, () async {
    await windowManager.setResizable(false);
    await Desktop.applyGlass(config.blur);
    await windowManager.show();
    await windowManager.focus();
  });

  runApp(LauncherApp(config: config));
}

class LauncherApp extends StatelessWidget {
  const LauncherApp({super.key, required this.config});

  final GlassConfig config;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GlassDesk',
      debugShowCheckedModeBanner: false,
      theme: buildGlassTheme(),
      color: Colors.transparent,
      home: Scaffold(
        backgroundColor: Colors.transparent,
        body: LauncherController(config: config),
      ),
    );
  }
}

/// Başlatıcının mantığı: widget süreçlerini başlatır, durumlarını izler
/// ve ayarları kaydeder. Görünüm [LauncherView]'dadır.
class LauncherController extends StatefulWidget {
  const LauncherController({super.key, required this.config});

  final GlassConfig config;

  @override
  State<LauncherController> createState() => _LauncherControllerState();
}

class _LauncherControllerState extends State<LauncherController> {
  late final GlassConfig _config = widget.config;
  final Map<WidgetKind, bool> _running = {};
  final Map<WidgetKind, DateTime> _spawnedAt = {};
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    _refreshStatus();
    for (final kind in WidgetKind.values) {
      if (_config.isEnabled(kind) && !(_running[kind] ?? false)) {
        _spawn(kind);
      }
    }
    _poll = Timer.periodic(const Duration(seconds: 2), (_) {
      Heartbeat.beat(Heartbeat.launcherId);
      _syncFromDisk();
      _refreshStatus();
    });
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  /// Widget'lar kendilerini kapatınca config dosyası değişir; panele yansıt.
  void _syncFromDisk() {
    final disk = GlassConfig.load();
    for (final kind in WidgetKind.values) {
      _config.setEnabled(kind, disk.isEnabled(kind));
    }
  }

  void _refreshStatus() {
    final now = DateTime.now();
    setState(() {
      for (final kind in WidgetKind.values) {
        final alive = Heartbeat.isAlive(kind.id);
        final starting = _spawnedAt[kind] != null &&
            now.difference(_spawnedAt[kind]!) < const Duration(seconds: 8) &&
            _config.isEnabled(kind);
        _running[kind] = alive || starting;
      }
    });
  }

  void _spawn(WidgetKind kind) {
    _spawnedAt[kind] = DateTime.now();
    _running[kind] = true;
    Desktop.spawnWidget(kind);
  }

  void _setEnabled(WidgetKind kind, bool value) {
    setState(() {
      _config.setEnabled(kind, value);
      _config.save();
      if (value && !Heartbeat.isAlive(kind.id)) {
        _spawn(kind);
      } else if (!value) {
        _spawnedAt.remove(kind);
        _running[kind] = false;
      }
    });
  }

  void _setAll(bool value) {
    for (final kind in WidgetKind.values) {
      _setEnabled(kind, value);
    }
  }

  void _save(void Function() change) {
    setState(change);
    _config.save();
  }

  Future<void> _closeLauncher() async {
    _poll?.cancel();
    Heartbeat.clear(Heartbeat.launcherId);
    try {
      await windowManager.destroy();
    } catch (_) {}
    exit(0);
  }

  @override
  Widget build(BuildContext context) {
    return LauncherView(
      enabled: {for (final k in WidgetKind.values) k: _config.isEnabled(k)},
      running: Map.of(_running),
      layer: _config.layer,
      blur: _config.blur,
      blurSupported: Desktop.supportsBlur,
      tint: _config.tint,
      translucent: Desktop.supportsBlur && _config.blur,
      onToggle: _setEnabled,
      onAll: _setAll,
      onLayer: (layer) => _save(() => _config.layer = layer),
      onBlur: (blur) async {
        _save(() => _config.blur = blur);
        await Desktop.applyGlass(blur);
      },
      onTint: (tint) => setState(() => _config.tint = tint),
      onTintEnd: (tint) => _save(() => _config.tint = tint),
      onMinimize: () => windowManager.minimize(),
      onClose: _closeLauncher,
      titleBarWrapper: (child) => WindowDragArea(child: child),
    );
  }
}
