import 'dart:async';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/providers/app_providers.dart';
import '../../../core/providers/finance_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../features/transactions/screens/add_transaction_screen.dart';
import '../../budgets/screens/budgets_screen.dart';
import '../../notifications/screens/notifications_screen.dart';
import '../../settings/screens/settings_screen.dart';
import '../../simulator/screens/simulator_screen.dart';
import '../../../models/category.dart';
import '../../../models/enums.dart';
import '../../../models/household.dart';
import '../../../models/transaction.dart' as models;
import '../../../shared/utils/category_icons.dart';
import '../../../shared/utils/currency_formatter.dart';
import '../../../shared/utils/haptics.dart';
import '../../../shared/utils/report_export.dart';

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
        title: GestureDetector(
          onTap: () => unawaited(
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: householdAsync.when(
                  data: (household) => Text(
                    household?.name ?? 'Finanças do Casal',
                    overflow: TextOverflow.ellipsis,
                  ),
                  loading: () => const Text('Finanças do Casal'),
                  error: (_, __) => const Text('Finanças do Casal'),
                ),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.expand_more_rounded, size: 20),
            ],
          ),
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
          const _NotificationsButton(),
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
              const _OverdueBanner(),
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
              const _MonthlyTrendChart(),
              const SizedBox(height: AppSpacing.lg),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Lançamentos', style: AppTypography.title),
                  const _ExportButton(),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              const _TransactionSearchBar(),
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

class _NotificationsButton extends ConsumerWidget {
  const _NotificationsButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unreadCount = ref.watch(unreadNotificationsCountProvider);

    return IconButton(
      tooltip: 'Notificações',
      icon: Badge(
        isLabelVisible: unreadCount > 0,
        label: Text('$unreadCount'),
        child: const Icon(Icons.notifications_outlined),
      ),
      onPressed: () => unawaited(
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const NotificationsScreen()),
        ),
      ),
    );
  }
}

/// Contas pendentes com vencimento já passado, de qualquer mês — some
/// sozinho quando não há nenhuma.
class _OverdueBanner extends ConsumerWidget {
  const _OverdueBanner();

  Future<void> _markPaid(BuildContext context, WidgetRef ref, String id) async {
    try {
      await ref.read(transactionRepositoryProvider).markPaid(id);
      ref.invalidate(transactionsProvider);
      ref.invalidate(overdueTransactionsProvider);
      ref.invalidate(accountsProvider);
      Haptics.success();
    } catch (_) {
      Haptics.warning();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Não foi possível marcar como pago.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final overdue = ref.watch(overdueTransactionsProvider).valueOrNull ?? const [];
    if (overdue.isEmpty) return const SizedBox.shrink();

    final palette = AppColors.of(context);
    final total = overdue.fold<double>(0, (sum, t) => sum + t.amount);
    const maxShown = 4;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Card(
        color: palette.expense.withValues(alpha: 0.1),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.event_busy_rounded, color: palette.expense),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      '${overdue.length == 1 ? '1 conta atrasada' : '${overdue.length} contas atrasadas'} '
                      '· ${CurrencyFormatter.format(total)}',
                      style: AppTypography.bodyEmphasis.copyWith(color: palette.expense),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              ...overdue.take(maxShown).map((t) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${t.description} · ${CurrencyFormatter.format(t.amount)}',
                          style: AppTypography.caption,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      TextButton(
                        onPressed: () => unawaited(_markPaid(context, ref, t.id)),
                        child: const Text('Marcar pago'),
                      ),
                    ],
                  ),
                );
              }),
              if (overdue.length > maxShown)
                Text(
                  '+ ${overdue.length - maxShown} outra(s)',
                  style: AppTypography.caption.copyWith(color: palette.textTertiary),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MonthSelector extends ConsumerWidget {
  const _MonthSelector();

  Future<void> _pickCustomRange(BuildContext context, WidgetRef ref) async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 1),
      initialDateRange: ref.read(customDateRangeProvider),
      locale: const Locale('pt', 'BR'),
    );
    if (picked != null) {
      ref.read(customDateRangeProvider.notifier).state = picked;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final customRange = ref.watch(customDateRangeProvider);

    if (customRange != null) {
      final formatter = DateFormat('dd/MM/yy', 'pt_BR');
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.date_range_rounded, size: 18, color: AppColors.of(context).textSecondary),
          const SizedBox(width: AppSpacing.xs),
          Text(
            '${formatter.format(customRange.start)} - ${formatter.format(customRange.end)}',
            style: AppTypography.subtitle,
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 18),
            tooltip: 'Voltar pro mês',
            onPressed: () => ref.read(customDateRangeProvider.notifier).state = null,
          ),
        ],
      );
    }

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
        IconButton(
          icon: const Icon(Icons.date_range_outlined, size: 20),
          tooltip: 'Escolher período',
          onPressed: () => unawaited(_pickCustomRange(context, ref)),
        ),
      ],
    );
  }
}

