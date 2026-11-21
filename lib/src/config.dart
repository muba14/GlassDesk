import 'dart:io';

import 'storage.dart';
import 'widget_kind.dart';

/// Widget pencerelerinin diğer pencerelere göre katmanı.
enum WindowLayer {
  top('Üstte'),
  normal('Normal'),
  bottom('Masaüstünde');

  const WindowLayer(this.label);
  final String label;

  static WindowLayer fromName(Object? name) {
    for (final layer in WindowLayer.values) {
      if (layer.name == name) return layer;
    }
    return WindowLayer.normal;
  }
}

/// Başlatıcı ile widget pencereleri arasında paylaşılan ayarlar.
/// Başlatıcı yazar, widget'lar birkaç saniyede bir okuyup uygular.
class GlassConfig {
  GlassConfig({
    Map<String, bool>? enabled,
    this.layer = WindowLayer.normal,
    this.blur = true,
    this.tint = 0.5,
  }) : enabled = enabled ?? <String, bool>{};

  final Map<String, bool> enabled;
  WindowLayer layer;

  /// Windows'ta akrilik (bulanık cam) efekti.
  bool blur;

  /// Camın koyuluğu, 0 (çok saydam) – 1 (koyu).
  double tint;

  static JsonFile get _file => JsonFile.named('config.json');

  static bool get isFirstRun => !_file.exists();

  static GlassConfig load() {
    final json = _file.read();
    final enabledJson = json['enabled'];
    final enabled = <String, bool>{};
    if (enabledJson is Map) {
      enabledJson.forEach((key, value) {
        if (key is String && value is bool) enabled[key] = value;
      });
    }
    final tint = json['tint'];
    return GlassConfig(
      enabled: enabled,
      layer: WindowLayer.fromName(json['layer']),
      blur: json['blur'] is bool ? json['blur'] as bool : true,
      tint: tint is num ? tint.toDouble().clamp(0.0, 1.0) : 0.5,
    );
  }

  void save() {
    _file.write(<String, dynamic>{
      'enabled': enabled,
      'layer': layer.name,
      'blur': blur,
      'tint': tint,
    });
  }

  bool isEnabled(WidgetKind kind) => enabled[kind.id] ?? false;

  void setEnabled(WidgetKind kind, bool value) => enabled[kind.id] = value;
}

/// Her widget süreci (ve başlatıcı) birkaç saniyede bir "kalp atışı"
/// dosyası yazar. Böylece diğer süreçler onun açık olup olmadığını anlar.
class Heartbeat {
  Heartbeat._();

  static const launcherId = 'launcher';
  static const aliveWindow = Duration(seconds: 6);

  static File _file(String id) => AppPaths.file('hb_$id');

  static void beat(String id) {
    try {
      _file(id).writeAsStringSync(
        '$pid:${DateTime.now().millisecondsSinceEpoch}',
        flush: true,
      );
    } catch (_) {}
  }

  static void clear(String id) {
    try {
      final file = _file(id);
      if (file.existsSync()) file.deleteSync();
    } catch (_) {}
  }

  /// Süreç açıksa pid'ini, değilse null döndürür.
  static int? alivePid(String id) {
    try {
      final file = _file(id);
      if (!file.existsSync()) return null;
      final parts = file.readAsStringSync().trim().split(':');
      if (parts.length != 2) return null;
      final otherPid = int.tryParse(parts[0]);
      final stamp = int.tryParse(parts[1]);
      if (otherPid == null || stamp == null) return null;
      final age = DateTime.now().millisecondsSinceEpoch - stamp;
      if (age > aliveWindow.inMilliseconds) return null;
      return otherPid;
    } catch (_) {
      return null;
    }
  }

  static bool isAlive(String id) => alivePid(id) != null;
}
