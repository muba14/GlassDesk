import 'package:material_ui/material_ui.dart';

import 'theme.dart';

/// Cam görünümlü yüzey.
///
/// [translucent] true ise arka plan yarı saydamdır (Windows'ta akrilik
/// efektinin üzerine çizilir). False ise pencere saydamlığı olmayan
/// sistemler için koyu, opak bir zemin çizilir.
class GlassPanel extends StatelessWidget {
  const GlassPanel({
    super.key,
    required this.child,
    this.translucent = true,
    this.tint = 0.5,
    this.radius = 8,
    this.padding = const EdgeInsets.all(16),
  });

  final Widget child;
  final bool translucent;
  final double tint;
  final double radius;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final t = tint.clamp(0.0, 1.0);
    final gradient = translucent
        ? LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color.lerp(
                Colors.white.withValues(alpha: 0.18),
                const Color(0xFF0E0C1C).withValues(alpha: 0.55),
                t,
              )!,
              Color.lerp(
                Colors.white.withValues(alpha: 0.06),
                const Color(0xFF0E0C1C).withValues(alpha: 0.75),
                t,
              )!,
            ],
          )
        : const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [GlassColors.opaqueTop, GlassColors.opaqueBottom],
          );

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}

/// Widget'ların içinde kullanılan küçük başlık satırı.
class GlassHeader extends StatelessWidget {
  const GlassHeader({
    super.key,
    required this.icon,
    required this.title,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 15, color: GlassColors.accent2),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            trUpper(title),
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11,
              letterSpacing: 1.4,
              fontWeight: FontWeight.w600,
              color: GlassColors.soft(0.75),
            ),
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}

/// İnce, yuvarlak köşeli ilerleme çubuğu.
class GlassBar extends StatelessWidget {
  const GlassBar({super.key, required this.value, this.color});

  final double value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final v = value.isNaN ? 0.0 : value.clamp(0.0, 1.0);
    final c = color ?? GlassColors.accent;
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: SizedBox(
        height: 6,
        child: Stack(
          fit: StackFit.expand,
          children: [
            ColoredBox(color: Colors.white.withValues(alpha: 0.10)),
            FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: v,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [c.withValues(alpha: 0.75), c],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
