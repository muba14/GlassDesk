import 'package:material_ui/material_ui.dart';

/// GlassDesk renkleri ve tema.
class GlassColors {
  GlassColors._();

  static const accent = Color(0xFF9D8CFF);
  static const accent2 = Color(0xFF5CE1E6);
  static const warm = Color(0xFFFFB86B);
  static const danger = Color(0xFFFF6B8B);
  static const text = Colors.white;

  static Color soft([double alpha = 0.7]) =>
      Colors.white.withValues(alpha: alpha);

  static const opaqueTop = Color(0xFF2B2742);
  static const opaqueBottom = Color(0xFF17162A);
}

ThemeData buildGlassTheme({String? fontFamily}) {
  final base = ThemeData(
    brightness: Brightness.dark,
    useMaterial3: true,
    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    visualDensity: VisualDensity.compact,
    fontFamily: fontFamily,
    colorScheme: ColorScheme.fromSeed(
      seedColor: GlassColors.accent,
      brightness: Brightness.dark,
    ),
  );
  return base.copyWith(
    scaffoldBackgroundColor: Colors.transparent,
    canvasColor: Colors.transparent,
    textTheme: base.textTheme.apply(
      bodyColor: GlassColors.text,
      displayColor: GlassColors.text,
    ),
    iconTheme: const IconThemeData(color: GlassColors.text),
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: GlassColors.accent2,
      selectionColor: GlassColors.accent.withValues(alpha: 0.35),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: const Color(0xF0221F35),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      textStyle: const TextStyle(color: Colors.white, fontSize: 13),
    ),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        color: const Color(0xF0221F35),
        borderRadius: BorderRadius.circular(8),
      ),
      textStyle: const TextStyle(color: Colors.white, fontSize: 12),
    ),
  );
}

/// Türkçe kurallarıyla büyük harf: i → İ, ı → I.
String trUpper(String s) =>
    s.replaceAll('i', 'İ').replaceAll('ı', 'I').toUpperCase();
