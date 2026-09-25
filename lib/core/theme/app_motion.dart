import 'package:flutter/animation.dart';
import 'package:flutter/scheduler.dart';

/// Centraliza durações e curvas de animação para manter as microinterações
/// consistentes em todo o app. Toda animação deve comunicar algo — nunca
/// decorativa por si só (ver briefing, seção 5).
class AppMotion {
  AppMotion._();

  static const Duration instant = Duration(milliseconds: 120);
  static const Duration fast = Duration(milliseconds: 220);
  static const Duration medium = Duration(milliseconds: 380);
  static const Duration slow = Duration(milliseconds: 600);
  static const Duration numberCountUp = Duration(milliseconds: 700);

  /// Curva "mola" suave usada em bottom sheets e transições físicas.
  static const Curve spring = Curves.easeOutCubic;
  static const Curve enter = Curves.easeOutQuart;
  static const Curve exit = Curves.easeInCubic;
  static const Curve elastic = Curves.elasticOut;

  /// Respeita a preferência de "Reduzir movimento" do sistema (briefing,
  /// seção 5). Widgets de animação devem consultar isto antes de animar.
  static bool reduceMotionEnabled() {
    return SchedulerBinding.instance.platformDispatcher.accessibilityFeatures
        .disableAnimations;
  }

  static Duration resolve(Duration duration) {
    return reduceMotionEnabled() ? Duration.zero : duration;
  }
}
