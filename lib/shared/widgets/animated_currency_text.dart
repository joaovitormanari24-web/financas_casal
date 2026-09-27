import 'package:flutter/material.dart';

import '../../core/theme/app_motion.dart';
import '../utils/currency_formatter.dart';

/// Anima a transição de um valor monetário para o outro ("contando") em vez
/// de trocar o texto de golpe — usado no saldo/receitas/despesas do resumo
/// do mês, que mudam toda vez que um lançamento é adicionado ou o mês
/// selecionado troca.
class AnimatedCurrencyText extends StatefulWidget {
  const AnimatedCurrencyText({required this.value, this.style, super.key});

  final double value;
  final TextStyle? style;

  @override
  State<AnimatedCurrencyText> createState() => _AnimatedCurrencyTextState();
}

class _AnimatedCurrencyTextState extends State<AnimatedCurrencyText> {
  double _previousValue = 0;

  @override
  void didUpdateWidget(AnimatedCurrencyText oldWidget) {
    super.didUpdateWidget(oldWidget);
    _previousValue = oldWidget.value;
  }

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: _previousValue, end: widget.value),
      duration: AppMotion.resolve(AppMotion.numberCountUp),
      curve: AppMotion.enter,
      builder: (context, animatedValue, _) {
        return Text(CurrencyFormatter.format(animatedValue), style: widget.style);
      },
    );
  }
}
