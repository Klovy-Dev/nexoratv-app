import 'package:flutter/material.dart';

/// Charte NexoraTV (identique au site) : fond quasi noir, un seul accent
/// corail, Bricolage Grotesque pour les titres, Manrope pour le texte.
abstract final class Nx {
  static const bg = Color(0xFF0B0C0F);
  static const bgSoft = Color(0xFF111217);
  static const surface = Color(0xFF16171D);
  static const surface2 = Color(0xFF1D1F27);
  static const border = Color(0x17FFFFFF);
  static const borderStrong = Color(0x29FFFFFF);
  static const text = Color(0xFFF5F4F0);
  static const muted = Color(0xFF9A9BA3);
  static const accent = Color(0xFFFF4B3E);
  static const accentStrong = Color(0xFFE63C30);
  static const success = Color(0xFF23C17D);
  static const warning = Color(0xFFFFB02E);
  static const danger = Color(0xFFFF5470);

  static const display = 'Bricolage';
  static const radius = 16.0;
  static const radiusSm = 10.0;
  static const ease = Cubic(0.22, 1, 0.36, 1);
  static const fast = Duration(milliseconds: 220);
}

ThemeData buildTheme() {
  const scheme = ColorScheme.dark(
    primary: Nx.accent,
    onPrimary: Nx.bg,
    secondary: Nx.accent,
    onSecondary: Nx.bg,
    surface: Nx.surface,
    onSurface: Nx.text,
    error: Nx.danger,
    outline: Nx.border,
  );

  final base = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: scheme,
    fontFamily: 'Manrope',
    scaffoldBackgroundColor: Nx.bg,
    splashFactory: InkSparkle.splashFactory,
  );

  TextStyle? display(
    TextStyle? s, {
    double? size,
    FontWeight weight = FontWeight.w700,
  }) => s?.copyWith(
    fontFamily: Nx.display,
    fontWeight: weight,
    fontSize: size,
    color: Nx.text,
    letterSpacing: -0.4,
  );

  final text = base.textTheme.apply(bodyColor: Nx.text, displayColor: Nx.text);
  const stadium = StadiumBorder();
  const padding = EdgeInsets.symmetric(horizontal: 26, vertical: 18);

  // Focus télécommande / clavier : l'ombrage Material par défaut est
  // invisible sur une télé. Contour franc + fond teinté sur tous les boutons.
  WidgetStateProperty<BorderSide?> focusSide(
    BorderSide? normal, {
    Color color = Nx.accent,
  }) => WidgetStateProperty.resolveWith(
    (s) => s.contains(WidgetState.focused)
        ? BorderSide(color: color, width: 2.5)
        : normal,
  );
  WidgetStateProperty<Color?> focusOverlay(
    Color tint,
  ) => WidgetStateProperty.resolveWith((s) {
    if (s.contains(WidgetState.focused)) return tint.withValues(alpha: 0.2);
    if (s.contains(WidgetState.pressed)) return tint.withValues(alpha: 0.14);
    if (s.contains(WidgetState.hovered)) return tint.withValues(alpha: 0.08);
    return null;
  });

  return base.copyWith(
    textTheme: text.copyWith(
      displaySmall: display(text.displaySmall, size: 34),
      headlineMedium: display(text.headlineMedium, size: 28),
      headlineSmall: display(text.headlineSmall, size: 22),
      titleLarge: display(text.titleLarge, size: 19, weight: FontWeight.w600),
      titleMedium: text.titleMedium?.copyWith(fontWeight: FontWeight.w700),
      bodyMedium: text.bodyMedium?.copyWith(height: 1.5),
      bodySmall: text.bodySmall?.copyWith(color: Nx.muted),
    ),
    dividerTheme: const DividerThemeData(
      color: Nx.border,
      space: 1,
      thickness: 1,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style:
          FilledButton.styleFrom(
            backgroundColor: Nx.accent,
            foregroundColor: Nx.bg,
            disabledBackgroundColor: Nx.accent.withValues(alpha: 0.4),
            shape: stadium,
            padding: padding,
            textStyle: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 15,
              fontFamily: 'Manrope',
            ),
          ).copyWith(
            // Bouton corail : contour blanc pour trancher sur le fond du bouton.
            side: focusSide(null, color: Nx.text),
            overlayColor: focusOverlay(Colors.white),
          ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style:
          OutlinedButton.styleFrom(
            foregroundColor: Nx.text,
            shape: stadium,
            padding: padding,
            textStyle: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 15,
              fontFamily: 'Manrope',
            ),
          ).copyWith(
            side: focusSide(const BorderSide(color: Nx.borderStrong)),
            overlayColor: focusOverlay(Nx.accent),
          ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: Nx.accent,
        shape: stadium,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      ).copyWith(side: focusSide(null), overlayColor: focusOverlay(Nx.accent)),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: ButtonStyle(
        side: focusSide(null),
        overlayColor: focusOverlay(Nx.accent),
      ),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(overlayColor: focusOverlay(Nx.text)),
    ),
    switchTheme: SwitchThemeData(
      // Contour blanc autour de l'interrupteur qui a le focus.
      trackOutlineColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.focused) ? Nx.text : null,
      ),
      trackOutlineWidth: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.focused) ? 3 : null,
      ),
      overlayColor: focusOverlay(Nx.accent),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Nx.bgSoft,
      hintStyle: const TextStyle(color: Nx.muted),
      labelStyle: const TextStyle(color: Nx.muted),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(Nx.radiusSm),
        borderSide: const BorderSide(color: Nx.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(Nx.radiusSm),
        borderSide: const BorderSide(color: Nx.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(Nx.radiusSm),
        borderSide: const BorderSide(color: Nx.accent, width: 1.4),
      ),
    ),
    snackBarTheme: const SnackBarThemeData(
      backgroundColor: Nx.surface2,
      contentTextStyle: TextStyle(color: Nx.text, fontFamily: 'Manrope'),
      behavior: SnackBarBehavior.floating,
    ),
    scrollbarTheme: ScrollbarThemeData(
      thumbColor: WidgetStatePropertyAll(Colors.white.withValues(alpha: 0.18)),
      radius: const Radius.circular(8),
      thickness: const WidgetStatePropertyAll(6),
    ),
    tooltipTheme: const TooltipThemeData(
      decoration: BoxDecoration(
        color: Nx.surface2,
        borderRadius: BorderRadius.all(Radius.circular(8)),
      ),
      textStyle: TextStyle(color: Nx.text, fontSize: 12),
    ),
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.windows: FadeForwardsPageTransitionsBuilder(),
        TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
      },
    ),
  );
}
