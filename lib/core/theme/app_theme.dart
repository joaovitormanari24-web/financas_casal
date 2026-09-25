import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'app_spacing.dart';
import 'app_typography.dart';

/// Constrói os [ThemeData] light e dark a partir da paleta do design
/// system. Mantém a superfície do Material mínima — a personalidade do
/// app vem dos widgets do design system (lib/shared/widgets), não de
/// componentes Material padrão.
class AppTheme {
  AppTheme._();

  static ThemeData light() => _build(AppColors.light, Brightness.light);
  static ThemeData dark() => _build(AppColors.dark, Brightness.dark);

  static ThemeData _build(AppPalette palette, Brightness brightness) {
    final colorScheme = brightness == Brightness.light
        ? ColorScheme.light(
            primary: palette.accent,
            onPrimary: palette.background,
            surface: palette.surface,
            onSurface: palette.textPrimary,
            error: palette.warning,
          )
        : ColorScheme.dark(
            primary: palette.accent,
            onPrimary: palette.background,
            surface: palette.surface,
            onSurface: palette.textPrimary,
            error: palette.warning,
          );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: palette.background,
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
      textTheme: TextTheme(
        displayLarge: AppTypography.displayAmount.copyWith(
          color: palette.textPrimary,
        ),
        headlineMedium: AppTypography.title.copyWith(
          color: palette.textPrimary,
        ),
        titleMedium: AppTypography.subtitle.copyWith(
          color: palette.textPrimary,
        ),
        bodyLarge: AppTypography.body.copyWith(color: palette.textPrimary),
        bodyMedium: AppTypography.body.copyWith(color: palette.textSecondary),
        labelSmall: AppTypography.overline.copyWith(
          color: palette.textTertiary,
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: palette.background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        foregroundColor: palette.textPrimary,
        titleTextStyle: AppTypography.title.copyWith(
          color: palette.textPrimary,
        ),
      ),
      cardTheme: CardThemeData(
        color: palette.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          side: BorderSide(color: palette.borderSubtle),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: palette.surfaceElevated,
        modalBackgroundColor: palette.surfaceElevated,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: palette.borderSubtle,
        thickness: 1,
        space: 1,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: palette.textPrimary,
          foregroundColor: palette.background,
          elevation: 0,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.sm + 2,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.pill),
          ),
          textStyle: AppTypography.bodyEmphasis,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: palette.accent,
          textStyle: AppTypography.bodyEmphasis,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: palette.backgroundSecondary,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm + 2,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide.none,
        ),
        hintStyle: AppTypography.body.copyWith(color: palette.textTertiary),
      ),
    );
  }
}