class _ExportButton extends ConsumerStatefulWidget {
  const _ExportButton();

  @override
  ConsumerState<_ExportButton> createState() => _ExportButtonState();
}

class _ExportButtonState extends ConsumerState<_ExportButton> {
  bool _isExporting = false;

  String _periodFileLabel() {
    final customRange = ref.read(customDateRangeProvider);
    if (customRange != null) {
      final f = DateFormat('yyyyMMdd');
      return '${f.format(customRange.start)}_${f.format(customRange.end)}';
    }
    final month = ref.read(selectedMonthProvider);
    return DateFormat('yyyy_MM').format(month);
  }

  String _periodTitle() {
    final customRange = ref.read(customDateRangeProvider);
    if (customRange != null) {
      final f = DateFormat('dd/MM/yyyy');
      return 'Período: ${f.format(customRange.start)} - ${f.format(customRange.end)}';
    }
    final month = ref.read(selectedMonthProvider);
    final label = DateFormat('MMMM yyyy', 'pt_BR').format(month);
    return label[0].toUpperCase() + label.substring(1);
  }

  Future<void> _export({required bool asPdf}) async {
    final transactions = ref.read(filteredTransactionsProvider);
    if (transactions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nenhum lançamento pra exportar nesse período.')),
      );
      return;
    }

    setState(() => _isExporting = true);
    try {
      final categories = ref.read(categoriesProvider).valueOrNull ?? const <Category>[];
      final members = ref.read(householdMembersProvider).valueOrNull ?? const <HouseholdMember>[];
      final categoriesById = {for (final c in categories) c.id: c};
      final membersById = {for (final m in members) m.id: m};
      final periodLabel = _periodFileLabel();

      double income = 0;
      double expense = 0;
      for (final t in transactions) {
        if (t.type == TransactionType.income) {
          income += t.amount;
        } else if (t.type == TransactionType.expense) {
          expense += t.amount;
        }
      }

      if (asPdf) {
        await ReportExport.downloadPdf(
          transactions: transactions,
          categoriesById: categoriesById,
          membersById: membersById,
          periodLabel: periodLabel,
          periodTitle: _periodTitle(),
          income: income,
          expense: expense,
        );
      } else {
        ReportExport.downloadCsv(
          transactions: transactions,
          categoriesById: categoriesById,
          membersById: membersById,
          periodLabel: periodLabel,
        );
      }
      Haptics.success();
    } catch (_) {
      Haptics.warning();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Não foi possível exportar. Tente novamente.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  Future<void> _showOptions() async {
    final choice = await showModalBottomSheet<bool>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.table_chart_outlined),
              title: const Text('Planilha (CSV)'),
              onTap: () => Navigator.of(context).pop(false),
            ),
            ListTile(
              leading: const Icon(Icons.picture_as_pdf_outlined),
              title: const Text('Relatório (PDF)'),
              onTap: () => Navigator.of(context).pop(true),
            ),
          ],
        ),
      ),
    );
    if (choice == null) return;
    await _export(asPdf: choice);
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Exportar',
      icon: _isExporting
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.ios_share_rounded, size: 20),
      onPressed: _isExporting ? null : () => unawaited(_showOptions()),
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

class _MonthlyTrendChart extends ConsumerWidget {
  const _MonthlyTrendChart();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = AppColors.of(context);
    final trendAsync = ref.watch(monthlyTrendProvider);

