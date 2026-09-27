import 'package:flutter/material.dart';

import '../../core/theme/app_motion.dart';

/// Encolhe levemente o filho enquanto pressionado, soltando com uma
/// pequena "mola" — feedback tátil visual pra toques em ícones/botões que,
/// de outra forma, só mudam de estado sem nenhuma reação imediata ao toque.
class TapBounce extends StatefulWidget {
  const TapBounce({required this.onTap, required this.child, super.key});

  final VoidCallback? onTap;
  final Widget child;

  @override
  State<TapBounce> createState() => _TapBounceState();
}

class _TapBounceState extends State<TapBounce> {
  double _scale = 1;

  void _setScale(double value) {
    if (widget.onTap == null) return;
    setState(() => _scale = value);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _setScale(0.82),
      onTapCancel: () => _setScale(1),
      onTapUp: (_) => _setScale(1),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _scale,
        duration: AppMotion.resolve(AppMotion.instant),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}
