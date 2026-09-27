import 'package:flutter/material.dart';

import '../../core/theme/app_motion.dart';

/// Revela o filho com um leve fade + slide-up, uma única vez quando ele
/// aparece na árvore (não a cada rebuild do widget pai) — usado nos cards
/// principais da Home pra dar uma entrada mais viva em vez de aparecerem
/// todos prontos de uma vez.
class FadeSlideIn extends StatefulWidget {
  const FadeSlideIn({required this.child, this.delay = Duration.zero, super.key});

  final Widget child;
  final Duration delay;

  @override
  State<FadeSlideIn> createState() => _FadeSlideInState();
}

class _FadeSlideInState extends State<FadeSlideIn> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: AppMotion.resolve(AppMotion.medium),
    );
    if (widget.delay == Duration.zero) {
      _controller.forward();
    } else {
      Future.delayed(AppMotion.resolve(widget.delay), () {
        if (mounted) _controller.forward();
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final curved = CurvedAnimation(parent: _controller, curve: AppMotion.enter);
    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.03),
          end: Offset.zero,
        ).animate(curved),
        child: widget.child,
      ),
    );
  }
}
