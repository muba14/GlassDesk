import 'dart:async';
import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../../storage.dart';
import '../../theme.dart';
import 'calendar.dart';

/// Saat + aylık takvim widget'ı. Saate tıklayınca dijital/analog arasında
/// geçiş yapar; takvimde oklarla aylar arasında gezilir.
class ClockWidget extends StatefulWidget {
  const ClockWidget({
    super.key,
    this.now,
    this.live = true,
    this.store,
    this.initialAnalog = false,
  });

  /// Testler ve ekran görüntüleri için sabit saat.
  final DateTime Function()? now;

  /// false ise zamanlayıcı çalışmaz (testler için).
  final bool live;

  final JsonFile? store;
  final bool initialAnalog;

  @override
  State<ClockWidget> createState() => _ClockWidgetState();
}

class _ClockWidgetState extends State<ClockWidget> {
  Timer? _timer;
  late bool _analog;
  int _monthOffset = 0;

  DateTime get _now => widget.now?.call() ?? DateTime.now();

  @override
  void initState() {
    super.initState();
    final saved = widget.store?.read()['analog'];
    _analog = saved is bool ? saved : widget.initialAnalog;
    if (widget.live) {
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _toggleMode() {
    setState(() => _analog = !_analog);
    widget.store?.update((data) => data['analog'] = _analog);
  }

  @override
  Widget build(BuildContext context) {
    final now = _now;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          trUpper(TrDate.day(now)),
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12,
            letterSpacing: 3,
            fontWeight: FontWeight.w600,
            color: GlassColors.accent2.withValues(alpha: 0.9),
          ),
        ),
        const SizedBox(height: 4),
        MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            onTap: _toggleMode,
            child: SizedBox(
              height: 118,
              child: Center(
                child: _analog
                    ? SizedBox.square(
                        dimension: 112,
                        child: CustomPaint(painter: AnalogClockPainter(now)),
                      )
                    : FittedBox(
                        fit: BoxFit.scaleDown,
                        child: _DigitalTime(now: now),
                      ),
              ),
            ),
          ),
        ),
        Text(
          TrDate.longDate(now),
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14, color: GlassColors.soft(0.8)),
        ),
        const SizedBox(height: 12),
        Divider(height: 1, color: Colors.white.withValues(alpha: 0.12)),
        const SizedBox(height: 10),
        Expanded(
          child: _MonthCalendar(
            today: now,
            offset: _monthOffset,
            onPrev: () => setState(() => _monthOffset--),
            onNext: () => setState(() => _monthOffset++),
            onReset: () => setState(() => _monthOffset = 0),
          ),
        ),
      ],
    );
  }
}

class _DigitalTime extends StatelessWidget {
  const _DigitalTime({required this.now});

  final DateTime now;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          '${TrDate.two(now.hour)}:${TrDate.two(now.minute)}',
          style: const TextStyle(
            fontSize: 68,
            height: 1,
            fontWeight: FontWeight.w300,
            letterSpacing: -1,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            TrDate.two(now.second),
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: GlassColors.accent,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ),
      ],
    );
  }
}

class _MonthCalendar extends StatelessWidget {
  const _MonthCalendar({
    required this.today,
    required this.offset,
    required this.onPrev,
    required this.onNext,
    required this.onReset,
  });

  final DateTime today;
  final int offset;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    final shown = DateTime(today.year, today.month + offset, 1);
    final cells = monthGrid(shown.year, shown.month);
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: onReset,
                child: Text(
                  '${TrDate.month(shown.month)} ${shown.year}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            _SmallIconButton(icon: Icons.chevron_left_rounded, onTap: onPrev),
            _SmallIconButton(icon: Icons.chevron_right_rounded, onTap: onNext),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            for (final d in TrDate.shortDays)
              Expanded(
                child: Text(
                  d,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: GlassColors.soft(0.5),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        for (var row = 0; row < cells.length ~/ 7; row++)
          Expanded(
            child: Row(
              children: [
                for (var col = 0; col < 7; col++)
                  Expanded(
                    child: _DayCell(
                      date: cells[row * 7 + col],
                      today: today,
                      weekend: col >= 5,
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.date,
    required this.today,
    required this.weekend,
  });

  final DateTime? date;
  final DateTime today;
  final bool weekend;

  @override
  Widget build(BuildContext context) {
    final d = date;
    if (d == null) return const SizedBox.shrink();
    final isToday = isSameDay(d, today);
    return Center(
      child: Container(
        width: 26,
        height: 26,
        alignment: Alignment.center,
        decoration: isToday
            ? const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [GlassColors.accent, GlassColors.accent2],
                ),
              )
            : null,
        child: Text(
          '${d.day}',
          style: TextStyle(
            fontSize: 12,
            fontWeight: isToday ? FontWeight.w700 : FontWeight.w400,
            color: isToday
                ? const Color(0xFF15132A)
                : weekend
                    ? GlassColors.accent.withValues(alpha: 0.9)
                    : GlassColors.soft(0.85),
          ),
        ),
      ),
    );
  }
}

class _SmallIconButton extends StatelessWidget {
  const _SmallIconButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkResponse(
      onTap: onTap,
      radius: 16,
      child: Padding(
        padding: const EdgeInsets.all(2),
        child: Icon(icon, size: 20, color: GlassColors.soft(0.8)),
      ),
    );
  }
}

/// Analog saat çizimi.
class AnalogClockPainter extends CustomPainter {
  AnalogClockPainter(this.time);

  final DateTime time;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final r = size.shortestSide / 2;

    canvas.drawCircle(
      center,
      r,
      Paint()..color = Colors.white.withValues(alpha: 0.06),
    );
    canvas.drawCircle(
      center,
      r - 1,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = Colors.white.withValues(alpha: 0.25),
    );

    for (var i = 0; i < 60; i++) {
      final major = i % 5 == 0;
      final angle = i * math.pi / 30;
      final outer = r - 6;
      final inner = outer - (major ? 7 : 3);
      final dir = Offset(math.sin(angle), -math.cos(angle));
      canvas.drawLine(
        center + dir * inner,
        center + dir * outer,
        Paint()
          ..strokeWidth = major ? 2 : 1
          ..strokeCap = StrokeCap.round
          ..color = Colors.white.withValues(alpha: major ? 0.7 : 0.25),
      );
    }

    void hand(double angle, double length, double width, Color color) {
      final dir = Offset(math.sin(angle), -math.cos(angle));
      canvas.drawLine(
        center - dir * 6,
        center + dir * length,
        Paint()
          ..strokeWidth = width
          ..strokeCap = StrokeCap.round
          ..color = color,
      );
    }

    final seconds = time.second;
    final minutes = time.minute + seconds / 60;
    final hours = (time.hour % 12) + minutes / 60;

    hand(hours * math.pi / 6, r * 0.5, 4, Colors.white);
    hand(minutes * math.pi / 30, r * 0.72, 3, Colors.white.withValues(alpha: 0.9));
    hand(seconds * math.pi / 30, r * 0.8, 1.4, GlassColors.accent2);
    canvas.drawCircle(center, 3.5, Paint()..color = GlassColors.accent);
  }

  @override
  bool shouldRepaint(AnalogClockPainter oldDelegate) =>
      oldDelegate.time != time;
}
