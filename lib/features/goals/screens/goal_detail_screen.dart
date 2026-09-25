import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/providers/finance_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../models/goal.dart';
import '../../../shared/utils/category_icons.dart';
import '../../../shared/utils/currency_formatter.dart';
import '../../../shared/utils/haptics.dart';

class GoalDetailScreen extends ConsumerStatefulWidget {
  const GoalDetailScreen({required this.goal, super.key});

  final Goal goal;

  @override
  ConsumerState<GoalDetailScreen> createState() => _GoalDetailScreenState();
}

class _GoalDetailScreenState extends ConsumerState<GoalDetailScreen> {
  bool _isDeleting = false;

  Future<void> _addContribution() async {
    final controller = TextEditingController();
    final amount = await showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Adicionar aporte'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(hintText: '0,00', prefixText: 'R\$ '),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              final normalized = controller.text.replaceAll('.', '').replaceAll(',', '.');
              final value = double.tryParse(normalized);
              Navigator.of(context).pop(value);
            },
            child: const Text('Adicionar'),
          ),
        ],
      ),
    );

    if (amount == null || amount <= 0) return;

    final member = ref.read(currentMemberProvider).valueOrNull;
    if (member == null) return;

    try {
      await ref.read(goalRepositoryProvider).contribute(
            goalId: widget.goal.id,
            memberId: member.id,
            amount: amount,
          );
      ref.invalidate(goalsProvider);
      Haptics.success();
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      Haptics.warning();
    }
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir meta?'),
        content: const Text('O histórico de aportes também será removido.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(
              'Excluir',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _isDeleting = true);
    try {
      await ref.read(goalRepositoryProvider).delete(widget.goal.id);
      ref.invalidate(goalsProvider);
      Haptics.success();
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      Haptics.warning();
      setState(() => _isDeleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.of(context);
    // Reflete o saldo mais recente após um aporte.
    final goals = ref.watch(goalsProvider).valueOrNull;
    final goal = goals?.firstWhere(
          (g) => g.id == widget.goal.id,
          orElse: () => widget.goal,
        ) ??
        widget.goal;

    return Scaffold(
      appBar: AppBar(
        title: Text(goal.name),
        actions: [
          IconButton(
            icon: _isDeleting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.delete_outline_rounded),
            onPressed: _isDeleting ? null : _delete,
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.screenPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(color: palette.accentMuted, shape: BoxShape.circle),
                  child: Icon(categoryIconData(goal.icon), size: 30, color: palette.accent),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Center(
                child: Text(
                  CurrencyFormatter.format(goal.currentAmount),
                  style: AppTypography.displayAmount,
                ),
              ),
              Center(
                child: Text(
                  'de ${CurrencyFormatter.format(goal.targetAmount)}',
                  style: AppTypography.body.copyWith(color: palette.textSecondary),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.pill),
                child: LinearProgressIndicator(
                  value: goal.progress,
                  minHeight: 10,
                  backgroundColor: palette.backgroundSecondary,
                  valueColor: AlwaysStoppedAnimation(palette.accent),
                ),
              ),
              if (goal.targetDate != null || goal.monthlyContribution != null) ...[
                const SizedBox(height: AppSpacing.md),
                if (goal.targetDate != null)
                  Text(
                    'Até ${DateFormat('dd/MM/yyyy', 'pt_BR').format(goal.targetDate!)}',
                    style: AppTypography.caption.copyWith(color: palette.textTertiary),
                  ),
                if (goal.monthlyContribution != null)
                  Text(
                    'Aporte planejado: ${CurrencyFormatter.format(goal.monthlyContribution!)}/mês',
                    style: AppTypography.caption.copyWith(color: palette.textTertiary),
                  ),
              ],
              const SizedBox(height: AppSpacing.lg),
              ElevatedButton(
                onPressed: _addContribution,
                child: const Text('Adicionar aporte'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
