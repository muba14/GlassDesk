import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../../glass_panel.dart';
import '../../theme.dart';
import 'system_stats.dart';

/// CPU geçmiş grafiği + RAM, disk ve pil çubukları.
class SystemWidget extends StatefulWidget {
  const SystemWidget({
    super.key,
    required this.source,
    this.live = true,
    this.initialHistory = const [],
  });

  final SystemStatsSource source;
  final bool live;

  /// Ekran görüntüleri için önceden doldurulmuş CPU geçmişi.
  final List<double> initialHistory;

  @override
  State<SystemWidget> createState() => _SystemWidgetState();
}

class _SystemWidgetState extends State<SystemWidget> {
  static const _historyLength = 60;

  Timer? _timer;
  SystemSnapshot _snapshot = SystemSnapshot.empty;
  late final List<double> _history = [...widget.initialHistory];

  @override
  void initState() {
    super.initState();
    _refresh();
    if (widget.live) {
      _timer = Timer.periodic(
        const Duration(milliseconds: 1500),
        (_) => _refresh(),
      );
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _refresh() async {
    try {
      final snap = await widget.source.read();
      if (!mounted) return;
      setState(() {
        _snapshot = snap;
        if (widget.live) {
          _history.add(snap.cpu);
          if (_history.length > _historyLength) _history.removeAt(0);
        }
      });
    } catch (_) {
      // Okuma hatası: bir sonraki turda tekrar denenir.
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = _snapshot;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const GlassHeader(icon: Icons.memory_rounded, title: 'Sistem'),
        const SizedBox(height: 10),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '${(s.cpu * 100).round()}',
              style: const TextStyle(
                fontSize: 40,
                height: 1,
                fontWeight: FontWeight.w300,
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(left: 2, bottom: 4),
              child: Text(
                '% CPU',
                style: TextStyle(fontSize: 13, color: GlassColors.soft(0.7)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 46,
          child: CustomPaint(
            painter: SparklinePainter(
              values: _history,
              maxPoints: _historyLength,
            ),
          ),
        ),
        const SizedBox(height: 12),
        _StatRow(
          label: 'RAM',
          detail: '${formatBytes(s.memUsed)} / ${formatBytes(s.memTotal)}',
          value: s.memRatio,
          color: GlassColors.accent,
        ),
        const SizedBox(height: 10),
        _StatRow(
          label: s.diskLabel,
          detail: '${formatBytes(s.diskUsed)} / ${formatBytes(s.diskTotal)}',
          value: s.diskRatio,
          color: GlassColors.accent2,
        ),
        const SizedBox(height: 10),
        if (s.battery != null)
          _StatRow(
            label: s.charging ? 'Pil · şarj oluyor' : 'Pil',
            detail: '%${s.battery}',
            value: s.battery! / 100,
            color: s.battery! <= 20 ? GlassColors.danger : GlassColors.warm,
          )
        else
          _StatRow(
            label: 'Pil',
            detail: 'Fişe takılı',
            value: 1,
            color: GlassColors.warm.withValues(alpha: 0.5),
          ),
      ],
    );
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow({
    required this.label,
    required this.detail,
    required this.value,
    required this.color,
  });

  final String label;
  final String detail;
  final double value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),
            Text(
              detail,
              style: TextStyle(fontSize: 12, color: GlassColors.soft(0.65)),
            ),
          ],
        ),
        const SizedBox(height: 5),
        GlassBar(value: value, color: color),
      ],
    );
  }
}

/// CPU kullanım geçmişi için dolgulu çizgi grafik.
class SparklinePainter extends CustomPainter {
  SparklinePainter({required this.values, required this.maxPoints});

  final List<double> values;
  final int maxPoints;

  @override
  void paint(Canvas canvas, Size size) {
    final grid = Paint()
      ..color = Colors.white.withValues(alpha: 0.07)
      ..strokeWidth = 1;
    for (var i = 1; i < 3; i++) {
      final y = size.height * i / 3;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }
    if (values.length < 2) return;

    final step = size.width / (maxPoints - 1);
    final startX = size.width - step * (values.length - 1);
    final line = Path();
    for (var i = 0; i < values.length; i++) {
      final x = startX + step * i;
      final y = size.height - values[i].clamp(0.0, 1.0) * size.height;
      if (i == 0) {
        line.moveTo(x, y);
      } else {
        line.lineTo(x, y);
      }
    }
    final fill = Path.from(line)
      ..lineTo(size.width, size.height)
      ..lineTo(startX, size.height)
      ..close();

    final rect = Offset.zero & size;
    canvas.drawPath(
      fill,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            GlassColors.accent2.withValues(alpha: 0.35),
            GlassColors.accent2.withValues(alpha: 0.0),
          ],
        ).createShader(rect),
    );
    canvas.drawPath(
      line,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8
        ..strokeJoin = StrokeJoin.round
        ..color = GlassColors.accent2,
    );
  }

  @override
  bool shouldRepaint(SparklinePainter oldDelegate) => true;
}
