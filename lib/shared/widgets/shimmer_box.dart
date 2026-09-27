import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_motion.dart';

/// Placeholder "shimmer" pra estados de carregamento — uma barra que varre
/// um brilho leve da esquerda pra direita, em loop, no lugar de um spinner
/// solto no meio da tela. Desliga sozinho quando "Reduzir movimento" está
/// ativo (vira só um bloco estático).
class ShimmerBox extends StatefulWidget {
  const ShimmerBox({this.width, required this.height, this.borderRadius = 8, super.key});

  final double? width;
  final double height;
  final double borderRadius;

  @override
  State<ShimmerBox> createState() => _ShimmerBoxState();
}

class _ShimmerBoxState extends State<ShimmerBox> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400));
    if (!AppMotion.reduceMotionEnabled()) _controller.repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.of(context);
    final base = palette.borderSubtle;

    final box = Container(
      width: widget.width,
      height: widget.height,
      decoration: BoxDecoration(color: base, borderRadius: BorderRadius.circular(widget.borderRadius)),
    );

    if (AppMotion.reduceMotionEnabled()) return box;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = _controller.value;
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) => LinearGradient(
            colors: [base, palette.surface, base],
            stops: const [0.35, 0.5, 0.65],
            begin: Alignment(-1.5 + 3 * t, 0),
            end: Alignment(-0.5 + 3 * t, 0),
          ).createShader(bounds),
          child: child,
        );
      },
      child: box,
    );
  }
}
