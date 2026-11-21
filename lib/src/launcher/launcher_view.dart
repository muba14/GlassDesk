import 'package:material_ui/material_ui.dart';

import '../config.dart';
import '../glass_panel.dart';
import '../theme.dart';
import '../widget_kind.dart';

/// Kontrol panelinin görünümü (mantıktan bağımsız; testlerde ve ekran
/// görüntülerinde doğrudan kullanılır).
class LauncherView extends StatelessWidget {
  const LauncherView({
    super.key,
    required this.enabled,
    required this.running,
    required this.layer,
    required this.blur,
    required this.blurSupported,
    required this.tint,
    required this.translucent,
    required this.onToggle,
    required this.onAll,
    required this.onLayer,
    required this.onBlur,
    required this.onTint,
    required this.onTintEnd,
    required this.onMinimize,
    required this.onClose,
    this.titleBarWrapper,
  });

  final Map<WidgetKind, bool> enabled;
  final Map<WidgetKind, bool> running;
  final WindowLayer layer;
  final bool blur;
  final bool blurSupported;
  final double tint;
  final bool translucent;
  final void Function(WidgetKind kind, bool value) onToggle;
  final ValueChanged<bool> onAll;
  final ValueChanged<WindowLayer> onLayer;
  final ValueChanged<bool> onBlur;
  final ValueChanged<double> onTint;
  final ValueChanged<double> onTintEnd;
  final VoidCallback onMinimize;
  final VoidCallback onClose;
  final Widget Function(Widget child)? titleBarWrapper;

  @override
  Widget build(BuildContext context) {
    final allOn = WidgetKind.values.every((k) => enabled[k] ?? false);
    final titleBar = Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.asset('assets/icon/icon.png', width: 30, height: 30),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'GlassDesk',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.3,
              ),
            ),
          ),
          _WindowButton(
            icon: Icons.remove_rounded,
            tooltip: 'Küçült',
            onTap: onMinimize,
          ),
          const SizedBox(width: 4),
          _WindowButton(
            icon: Icons.close_rounded,
            tooltip: 'Paneli kapat',
            onTap: onClose,
            danger: true,
          ),
        ],
      ),
    );

    return GlassPanel(
      translucent: translucent,
      tint: tint,
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          titleBarWrapper?.call(titleBar) ?? titleBar,
          Text(
            'Masaüstün için cam efektli, yüzen widget\'lar',
            style: TextStyle(fontSize: 13, color: GlassColors.soft(0.6)),
          ),
          const SizedBox(height: 16),
          _SectionTitle(
            title: 'Widget\'lar',
            trailing: TextButton(
              onPressed: () => onAll(!allOn),
              style: TextButton.styleFrom(
                foregroundColor: GlassColors.accent2,
                visualDensity: VisualDensity.compact,
              ),
              child: Text(allOn ? 'Hepsini kapat' : 'Hepsini aç'),
            ),
          ),
          const SizedBox(height: 6),
          for (final kind in WidgetKind.values) ...[
            _WidgetCard(
              kind: kind,
              enabled: enabled[kind] ?? false,
              running: running[kind] ?? false,
              onChanged: (v) => onToggle(kind, v),
            ),
            const SizedBox(height: 8),
          ],
          const SizedBox(height: 8),
          const _SectionTitle(title: 'Görünüm'),
          const SizedBox(height: 10),
          const _Label('Katman'),
          const SizedBox(height: 6),
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<WindowLayer>(
              expandedInsets: EdgeInsets.zero,
              showSelectedIcon: false,
              style: SegmentedButton.styleFrom(
                visualDensity: VisualDensity.compact,
                selectedBackgroundColor:
                    GlassColors.accent.withValues(alpha: 0.35),
                selectedForegroundColor: Colors.white,
                foregroundColor: GlassColors.soft(0.7),
                side: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
              ),
              segments: [
                for (final l in WindowLayer.values)
                  ButtonSegment(
                    value: l,
                    label: Text(l.label, style: const TextStyle(fontSize: 12)),
                  ),
              ],
              selected: {layer},
              onSelectionChanged: (s) => onLayer(s.first),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: _Label(
                  'Bulanık cam (akrilik)',
                  hint: blurSupported ? null : 'Yalnızca Windows\'ta',
                ),
              ),
              Switch(
                value: blur && blurSupported,
                onChanged: blurSupported ? onBlur : null,
                activeTrackColor: GlassColors.accent,
              ),
            ],
          ),
          Row(
            children: [
              const _Label('Cam koyuluğu'),
              Expanded(
                child: Slider(
                  value: tint.clamp(0.0, 1.0),
                  onChanged: onTint,
                  onChangeEnd: onTintEnd,
                  activeColor: GlassColors.accent2,
                  inactiveColor: Colors.white.withValues(alpha: 0.15),
                ),
              ),
            ],
          ),
          const Spacer(),
          Row(
            children: [
              Icon(Icons.info_outline_rounded,
                  size: 14, color: GlassColors.soft(0.45)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Paneli kapatsan da widget\'lar açık kalır. Bir widget\'a '
                  'sağ tıklayarak paneli yeniden açabilirsin.',
                  style: TextStyle(fontSize: 11, color: GlassColors.soft(0.45)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 28,
      child: Row(
        children: [
          Expanded(
            child: Text(
              trUpper(title),
              style: TextStyle(
                fontSize: 11,
                letterSpacing: 1.4,
                fontWeight: FontWeight.w700,
                color: GlassColors.soft(0.55),
              ),
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text, {this.hint});

  final String text;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(text, style: const TextStyle(fontSize: 13)),
        if (hint != null)
          Text(
            hint!,
            style: TextStyle(fontSize: 11, color: GlassColors.soft(0.45)),
          ),
      ],
    );
  }
}

class _WidgetCard extends StatelessWidget {
  const _WidgetCard({
    required this.kind,
    required this.enabled,
    required this.running,
    required this.onChanged,
  });

  final WidgetKind kind;
  final bool enabled;
  final bool running;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final on = enabled && running;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: enabled ? 0.09 : 0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Colors.white.withValues(alpha: enabled ? 0.14 : 0.06),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(11),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  GlassColors.accent.withValues(alpha: enabled ? 0.55 : 0.2),
                  GlassColors.accent2.withValues(alpha: enabled ? 0.45 : 0.15),
                ],
              ),
            ),
            child: Icon(kind.icon, size: 20, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  kind.title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: on
                            ? const Color(0xFF5BE38F)
                            : GlassColors.soft(0.3),
                      ),
                    ),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        on ? 'Açık · ${kind.description}' : kind.description,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11.5,
                          color: GlassColors.soft(0.55),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Switch(
            value: enabled,
            onChanged: onChanged,
            activeTrackColor: GlassColors.accent,
          ),
        ],
      ),
    );
  }
}

class _WindowButton extends StatelessWidget {
  const _WindowButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.danger = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          hoverColor: danger
              ? GlassColors.danger.withValues(alpha: 0.6)
              : Colors.white.withValues(alpha: 0.12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: Icon(icon, size: 16),
          ),
        ),
      ),
    );
  }
}
