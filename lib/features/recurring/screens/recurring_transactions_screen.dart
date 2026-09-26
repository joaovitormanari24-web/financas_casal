import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/providers/finance_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../models/category.dart';
import '../../../models/enums.dart';
import '../../../models/transaction.dart';
import '../../../shared/utils/category_icons.dart';
import '../../../shared/utils/currency_formatter.dart';
import '../../../shared/utils/haptics.dart';
import '../../transactions/screens/add_transaction_screen.dart';

class RecurringTransactionsScreen extends ConsumerWidget {
  const RecurringTransactionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recurringAsync = ref.watch(recurringTransactionsProvider);
    final categoriesAsync = ref.watch(categoriesProvider);
    final palette = AppColors.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Gastos recorrentes')),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(recurringTransactionsProvider);
            await ref.read(recurringTransactionsProvider.future);
          },
          child: recurringAsync.when(
            loading: () => const Center(child: CircularProgressIndicator(strokeWidth: 2)),
            error: (_, __) => ListView(
              children: [
                const SizedBox(height: AppSpacing.xxl),
                Center(
                  child: Text(
                    'Não foi possível carregar.',
                    style: AppTypography.body,
                  ),
                ),
              ],
            ),
            data: (items) {
              if (items.isEmpty) {
                return ListView(
                  children: [
                    const SizedBox(height: AppSpacing.xxl),
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.screenPadding,
                        ),
                        child: Text(
                          'Nenhum gasto recorrente ainda. Cadastre assinaturas, '
                          'aluguel ou outras contas fixas — o app lança sozinho '
                          'todo mês.',
                          style: AppTypography.body,
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ],
                );
              }

              final categoriesById = {
                for (final category in categoriesAsync.valueOrNull ?? const <Category>[])
                  category.id: category,
              };

              return ListView.separated(
                padding: const EdgeInsets.all(AppSpacing.screenPadding),
                itemCount: items.length,
                separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
                itemBuilder: (context, index) {
                  final item = items[index];
                  final category = categoriesById[item.categoryId];
                  return _RecurringCard(item: item, category: category);
                },
              );
            },
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => const AddTransactionScreen(
              initialTxRepeatMode: TxRepeatMode.recurring,
            ),
          ),
        ),
        backgroundColor: palette.textPrimary,
        foregroundColor: palette.background,
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _RecurringCard extends ConsumerWidget {
  const _RecurringCard({required this.item, required this.category});

  final RecurringTransaction item;
  final Category? category;

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir recorrência?'),
        content: const Text('Lançamentos já gerados não são afetados.'),
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

    try {
      await ref.read(recurringTransactionRepositoryProvider).delete(item.id);
      ref.invalidate(recurringTransactionsProvider);
      Haptics.success();
    } catch (_) {
      Haptics.warning();
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = AppColors.of(context);
    final color = category != null ? colorFromHex(category!.colorHex) : palette.accent;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(categoryIconData(category?.icon ?? ''), size: 20, color: color),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.description, style: AppTypography.body),
                  Text(
                    '${item.frequency.label} · ${CurrencyFormatter.format(item.amount)}'
                    '${item.endDate != null ? ' · até ${DateFormat('dd/MM/yyyy', 'pt_BR').format(item.endDate!)}' : ''}',
                    style: AppTypography.caption.copyWith(color: palette.textTertiary),
                  ),
                ],
              ),
            ),
            Switch(
              value: item.active,
              onChanged: (value) async {
                try {
                  await ref
                      .read(recurringTransactionRepositoryProvider)
                      .setActive(item.id, value);
                  ref.invalidate(recurringTransactionsProvider);
                  Haptics.tapLight();
                } catch (_) {
                  Haptics.warning();
                }
              },
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded, size: 20),
              onPressed: () => _delete(context, ref),
            ),
          ],
        ),
      ),
    );
  }
}
