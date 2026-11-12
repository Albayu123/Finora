import 'package:flutter/material.dart';

/// Palet warna Finora yang telah diverifikasi memenuhi kontras WCAG AA.
class FinoraColors extends ThemeExtension<FinoraColors> {
  const FinoraColors({
    required this.background,
    required this.surface,
    required this.surfaceMuted,
    required this.textPrimary,
    required this.textSecondary,
    required this.accent,
    required this.onAccent,
    required this.income,
    required this.incomeSurface,
    required this.expense,
    required this.expenseSurface,
    required this.unsynced,
    required this.unsyncedSurface,
    required this.borderStrong,
    required this.divider,
  });

  final Color background;
  final Color surface;
  final Color surfaceMuted;
  final Color textPrimary;
  final Color textSecondary;
  final Color accent;
  final Color onAccent;
  final Color income;
  final Color incomeSurface;
  final Color expense;
  final Color expenseSurface;
  final Color unsynced;
  final Color unsyncedSurface;
  final Color borderStrong;
  final Color divider;

  static const FinoraColors light = FinoraColors(
    background: Color(0xFFF8F7F4),
    surface: Color(0xFFFFFFFF),
    surfaceMuted: Color(0xFFEFECE6),
    textPrimary: Color(0xFF17191C),
    textSecondary: Color(0xFF525860),
    accent: Color(0xFF0F5C46),
    onAccent: Color(0xFFFFFFFF),
    income: Color(0xFF0F5C46),
    incomeSurface: Color(0xFFE6F2EE),
    expense: Color(0xFFA82924),
    expenseSurface: Color(0xFFFCECEB),
    unsynced: Color(0xFF8A5300),
    unsyncedSurface: Color(0xFFFEF3C7),
    borderStrong: Color(0xFF85837B),
    divider: Color(0xFFE2DFD7),
  );

  static const FinoraColors dark = FinoraColors(
    background: Color(0xFF111315),
    surface: Color(0xFF1A1D21),
    surfaceMuted: Color(0xFF24282E),
    textPrimary: Color(0xFFF2F1ED),
    textSecondary: Color(0xFFA5ABB3),
    accent: Color(0xFF34B38A),
    onAccent: Color(0xFF0B2920),
    income: Color(0xFF5ED3AA),
    incomeSurface: Color(0xFF162C24),
    expense: Color(0xFFF27A74),
    expenseSurface: Color(0xFF331D1C),
    unsynced: Color(0xFFF5B942),
    unsyncedSurface: Color(0xFF302612),
    borderStrong: Color(0xFF7A828E),
    divider: Color(0xFF2B3038),
  );

  @override
  FinoraColors copyWith({
    Color? background,
    Color? surface,
    Color? surfaceMuted,
    Color? textPrimary,
    Color? textSecondary,
    Color? accent,
    Color? onAccent,
    Color? income,
    Color? incomeSurface,
    Color? expense,
    Color? expenseSurface,
    Color? unsynced,
    Color? unsyncedSurface,
    Color? borderStrong,
    Color? divider,
  }) {
    return FinoraColors(
      background: background ?? this.background,
      surface: surface ?? this.surface,
      surfaceMuted: surfaceMuted ?? this.surfaceMuted,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      accent: accent ?? this.accent,
      onAccent: onAccent ?? this.onAccent,
      income: income ?? this.income,
      incomeSurface: incomeSurface ?? this.incomeSurface,
      expense: expense ?? this.expense,
      expenseSurface: expenseSurface ?? this.expenseSurface,
      unsynced: unsynced ?? this.unsynced,
      unsyncedSurface: unsyncedSurface ?? this.unsyncedSurface,
      borderStrong: borderStrong ?? this.borderStrong,
      divider: divider ?? this.divider,
    );
  }

  @override
  FinoraColors lerp(ThemeExtension<FinoraColors>? other, double t) {
    if (other is! FinoraColors) return this;
    return FinoraColors(
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceMuted: Color.lerp(surfaceMuted, other.surfaceMuted, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      onAccent: Color.lerp(onAccent, other.onAccent, t)!,
      income: Color.lerp(income, other.income, t)!,
      incomeSurface: Color.lerp(incomeSurface, other.incomeSurface, t)!,
      expense: Color.lerp(expense, other.expense, t)!,
      expenseSurface: Color.lerp(expenseSurface, other.expenseSurface, t)!,
      unsynced: Color.lerp(unsynced, other.unsynced, t)!,
      unsyncedSurface: Color.lerp(unsyncedSurface, other.unsyncedSurface, t)!,
      borderStrong: Color.lerp(borderStrong, other.borderStrong, t)!,
      divider: Color.lerp(divider, other.divider, t)!,
    );
  }
}

/// Tema Material 3 Finora untuk mode terang dan gelap.
class AppTheme {
  static ThemeData buildTheme(FinoraColors palette, Brightness brightness) {
    final colorScheme = ColorScheme(
      brightness: brightness,
      primary: palette.accent,
      onPrimary: palette.onAccent,
      secondary: palette.accent,
      onSecondary: palette.onAccent,
      error: palette.expense,
      onError: palette.surface,
      surface: palette.surface,
      onSurface: palette.textPrimary,
      outline: palette.borderStrong,
      outlineVariant: palette.divider,
      surfaceContainerHighest: palette.surfaceMuted,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: palette.background,
      dividerColor: palette.divider,
      extensions: [palette],
      appBarTheme: AppBarTheme(
        backgroundColor: palette.background,
        foregroundColor: palette.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      cardTheme: CardThemeData(
        color: palette.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: palette.divider),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: palette.surface,
        labelStyle: TextStyle(color: palette.textSecondary),
        hintStyle: TextStyle(color: palette.textSecondary),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: palette.borderStrong),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: palette.borderStrong),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: palette.accent, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: palette.expense, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: palette.expense, width: 2),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: palette.accent,
          foregroundColor: palette.onAccent,
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: palette.textPrimary,
          side: BorderSide(color: palette.borderStrong),
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: palette.accent,
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
    );
  }
}

extension FinoraThemeBuildContext on BuildContext {
  FinoraColors get finoraColors =>
      Theme.of(this).extension<FinoraColors>() ?? FinoraColors.light;
}
