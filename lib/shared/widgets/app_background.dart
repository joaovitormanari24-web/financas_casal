import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// Fundo com manchas de cor bem suaves e difusas (gradiente radial, sem
/// blur de verdade — mais barato e igualmente eficaz) atrás do conteúdo.
/// Pensado pra ficar por trás de [GlassCard]s, que ganham profundidade ao
/// deixar essas cores passarem por trás do vidro fosco.
class AppBackground extends StatelessWidget {
  const AppBackground({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Stack(
      children: [
        Positioned.fill(child: ColoredBox(color: palette.background)),
        Positioned(
          top: -90,
          left: -70,
          child: _Blob(color: palette.accent, size: 260, opacity: isDark ? 0.20 : 0.13),
        ),
        Positioned(
          top: 160,
          right: -110,
          child: _Blob(color: palette.income, size: 220, opacity: isDark ? 0.16 : 0.10),
        ),
        child,
      ],
    );
  }
}

class _Blob extends StatelessWidget {
  const _Blob({required this.color, required this.size, required this.opacity});

  final Color color;
  final double size;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [color.withValues(alpha: opacity), color.withValues(alpha: 0)],
          ),
        ),
      ),
    );
  }
}
