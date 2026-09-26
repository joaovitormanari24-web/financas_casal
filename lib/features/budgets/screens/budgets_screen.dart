import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/app_providers.dart';
import '../../../core/providers/finance_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../models/budget.dart';
import '../../../models/category.dart';
import '../../../shared/utils/category_icons.dart';
import '../../../shared/utils/currency_formatter.dart';
import '../../../shared/utils/haptics.dart';

class BudgetsScreen extends ConsumerWidget {
  const BudgetsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoriesAsync = ref.watch(categoriesProvider);
    final progressList = ref.watch(categoryBudgetProgressProvider);
    final progressByCategory = {for (final p in progressList) p.budget.categoryId: p};

    return Scaffold(
      appBar: AppBar(title: const Text('Orçamento do mês')),
      body: SafeArea(
        child: categoriesAsync.when(
          loading: () => const Center(child: CircularProgressIndicator(strokeWidth: 2)),
          error: (_, __) => Center(
            child: Text('Não foi possível carregar.', style: AppTypography.body),
          ),
          data: (categories) {
            return ListView.separated(
              padding: const EdgeInsets.all(AppSpacing.screenPadding),
              itemCount: categories.length,
              separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
              itemBuilder: (context, index) {
                final category = categories[index];
                return _BudgetRow(
                  category: category,
                  progress: progressByCategory[category.id],
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _BudgetRow extends ConsumerWidget {
  const _BudgetRow({required this.category, required this.progress});

  final Category category;
  final CategoryBudgetProgress? progress;

  Future<void> _editBudget(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController(
      text: progress == null ? '' : progress!.budget.limitAmount.toStringAsFixed(2).replaceAll('.', ','),
    );

    final result = await showDialog<_BudgetDialogResult>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Limite para ${category.name}'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(hintText: '0,00', prefixText: 'R\$ '),
        ),
        actions: [
          if (progress != null)
            TextButton(
              onPressed: () => Navigator.of(context).pop(const _BudgetDialogResult.remove()),
              child: Text(
                'Remover',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              final normalized = controller.text.replaceAll('.', '').replaceAll(',', '.');
              final amount = double.tryParse(normalized);
              if (amount == null || amount <= 0) return;
              Navigator.of(context).pop(_BudgetDialogResult.save(amount));
            },
            child: const Text('Salvar'),
          ),
        ],
      ),
    );

    if (result == null) return;

    final household = ref.read(currentHouseholdProvider).valueOrNull;
    if (household == null) return;

    try {
      if (result.remove) {
        if (progress != null) {
          await ref.read(budgetRepositoryProvider).delete(progress!.budget.id);
        }
      } else {
        final month = ref.read(selectedMonthProvider);
        final budget = Budget(
          id: progress?.budget.id ?? '',
          householdId: household.id,
          categoryId: category.id,
          limitAmount: result.amount!,
          referenceMonth: DateTime(month.year, month.month, 1),
        );
        await ref.read(budgetRepositoryProvider).upsert(budget);
      }
      ref.invalidate(budgetsProvider);
      Haptics.success();
    } catch (_) {
      Haptics.warning();
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = AppColors.of(context);
    final color = colorFromHex(category.colorHex);
    final hasBudget = progress != null;

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        onTap: () => _editBudget(context, ref),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(categoryIconData(category.icon), size: 16, color: color),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(child: Text(category.name, style: AppTypography.body)),
                  if (hasBudget)
                    Text(
                      '${CurrencyFormatter.format(progress!.spent)} / '
                      '${CurrencyFormatter.format(progress!.budget.limitAmount)}',
                      style: AppTypography.captionEmphasis.copyWith(
                        color: progress!.isOverBudget ? palette.warning : palette.textSecondary,
                      ),
                    )
                  else
                    Text(
                      'Definir limite',
                      style: AppTypography.caption.copyWith(color: palette.accent),
                    ),
                ],
              ),
              if (hasBudget) ...[
                const SizedBox(height: AppSpacing.xs),
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  child: LinearProgressIndicator(
                    value: progress!.progress.clamp(0, 1),
                    minHeight: 6,
                    backgroundColor: palette.backgroundSecondary,
                    valueColor: AlwaysStoppedAnimation(
                      progress!.isOverBudget ? palette.warning : palette.accent,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _BudgetDialogResult {
  const _BudgetDialogResult.save(this.amount) : remove = false;
  const _BudgetDialogResult.remove()
      : amount = null,
        remove = true;

  final double? amount;
  final bool remove;
}
