import 'package:flutter/widgets.dart';
import 'package:google_fonts/google_fonts.dart';

/// Tipografia refinada baseada em Inter (métricas próximas de SF Pro,
/// com excelente suporte a números tabulares — essencial para valores
/// em R$ que mudam sem "dançar" de largura).
class AppTypography {
  AppTypography._();

  static TextStyle _base({
    required double size,
    required FontWeight weight,
    double? letterSpacing,
    double? height,
  }) {
    return GoogleFonts.inter(
      fontSize: size,
      fontWeight: weight,
      letterSpacing: letterSpacing,
      height: height,
    );
  }

  /// Números grandes de destaque (ex.: "Disponível para gastar").
  static TextStyle get displayAmount => _base(
        size: 44,
        weight: FontWeight.w700,
        letterSpacing: -1.2,
        height: 1.05,
      );

  static TextStyle get amountLarge => _base(
        size: 32,
        weight: FontWeight.w700,
        letterSpacing: -0.6,
        height: 1.1,
      );

  static TextStyle get amountMedium => _base(
        size: 22,
        weight: FontWeight.w600,
        letterSpacing: -0.3,
      );

  static TextStyle get title => _base(
        size: 20,
        weight: FontWeight.w600,
        letterSpacing: -0.2,
      );

  static TextStyle get subtitle => _base(
        size: 17,
        weight: FontWeight.w500,
      );

  static TextStyle get body => _base(
        size: 15,
        weight: FontWeight.w400,
        height: 1.4,
      );

  static TextStyle get bodyEmphasis => _base(
        size: 15,
        weight: FontWeight.w600,
      );

  static TextStyle get caption => _base(
        size: 13,
        weight: FontWeight.w400,
        height: 1.3,
      );

  static TextStyle get captionEmphasis => _base(
        size: 13,
        weight: FontWeight.w600,
      );

  static TextStyle get overline => _base(
        size: 11,
        weight: FontWeight.w600,
        letterSpacing: 0.6,
      );
}
