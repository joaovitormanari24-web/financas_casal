import 'package:flutter/services.dart';

/// Feedback tátil discreto e consistente (briefing, seções 4 e 64).
/// Centralizado aqui para nunca espalhar chamadas diretas a
/// [HapticFeedback] pelas telas.
class Haptics {
  Haptics._();

  static void tapLight() => HapticFeedback.selectionClick();

  static void tapMedium() => HapticFeedback.lightImpact();

  static void success() => HapticFeedback.mediumImpact();

  static void warning() => HapticFeedback.heavyImpact();
}
