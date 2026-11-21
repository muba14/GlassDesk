import 'dart:async';
import 'dart:io';

import 'package:material_ui/material_ui.dart';
import 'package:window_manager/window_manager.dart';

import 'config.dart';
import 'desktop.dart';
import 'glass_panel.dart';
import 'storage.dart';
import 'theme.dart';
import 'widget_content.dart';
import 'widget_kind.dart';

/// Tek bir widget'ı kendi çerçevesiz penceresinde çalıştırır.
Future<void> runWidgetWindow(WidgetKind kind) async {
  // Aynı widget zaten açıksa ikinci kopyayı açma.
  final other = Heartbeat.alivePid(kind.id);
  if (other != null && other != pid) exit(0);
  Heartbeat.beat(kind.id);

  final config = GlassConfig.load();
  if (!config.isEnabled(kind)) {
    config.setEnabled(kind, true);
    config.save();
  }

  final state = JsonFile.named('widget_${kind.id}.json');
  final saved = state.read();
  final x = saved['x'];
  final y = saved['y'];
  final position = (x is num && y is num)
      ? Offset(x.toDouble(), y.toDouble())
      : kind.defaultPosition;

  await Desktop.init();
  final options = WindowOptions(
    size: kind.size,
    minimumSize: kind.size,
    maximumSize: kind.size,
    title: 'GlassDesk · ${kind.title}',
    titleBarStyle: TitleBarStyle.hidden,
    windowButtonVisibility: false,
    skipTaskbar: true,
    backgroundColor: Colors.transparent,
  );

  final translucent = Desktop.supportsBlur && config.blur;
  windowManager.waitUntilReadyToShow(options, () async {
    await windowManager.setResizable(false);
    await windowManager.setPosition(position);
    await Desktop.applyGlass(config.blur);
    await Desktop.applyLayer(config.layer);
    await windowManager.show();
  });

  runApp(WidgetWindowApp(
    kind: kind,
    config: config,
    state: state,
    translucent: translucent,
  ));
}

class WidgetWindowApp extends StatelessWidget {
  const WidgetWindowApp({
    super.key,
    required this.kind,
    required this.config,
    required this.state,
    required this.translucent,
  });

  final WidgetKind kind;
  final GlassConfig config;
  final JsonFile state;
  final bool translucent;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GlassDesk · ${kind.title}',
      debugShowCheckedModeBanner: false,
      theme: buildGlassTheme(),
      color: Colors.transparent,
      home: Scaffold(
        backgroundColor: Colors.transparent,
        body: WidgetShell(
          kind: kind,
          config: config,
          state: state,
          translucent: translucent,
          child: buildWidgetContent(kind),
        ),
      ),
    );
  }
}

/// Widget pencerelerinin ortak kabuğu: cam zemin, sürükleme, üzerine
/// gelince çıkan kapatma düğmesi, sağ tık menüsü, konum kaydı ve
/// başlatıcıdan gelen ayarların uygulanması.
class WidgetShell extends StatefulWidget {
  const WidgetShell({
    super.key,
    required this.kind,
    required this.config,
    required this.state,
    required this.translucent,
    required this.child,
  });

  final WidgetKind kind;
  final GlassConfig config;
  final JsonFile state;
  final bool translucent;
  final Widget child;

  @override
  State<WidgetShell> createState() => _WidgetShellState();
}

class _WidgetShellState extends State<WidgetShell> with WindowListener {
  late GlassConfig _config = widget.config;
  late bool _translucent = widget.translucent;
  Timer? _poll;
  Timer? _saveDebounce;
  bool _hover = false;
  bool _closing = false;

  WidgetKind get _kind => widget.kind;

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    _poll = Timer.periodic(const Duration(seconds: 2), (_) => _tick());
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    _poll?.cancel();
    _saveDebounce?.cancel();
    super.dispose();
  }

  Future<void> _tick() async {
    if (_closing) return;
    Heartbeat.beat(_kind.id);
    final next = GlassConfig.load();
    if (!next.isEnabled(_kind)) {
      await _quit();
      return;
    }
    if (next.layer != _config.layer) await Desktop.applyLayer(next.layer);
    var translucent = _translucent;
    if (next.blur != _config.blur) {
      translucent = await Desktop.applyGlass(next.blur);
    }
    if (!mounted) return;
    setState(() {
      _config = next;
      _translucent = translucent;
    });
  }

  @override
  void onWindowMove() => _schedulePositionSave();

  @override
  void onWindowMoved() => _schedulePositionSave();

  void _schedulePositionSave() {
    _saveDebounce?.cancel();
    _saveDebounce = Timer(const Duration(milliseconds: 500), () async {
      try {
        final p = await windowManager.getPosition();
        widget.state.update((data) {
          data['x'] = p.dx;
          data['y'] = p.dy;
        });
      } catch (_) {}
    });
  }

  Future<void> _close() async {
    final config = GlassConfig.load();
    config.setEnabled(_kind, false);
    config.save();
    await _quit();
  }

  Future<void> _quit() async {
    if (_closing) return;
    _closing = true;
    _poll?.cancel();
    Heartbeat.clear(_kind.id);
    try {
      await windowManager.destroy();
    } catch (_) {}
    exit(0);
  }

  Future<void> _showMenu(Offset position) async {
    final choice = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx,
        position.dy,
        position.dx,
        position.dy,
      ),
      items: const [
        PopupMenuItem(
          value: 'launcher',
          height: 36,
          child: Text('GlassDesk panelini aç'),
        ),
        PopupMenuItem(
          value: 'reset',
          height: 36,
          child: Text('Konumu sıfırla'),
        ),
        PopupMenuItem(
          value: 'close',
          height: 36,
          child: Text('Bu widget\'ı kapat'),
        ),
      ],
    );
    switch (choice) {
      case 'launcher':
        await Desktop.openLauncher();
      case 'reset':
        await windowManager.setPosition(_kind.defaultPosition);
      case 'close':
        await _close();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onSecondaryTapUp: (d) => _showMenu(d.globalPosition),
        child: Stack(
          children: [
            Positioned.fill(
              child: WindowDragArea(
                enabled: dragsWholeBody(_kind),
                child: GlassPanel(
                  translucent: _translucent,
                  tint: _config.tint,
                  child: widget.child,
                ),
              ),
            ),
            Positioned(
              top: 6,
              right: 6,
              child: IgnorePointer(
                ignoring: !_hover,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 150),
                  opacity: _hover ? 1 : 0,
                  child: _CloseButton(onTap: _close),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CloseButton extends StatelessWidget {
  const _CloseButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Kapat',
      child: Material(
        color: Colors.black.withValues(alpha: 0.35),
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: const Padding(
            padding: EdgeInsets.all(4),
            child: Icon(Icons.close_rounded, size: 14, color: Colors.white),
          ),
        ),
      ),
    );
  }
}
