import 'package:flutter/material.dart';

import 'app_motion.dart';

/// Transição padrão de navegação — leve slide-up + fade, em vez do corte
/// seco do MaterialPageRoute puro. Usar em todo Navigator.push de tela
/// cheia, no lugar de `MaterialPageRoute` direto.
Route<T> appPageRoute<T>({required WidgetBuilder builder}) {
  return PageRouteBuilder<T>(
    pageBuilder: (context, animation, secondaryAnimation) => builder(context),
    transitionDuration: AppMotion.resolve(AppMotion.medium),
    reverseTransitionDuration: AppMotion.resolve(AppMotion.fast),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(parent: animation, curve: AppMotion.enter);
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.04),
            end: Offset.zero,
          ).animate(curved),
          child: child,
        ),
      );
    },
  );
}
