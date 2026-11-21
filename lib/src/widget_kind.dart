import 'package:material_ui/material_ui.dart';

/// GlassDesk'teki her widget türü. Her biri masaüstünde kendi küçük
/// penceresinde (ayrı bir süreç olarak) çalışır.
enum WidgetKind {
  clock(
    'clock',
    'Saat & Takvim',
    'Dijital / analog saat ve aylık takvim',
    Icons.schedule_rounded,
    Size(300, 420),
  ),
  system(
    'system',
    'Sistem Monitörü',
    'CPU, RAM, disk ve pil kullanımı',
    Icons.memory_rounded,
    Size(300, 270),
  ),
  weather(
    'weather',
    'Hava Durumu',
    'Anlık hava ve 5 günlük tahmin',
    Icons.wb_sunny_rounded,
    Size(320, 270),
  ),
  notes(
    'notes',
    'Not & Yapılacaklar',
    'Yapışkan not ve görev listesi',
    Icons.sticky_note_2_rounded,
    Size(300, 400),
  );

  const WidgetKind(this.id, this.title, this.description, this.icon, this.size);

  final String id;
  final String title;
  final String description;
  final IconData icon;
  final Size size;

  /// İlk açılışta widget'ların yan yana dizildiği konum.
  Offset get defaultPosition => Offset(40.0 + index * 340.0, 60.0);

  static WidgetKind? fromId(String? id) {
    if (id == null) return null;
    for (final kind in WidgetKind.values) {
      if (kind.id == id) return kind;
    }
    return null;
  }

  /// `--widget=clock` argümanından ya da `GLASSDESK_WIDGET` ortam
  /// değişkeninden hangi widget'ın açılacağını bulur. İkisi de yoksa
  /// başlatıcı (kontrol paneli) açılır.
  static WidgetKind? fromLaunch(List<String> args, Map<String, String> env) {
    for (final arg in args) {
      if (arg.startsWith('--widget=')) {
        return fromId(arg.substring('--widget='.length));
      }
    }
    return fromId(env['GLASSDESK_WIDGET']);
  }
}
