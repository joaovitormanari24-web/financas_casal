import 'package:flutter/cupertino.dart';

/// Paleta do design system. Premium, minimalista, inspirada em iOS.
/// Cada cor existe em variante light e dark — use [AppColors.of] para
/// resolver a variante correta a partir do [BuildContext].
class AppPalette {
  const AppPalette({
    required this.background,
    required this.backgroundSecondary,
    required this.surface,
    required this.surfaceElevated,
    required this.border,
    required this.borderSubtle,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.accent,
    required this.accentMuted,
    required this.income,
    required this.expense,
    required this.pending,
    required this.saved,
    required this.warning,
    required this.overlayScrim,
  });

  final Color background;
  final Color backgroundSecondary;
  final Color surface;
  final Color surfaceElevated;
  final Color border;
  final Color borderSubtle;
  final Color textPrimary;
  final Color textSecondary;
  final Color textTertiary;
  final Color accent;
  final Color accentMuted;
  final Color income;
  final Color expense;
  final Color pending;
  final Color saved;
  final Color warning;
  final Color overlayScrim;
}

class AppColors {
  AppColors._();

  // Acento de marca: verde-petróleo sofisticado — remete a crescimento e
  // confiança sem cair no clichê do verde-dinheiro saturado.
  static const Color _brand = Color(0xFF1F6F5C);
  static const Color _brandLight = Color(0xFF2E8B75);

  static const AppPalette light = AppPalette(
    background: Color(0xFFFAFAF8),
    backgroundSecondary: Color(0xFFF2F1EE),
    surface: Color(0xFFFFFFFF),
    surfaceElevated: Color(0xFFFFFFFF),
    border: Color(0xFFE4E2DD),
    borderSubtle: Color(0xFFEDEBE6),
    textPrimary: Color(0xFF1A1D1B),
    textSecondary: Color(0xFF6B6E6B),
    textTertiary: Color(0xFFA1A39F),
    accent: _brand,
    accentMuted: Color(0xFFE3EDE9),
    income: Color(0xFF1F6F5C),
    expense: Color(0xFF3A3A3A),
    pending: Color(0xFFB8862F),
    saved: Color(0xFF2E6B8F),
    warning: Color(0xFFC0562F),
    overlayScrim: Color(0x66000000),
  );

  static const AppPalette dark = AppPalette(
    background: Color(0xFF0B0D0C),
    backgroundSecondary: Color(0xFF121412),
    surface: Color(0xFF171917),
    surfaceElevated: Color(0xFF1E211E),
    border: Color(0xFF2A2D2A),
    borderSubtle: Color(0xFF212421),
    textPrimary: Color(0xFFF5F5F3),
    textSecondary: Color(0xFFA3A6A1),
    textTertiary: Color(0xFF6D706C),
    accent: _brandLight,
    accentMuted: Color(0xFF1B2B26),
    income: Color(0xFF3FA98A),
    expense: Color(0xFFD8D6D0),
    pending: Color(0xFFE0A94E),
    saved: Color(0xFF5FA3CC),
    warning: Color(0xFFE07C4E),
    overlayScrim: Color(0x99000000),
  );

  static AppPalette of(BuildContext context) {
    final brightness = MediaQuery.platformBrightnessOf(context);
    return brightness == Brightness.dark ? dark : light;
  }
}
