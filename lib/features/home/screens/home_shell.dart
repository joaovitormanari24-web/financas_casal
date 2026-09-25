import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/providers/app_providers.dart';
import '../../../core/providers/finance_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../features/transactions/screens/add_transaction_screen.dart';
import '../../../models/enums.dart';
import '../../../models/transaction.dart' as models;
import '../../../shared/utils/category_icons.dart';
import '../../../shared/utils/currency_formatter.dart';
import '../../../shared/utils/haptics.dart';

class HomeShell extends ConsumerWidget {
  const HomeShell({super.key});

  Future<void> _showInviteCode(BuildContext context, WidgetRef ref, String householdId) async {
    try {
      final code = await ref
          .read(householdRepositoryProvider)
          .createInvite(householdId: householdId);
      if (!context.mounted) return;
      unawaited(showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Código de convite'),
          content: Text(
            'Compartilhe "$code" com seu parceiro(a). Válido por 7 dias.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Fechar'),
            ),
          ],
        ),
      ));
    } catch (_) {
      Haptics.warning();
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final householdAsync = ref.watch(currentHouseholdProvider);
    final palette = AppColors.of(context);

    return Scaffold(
      appBar: AppBar(
        title: householdAsync.when(
          data: (household) => Text(household?.name ?? 'Finanças do Casal'),
          loading: () => const Text('Finanças do Casal'),
          error: (_, __) => const Text('Finanças do Casal'),
        ),
        actions: [
          householdAsync.maybeWhen(
            data: (household) => household == null
                ? const SizedBox.shrink()
                : IconButton(
                    icon: const Icon(Icons.person_add_alt_outlined),
                    tooltip: 'Convidar parceiro(a)',
                    onPressed: () =>
                        unawaited(_showInviteCode(context, ref, household.id)),
                  ),
            orElse: () => const SizedBox.shrink(),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sair',
            onPressed: () => unawaited(ref.read(authRepositoryProvider).signOut()),
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(transactionsProvider);
            await ref.read(transactionsProvider.future);
          },
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.screenPadding),
            children: [
              const _MonthSelector(),
              const SizedBox(height: AppSpacing.md),
              const _MonthSummaryCard(),
              const SizedBox(height: AppSpacing.lg),
              Text('Lançamentos', style: AppTypography.title),
              const SizedBox(height: AppSpacing.xs),
              const _TransactionsList(),
              const SizedBox(height: AppSpacing.xxxl),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => unawaited(
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const AddTransactionScreen()),
          ),
        ),
        backgroundColor: palette.textPrimary,
        foregroundColor: palette.background,
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _MonthSelector extends ConsumerWidget {
  const _MonthSelector();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final month = ref.watch(selectedMonthProvider);
    final label = DateFormat('MMMM yyyy', 'pt_BR').format(month);

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          icon: const Icon(Icons.chevron_left_rounded),
          onPressed: () {
            ref.read(selectedMonthProvider.notifier).state =
                DateTime(month.year, month.month - 1, 1);
          },
        ),
        SizedBox(
          width: 160,
          child: Text(
            label[0].toUpperCase() + label.substring(1),
            textAlign: TextAlign.center,
            style: AppTypography.subtitle,
          ),
        ),
        IconButton(
          icon: const Icon(Icons.chevron_right_rounded),
          onPressed: () {
            ref.read(selectedMonthProvider.notifier).state =
                DateTime(month.year, month.month + 1, 1);
          },
        ),
      ],
    );
  }
}

class _MonthSummaryCard extends ConsumerWidget {
  const _MonthSummaryCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Garante que o resumo reflete o estado mais recente das transações.
    ref.watch(transactionsProvider);
    final summary = ref.watch(monthSummaryProvider);
    final palette = AppColors.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          children: [
            Text('Saldo do mês', style: AppTypography.caption),
            const SizedBox(height: AppSpacing.xxs),
            Text(
              CurrencyFormatter.format(summary.balance),
              style: AppTypography.displayAmount,
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: _SummaryStat(
                    label: 'Receitas',
                    value: summary.income,
                    color: palette.income,
                    icon: Icons.arrow_upward_rounded,
                  ),
                ),
                Container(width: 1, height: 32, color: palette.borderSubtle),
                Expanded(
                  child: _SummaryStat(
                    label: 'Despesas',
                    value: summary.expense,
                    color: palette.expense,
                    icon: Icons.arrow_downward_rounded,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryStat extends StatelessWidget {
  const _SummaryStat({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  final String label;
  final double value;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
            Text(label, style: AppTypography.caption),
          ],
        ),
        const SizedBox(height: 2),
        Text(CurrencyFormatter.format(value), style: AppTypography.amountMedium),
      ],
    );
  }
}

class _TransactionsList extends ConsumerWidget {
  const _TransactionsList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transactionsAsync = ref.watch(transactionsProvider);
    final categoriesAsync = ref.watch(categoriesProvider);

    return transactionsAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: AppSpacing.xl),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      ),
      error: (_, __) => Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
        child: Text(
          'Não foi possível carregar os lançamentos.',
          style: AppTypography.body,
        ),
      ),
      data: (transactions) {
        if (transactions.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
            child: Center(
              child: Text(
                'Nenhum lançamento neste mês ainda.',
                style: AppTypography.body,
              ),
            ),
          );
        }

        final categoriesById = {
          for (final category in categoriesAsync.valueOrNull ?? const [])
            category.id: category,
        };

        return Column(
          children: transactions.map((transaction) {
            final category = categoriesById[transaction.categoryId];
            return _TransactionTile(transaction: transaction, categoryName: category?.name, categoryIcon: category?.icon, categoryColor: category?.colorHex);
          }).toList(),
        );
      },
    );
  }
}

class _TransactionTile extends StatelessWidget {
  const _TransactionTile({
    required this.transaction,
    required this.categoryName,
    required this.categoryIcon,
    required this.categoryColor,
  });

  final models.Transaction transaction;
  final String? categoryName;
  final String? categoryIcon;
  final String? categoryColor;

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.of(context);
    final isExpense = transaction.type == TransactionType.expense;
    final color = categoryColor != null ? colorFromHex(categoryColor!) : palette.accent;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(
              categoryIconData(categoryIcon ?? ''),
              size: 20,
              color: color,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(transaction.description, style: AppTypography.body),
                Text(
                  categoryName ?? 'Sem categoria',
                  style: AppTypography.caption.copyWith(color: palette.textTertiary),
                ),
              ],
            ),
          ),
          Text(
            '${isExpense ? '-' : '+'} ${CurrencyFormatter.format(transaction.amount)}',
            style: AppTypography.bodyEmphasis.copyWith(
              color: isExpense ? palette.expense : palette.income,
            ),
          ),
        ],
      ),
    );
  }
}