    return trendAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (months) {
        if (months.every((m) => m.income == 0 && m.expense == 0)) {
          return const SizedBox.shrink();
        }

        final maxValue = months.fold<double>(
          0,
          (max, m) => [max, m.income, m.expense].reduce((a, b) => a > b ? a : b),
        );

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Evolução mensal', style: AppTypography.subtitle),
                const SizedBox(height: AppSpacing.md),
                SizedBox(
                  height: 140,
                  child: BarChart(
                    BarChartData(
                      maxY: maxValue <= 0 ? 100 : maxValue * 1.2,
                      alignment: BarChartAlignment.spaceAround,
                      gridData: const FlGridData(show: false),
                      borderData: FlBorderData(show: false),
                      titlesData: FlTitlesData(
                        leftTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        rightTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        topTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 24,
                            getTitlesWidget: (value, meta) {
                              final index = value.toInt();
                              if (index < 0 || index >= months.length) {
                                return const SizedBox.shrink();
                              }
                              final label = DateFormat('MMM', 'pt_BR')
                                  .format(months[index].month)
                                  .replaceAll('.', '');
                              return Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(label, style: AppTypography.caption),
                              );
                            },
                          ),
                        ),
                      ),
                      barGroups: months.asMap().entries.map((entry) {
                        return BarChartGroupData(
                          x: entry.key,
                          barRods: [
                            BarChartRodData(
                              toY: entry.value.income,
                              color: palette.income,
                              width: 8,
                              borderRadius: BorderRadius.circular(2),
                            ),
                            BarChartRodData(
                              toY: entry.value.expense,
                              color: palette.expense,
                              width: 8,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ],
                          barsSpace: 4,
                        );
                      }).toList(),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _LegendDot(color: palette.income, label: 'Receitas'),
                    const SizedBox(width: AppSpacing.md),
                    _LegendDot(color: palette.expense, label: 'Despesas'),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(label, style: AppTypography.caption),
      ],
    );
  }
}


class _TransactionSearchBar extends ConsumerStatefulWidget {
  const _TransactionSearchBar();

  @override
  ConsumerState<_TransactionSearchBar> createState() => _TransactionSearchBarState();
}

