import 'dart:async';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/providers/app_providers.dart';
import '../../../core/providers/finance_providers.dart';
import '../../../core/providers/theme_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../features/transactions/screens/add_transaction_screen.dart';
import '../../budgets/screens/budgets_screen.dart';
import '../../simulator/screens/simulator_screen.dart';
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
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Não foi possível gerar o convite. Tente novamente.'),
          ),
        );
      }
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
            icon: const Icon(Icons.pie_chart_outline_rounded),
            tooltip: 'Orçamento do mês',
            onPressed: () => unawaited(
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const BudgetsScreen()),
              ),
            ),
          ),
          const _ThemeModeButton(),
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
              const SizedBox(height: AppSpacing.sm),
              OutlinedButton.icon(
                onPressed: () => unawaited(
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const SimulatorScreen()),
                  ),
                ),
                icon: const Icon(Icons.calculate_outlined, size: 18),
                label: const Text('Podemos gastar?'),
              ),
              const SizedBox(height: AppSpacing.lg),
              const _SpendingByCategoryChart(),
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

class _ThemeModeButton extends ConsumerWidget {
  const _ThemeModeButton();

  IconData _iconFor(ThemeMode mode) => switch (mode) {
        ThemeMode.light => Icons.light_mode_outlined,
        ThemeMode.dark => Icons.dark_mode_outlined,
        ThemeMode.system => Icons.contrast_rounded,
      };

  String _labelFor(ThemeMode mode) => switch (mode) {
        ThemeMode.light => 'Claro',
        ThemeMode.dark => 'Escuro',
        ThemeMode.system => 'Automático',
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);

    return PopupMenuButton<ThemeMode>(
      tooltip: 'Tema',
      icon: Icon(_iconFor(themeMode)),
      onSelected: (mode) =>
          unawaited(ref.read(themeModeProvider.notifier).setThemeMode(mode)),
      itemBuilder: (context) => ThemeMode.values.map((mode) {
        return PopupMenuItem(
          value: mode,
          child: Row(
            children: [
              Icon(_iconFor(mode), size: 18),
              const SizedBox(width: AppSpacing.sm),
              Text(_labelFor(mode)),
              if (mode == themeMode) ...[
                const Spacer(),
                const Icon(Icons.check, size: 18),
              ],
            ],
          ),
        );
      }).toList(),
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

class _SpendingByCategoryChart extends ConsumerWidget {
  const _SpendingByCategoryChart();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = AppColors.of(context);
    final transactions = ref.watch(transactionsProvider).valueOrNull ?? const [];
    final categories = ref.watch(categoriesProvider).valueOrNull ?? const [];
    final categoriesById = {for (final c in categories) c.id: c};

    final spentByCategory = <String, double>{};
    for (final t in transactions) {
      if (t.type != TransactionType.expense) continue;
      spentByCategory.update(t.categoryId, (v) => v + t.amount, ifAbsent: () => t.amount);
    }

    if (spentByCategory.isEmpty) return const SizedBox.shrink();

    final total = spentByCategory.values.fold<double>(0, (a, b) => a + b);
    final entries = spentByCategory.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Gastos por categoria', style: AppTypography.subtitle),
            const SizedBox(height: AppSpacing.md),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 120,
                  height: 120,
                  child: PieChart(
                    PieChartData(
                      sections: entries.map((entry) {
                        final category = categoriesById[entry.key];
                        final color = category != null
                            ? colorFromHex(category.colorHex)
                            : palette.accent;
                        return PieChartSectionData(
                          value: entry.value,
                          color: color,
                          radius: 24,
                          showTitle: false,
                        );
                      }).toList(),
                      centerSpaceRadius: 36,
                      sectionsSpace: 2,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: entries.take(5).map((entry) {
                      final category = categoriesById[entry.key];
                      final color = category != null
                          ? colorFromHex(category.colorHex)
                          : palette.accent;
                      final percent = total <= 0 ? 0 : (entry.value / total * 100).round();
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        child: Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                            ),
                            const SizedBox(width: AppSpacing.xs),
                            Expanded(
                              child: Text(
                                category?.name ?? 'Sem categoria',
                                style: AppTypography.caption,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Text('$percent%', style: AppTypography.captionEmphasis),
                          ],
                        ),
                      );
                    }).toList(),
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

class _TransactionsList extends ConsumerWidget {
  const _TransactionsList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transactionsAsync = ref.watch(transactionsProvider);
    final categoriesAsync = ref.watch(categoriesProvider);
    final membersAsync = ref.watch(householdMembersProvider);
    final currentMemberAsync = ref.watch(currentMemberProvider);

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
        final members = membersAsync.valueOrNull ?? const [];
        final membersById = {for (final member in members) member.id: member};
        final currentMemberId = currentMemberAsync.valueOrNull?.id;

        return Column(
          children: transactions.map((transaction) {
            final category = categoriesById[transaction.categoryId];
            final payer = membersById[transaction.paidByMemberId];
            final paidByLabel = members.length > 1
                ? (payer == null
                    ? null
                    : (payer.id == currentMemberId ? 'Você' : payer.displayName))
                : null;
            return _TransactionTile(
              transaction: transaction,
              categoryName: category?.name,
              categoryIcon: category?.icon,
              categoryColor: category?.colorHex,
              paidByLabel: paidByLabel,
            );
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
    required this.paidByLabel,
  });

  final models.Transaction transaction;
  final String? categoryName;
  final String? categoryIcon;
  final String? categoryColor;

  /// "Você"/nome do parceiro(a) — nulo se o household só tem 1 membro.
  final String? paidByLabel;

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.of(context);
    final isExpense = transaction.type == TransactionType.expense;
    final color = categoryColor != null ? colorFromHex(categoryColor!) : palette.accent;

    return InkWell(
      borderRadius: BorderRadius.circular(AppRadius.md),
      onTap: () => unawaited(
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => AddTransactionScreen(existing: transaction),
          ),
        ),
      ),
      child: Padding(
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
                  paidByLabel == null
                      ? (categoryName ?? 'Sem categoria')
                      : '${categoryName ?? 'Sem categoria'} · $paidByLabel',
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
      ),
    );
  }
}
