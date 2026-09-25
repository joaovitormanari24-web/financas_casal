/// Escala de espaçamento do design system. Uso consistente evita a
/// aparência "genérica" — sempre espaçar a partir desta escala, nunca
/// com valores soltos.
class AppSpacing {
  AppSpacing._();

  static const double xxs = 4;
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;
  static const double xxxl = 64;

  /// Margem lateral padrão das telas.
  static const double screenPadding = 20;
}

class AppRadius {
  AppRadius._();

  static const double sm = 12;
  static const double md = 16;
  static const double lg = 20;
  static const double xl = 28;
  static const double pill = 999;
}