class _TransactionSearchBarState extends ConsumerState<_TransactionSearchBar> {
  late final TextEditingController _controller;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: ref.read(transactionSearchQueryProvider));
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onQueryChanged(String value) {
    _debounce?.cancel();
    // Busca vazia limpa na hora; texto novo espera um pouco (evita disparar
    // uma busca em todo o histórico a cada letra digitada).
    if (value.trim().isEmpty) {
      ref.read(transactionSearchQueryProvider.notifier).state = value;
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 400), () {
      ref.read(transactionSearchQueryProvider.notifier).state = value;
    });
  }

  Future<void> _openFilters(BuildContext context, WidgetRef ref) async {
    final categories = ref.read(categoriesProvider).valueOrNull ?? const [];
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return Consumer(
          builder: (context, ref, _) {
            final categoryFilter = ref.watch(transactionCategoryFilterProvider);
            final paymentFilter = ref.watch(transactionPaymentMethodFilterProvider);
            return Padding(
              padding: EdgeInsets.only(
                left: AppSpacing.screenPadding,
                right: AppSpacing.screenPadding,
                top: AppSpacing.md,
                bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.lg,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Filtros', style: AppTypography.title),
                      TextButton(
                        onPressed: () {
                          ref.read(transactionCategoryFilterProvider.notifier).state = null;
                          ref.read(transactionPaymentMethodFilterProvider.notifier).state =
                              null;
                        },
                        child: const Text('Limpar'),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text('Categoria', style: AppTypography.captionEmphasis),
                  const SizedBox(height: AppSpacing.xs),
                  Wrap(
                    spacing: AppSpacing.xs,
                    runSpacing: AppSpacing.xs,
                    children: categories.map((category) {
                      return ChoiceChip(
                        label: Text(category.name),
                        avatar: Icon(categoryIconData(category.icon), size: 16),
                        selected: category.id == categoryFilter,
                        onSelected: (selected) {
                          ref.read(transactionCategoryFilterProvider.notifier).state =
                              selected ? category.id : null;
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Text('Forma de pagamento', style: AppTypography.captionEmphasis),
                  const SizedBox(height: AppSpacing.xs),
                  Wrap(
                    spacing: AppSpacing.xs,
                    runSpacing: AppSpacing.xs,
                    children: PaymentMethod.values.map((method) {
                      return ChoiceChip(
                        label: Text(method.label),
                        selected: method == paymentFilter,
                        onSelected: (selected) {
                          ref.read(transactionPaymentMethodFilterProvider.notifier).state =
                              selected ? method : null;
                        },
                      );
                    }).toList(),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final categoryFilter = ref.watch(transactionCategoryFilterProvider);
    final paymentFilter = ref.watch(transactionPaymentMethodFilterProvider);
    final hasActiveFilter = categoryFilter != null || paymentFilter != null;
    final palette = AppColors.of(context);

    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _controller,
            decoration: const InputDecoration(
              hintText: 'Buscar lançamento',
              prefixIcon: Icon(Icons.search_rounded, size: 20),
              isDense: true,
            ),
            onChanged: _onQueryChanged,
          ),
        ),
        const SizedBox(width: AppSpacing.xs),
        Stack(
          clipBehavior: Clip.none,
          children: [
            IconButton(
              icon: const Icon(Icons.filter_list_rounded),
              tooltip: 'Filtros',
              onPressed: () => unawaited(_openFilters(context, ref)),
            ),
            if (hasActiveFilter)
              Positioned(
                right: 6,
                top: 6,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(color: palette.accent, shape: BoxShape.circle),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _TransactionsList extends ConsumerWidget {
  const _TransactionsList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isGlobalSearch = ref.watch(transactionSearchQueryProvider).trim().isNotEmpty;
    final transactionsAsync =
        isGlobalSearch ? ref.watch(globalSearchResultsProvider) : ref.watch(transactionsProvider);
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
      data: (allTransactions) {
        final transactions = ref.watch(filteredTransactionsProvider);

        if (allTransactions.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
            child: Center(
              child: Text(
                isGlobalSearch
                    ? 'Nenhum lançamento encontrado em todo o histórico.'
                    : 'Nenhum lançamento neste mês ainda.',
                style: AppTypography.body,
              ),
            ),
          );
        }

        if (transactions.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
            child: Center(
              child: Text(
                'Nenhum lançamento encontrado com esse filtro.',
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

class _TransactionTile extends ConsumerWidget {
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

  Future<void> _openEdit(BuildContext context, WidgetRef ref) async {
    final deleted = await Navigator.of(context).push<models.Transaction>(
      MaterialPageRoute(builder: (_) => AddTransactionScreen(existing: transaction)),
    );
    if (deleted == null || !context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('"${deleted.description}" excluído.'),
        action: SnackBarAction(
          label: 'Desfazer',
          onPressed: () => unawaited(_undoDelete(context, ref, deleted)),
        ),
      ),
    );
  }

  Future<void> _markPaid(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(transactionRepositoryProvider).markPaid(transaction.id);
      ref.invalidate(transactionsProvider);
      ref.invalidate(overdueTransactionsProvider);
      ref.invalidate(accountsProvider);
      Haptics.success();
    } catch (_) {
      Haptics.warning();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Não foi possível marcar como pago.')),
        );
      }
    }
  }

  Future<void> _undoDelete(
    BuildContext context,
    WidgetRef ref,
    models.Transaction deleted,
  ) async {
    try {
      await ref.read(transactionRepositoryProvider).create(
            models.Transaction(
              id: '',
              householdId: deleted.householdId,
              type: deleted.type,
              amount: deleted.amount,
              description: deleted.description,
              categoryId: deleted.categoryId,
              date: deleted.date,
              paidByMemberId: deleted.paidByMemberId,
              paymentMethod: deleted.paymentMethod,
              accountId: deleted.accountId,
            ),
          );
      ref.invalidate(transactionsProvider);
      Haptics.success();
    } catch (_) {
      Haptics.warning();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Não foi possível desfazer a exclusão.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = AppColors.of(context);
    final isExpense = transaction.type == TransactionType.expense;
    final color = categoryColor != null ? colorFromHex(categoryColor!) : palette.accent;

    return InkWell(
      borderRadius: BorderRadius.circular(AppRadius.md),
      onTap: () => unawaited(_openEdit(context, ref)),
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
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        transaction.description,
                        style: AppTypography.body,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (transaction.hasReceipt) ...[
                      const SizedBox(width: 4),
                      Icon(
                        Icons.attach_file_rounded,
                        size: 14,
                        color: palette.textTertiary,
                      ),
                    ],
                  ],
                ),
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        paidByLabel == null
                            ? (categoryName ?? 'Sem categoria')
                            : '${categoryName ?? 'Sem categoria'} · $paidByLabel',
                        style: AppTypography.caption.copyWith(color: palette.textTertiary),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (transaction.isPending) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: (transaction.isOverdue ? palette.expense : palette.warning)
                              .withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                        ),
                        child: Text(
                          transaction.isOverdue ? 'Atrasado' : 'Pendente',
                          style: AppTypography.caption.copyWith(
                            color: transaction.isOverdue ? palette.expense : palette.warning,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          if (transaction.isPending)
            IconButton(
              tooltip: 'Marcar como pago',
              icon: Icon(Icons.check_circle_outline_rounded, color: palette.textTertiary),
              onPressed: () => unawaited(_markPaid(context, ref)),
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
