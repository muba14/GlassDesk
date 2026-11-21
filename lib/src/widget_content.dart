import 'package:material_ui/material_ui.dart';

import 'desktop.dart';
import 'storage.dart';
import 'widget_kind.dart';
import 'widgets/clock/clock_widget.dart';
import 'widgets/notes/notes_store.dart';
import 'widgets/notes/notes_widget.dart';
import 'widgets/system/system_stats.dart';
import 'widgets/system/system_widget.dart';
import 'widgets/weather/weather_widget.dart';

/// Gerçek pencerede gösterilecek widget içeriği.
Widget buildWidgetContent(WidgetKind kind) {
  final store = JsonFile.named('widget_${kind.id}.json');
  switch (kind) {
    case WidgetKind.clock:
      return ClockWidget(store: store);
    case WidgetKind.system:
      return SystemWidget(source: SystemStatsSource.platform());
    case WidgetKind.weather:
      return WeatherWidget(store: store);
    case WidgetKind.notes:
      return NotesWidget(
        store: NotesStore.load(JsonFile.named('notes.json')),
        headerWrapper: (header) => WindowDragArea(child: header),
      );
  }
}

/// Not widget'ında yazı alanları olduğu için yalnızca başlıktan
/// sürüklenir; diğerleri her yerinden sürüklenebilir.
bool dragsWholeBody(WidgetKind kind) => kind != WidgetKind.notes;
