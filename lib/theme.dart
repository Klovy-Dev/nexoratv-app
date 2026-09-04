import 'package:flutter/material.dart';

/// Dégradé signature Nexora (rose → violet → bleu), repris du logo.
const nexoraGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [Color(0xFFE8348C), Color(0xFF8B5CF6), Color(0xFF2D7DF6)],
);

const nexoraPink = Color(0xFFE8348C);
const nexoraPurple = Color(0xFF8B5CF6);
const nexoraBlue = Color(0xFF2D7DF6);

/// Modes de thème proposés. Un 3ᵉ thème « premium » viendra plus tard ; en
/// attendant l'UI affiche une option « Bientôt disponible » désactivée.
enum AppThemeMode { dark, light }

ThemeData buildAppTheme(AppThemeMode mode) {
  final isLight = mode == AppThemeMode.light;
  final brightness = isLight ? Brightness.light : Brightness.dark;

  final scaffold =
      isLight ? const Color(0xFFF4F5F8) : const Color(0xFF0D0E13);
  final surface = isLight ? Colors.white : const Color(0xFF161821);
  final surfaceHi =
      isLight ? const Color(0xFFE9EAF0) : const Color(0xFF20222E);

  final scheme = ColorScheme.fromSeed(
    seedColor: nexoraPurple,
    brightness: brightness,
  ).copyWith(
    primary: nexoraPurple,
    secondary: nexoraPink,
    tertiary: nexoraBlue,
    surface: surface,
    surfaceContainerHighest: surfaceHi,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: scaffold,
    visualDensity: VisualDensity.standard,
    cardTheme: CardThemeData(
      clipBehavior: Clip.antiAlias,
      color: surface,
      elevation: 0,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: scaffold,
      surfaceTintColor: Colors.transparent,
      centerTitle: false,
      elevation: 0,
    ),
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: scaffold,
      indicatorColor: nexoraPurple.withValues(alpha: .22),
      selectedIconTheme: const IconThemeData(color: nexoraPurple),
      selectedLabelTextStyle: const TextStyle(
          color: nexoraPurple, fontWeight: FontWeight.w600),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: surface,
      indicatorColor: nexoraPurple.withValues(alpha: .22),
      labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
    ),
    inputDecorationTheme: InputDecorationTheme(
      isDense: true,
      filled: true,
      fillColor: surfaceHi,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
    ),
    chipTheme: ChipThemeData(
      selectedColor: nexoraPurple.withValues(alpha: .28),
      side: BorderSide.none,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
    ),
    listTileTheme: const ListTileThemeData(
      dense: true,
      minVerticalPadding: 6,
    ),
    sliderTheme: const SliderThemeData(
      activeTrackColor: nexoraPink,
      thumbColor: nexoraPink,
      overlayColor: Color(0x33E8348C),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: nexoraPink,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: nexoraPurple,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
  );
}
