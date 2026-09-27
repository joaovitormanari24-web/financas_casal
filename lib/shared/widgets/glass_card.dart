import 'dart:ui';

import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';

/// Um "Card" com efeito de vidro fosco (fundo translúcido + blur do que
/// está atrás) — pensado pra ficar sobre [AppBackground], deixando as
/// manchas de cor aparecerem borradas por trás do conteúdo.
class GlassCard extends StatelessWidget {
  const GlassCard({
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.md),
    this.borderRadius,
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.of(context);
    final radius = borderRadius ?? BorderRadius.circular(AppRadius.lg);

    return ClipRRect(
      borderRadius: radius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: palette.surface.withValues(alpha: 0.72),
            borderRadius: radius,
            border: Border.all(color: palette.borderSubtle.withValues(alpha: 0.6)),
          ),
          child: child,
        ),
      ),
    );
  }
}
