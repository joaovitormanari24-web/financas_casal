import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/app_providers.dart';
import '../../../core/providers/finance_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../models/financial_simulation.dart';
import '../../../shared/utils/currency_formatter.dart';
import '../../../shared/utils/haptics.dart';

class SimulatorScreen extends ConsumerStatefulWidget {
  const SimulatorScreen({super.key});

  @override
  ConsumerState<SimulatorScreen> createState() => _SimulatorScreenState();
}

class _SimulatorScreenState extends ConsumerState<SimulatorScreen> {
  final _amountController = TextEditingController();
  double? _simulatedAmount;

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  double? _parseAmount(String raw) {
    if (raw.trim().isEmpty) return null;
    final normalized = raw.replaceAll('.', '').replaceAll(',', '.');
    return double.tryParse(normalized);
  }

  Future<void> _simulate(double available, double amount) async {
    setState(() => _simulatedAmount = amount);
    Haptics.tapLight();

    final household = ref.read(currentHouseholdProvider).valueOrNull;
    final member = ref.read(currentMemberProvider).valueOrNull;
    if (household == null || member == null) return;

    try {
      await ref.read(financialSimulationRepositoryProvider).save(
            FinancialSimulation(
              id: '',
              householdId: household.id,
              createdByMemberId: member.id,
              kind: SimulationKind.purchase,
              input: {'amount': amount},
              result: {'available': available, 'fits': amount <= available},
            ),
          );
    } catch (_) {
      // Histórico é só um bônus — não bloqueia o resultado se falhar.
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.of(context);
    final summary = ref.watch(monthSummaryProvider);
    final goals = ref.watch(goalsProvider).valueOrNull ?? const [];

    final committed = goals.fold<double>(
      0,
      (total, goal) => total + (goal.monthlyContribution ?? 0),
    );
    final available = summary.balance - committed;

    final fits = _simulatedAmount != null && _simulatedAmount! <= available;

    return Scaffold(
      appBar: AppBar(title: const Text('Podemos gastar?')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.screenPadding),
          child: ListView(
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _SummaryLine(
                        label: 'Saldo do mês',
                        value: summary.balance,
                        palette: palette,
                      ),
                      if (committed > 0)
                        _SummaryLine(
                          label: 'Comprometido com metas',
                          value: -committed,
                          palette: palette,
                        ),
                      const Divider(height: AppSpacing.lg),
                      _SummaryLine(
                        label: 'Disponível pra gastar',
                        value: available,
                        palette: palette,
                        emphasis: true,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text('Quanto você quer gastar?', style: AppTypography.captionEmphasis),
              const SizedBox(height: AppSpacing.xs),
              TextField(
                controller: _amountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                style: AppTypography.amountLarge,
                decoration: const InputDecoration(hintText: '0,00', prefixText: 'R\$ '),
                onSubmitted: (_) {
                  final amount = _parseAmount(_amountController.text);
                  if (amount != null) _simulate(available, amount);
                },
              ),
              const SizedBox(height: AppSpacing.md),
              ElevatedButton(
                onPressed: () {
                  final amount = _parseAmount(_amountController.text);
                  if (amount != null) _simulate(available, amount);
                },
                child: const Text('Simular'),
              ),
              if (_simulatedAmount != null) ...[
                const SizedBox(height: AppSpacing.lg),
                Card(
                  color: fits ? palette.accentMuted : palette.warning.withValues(alpha: 0.12),
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Column(
                      children: [
                        Icon(
                          fits ? Icons.check_circle_rounded : Icons.error_outline_rounded,
                          color: fits ? palette.accent : palette.warning,
                          size: 32,
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          fits ? 'Cabe no orçamento!' : 'Vai apertar',
                          style: AppTypography.title,
                        ),
                        const SizedBox(height: AppSpacing.xxs),
                        Text(
                          fits
                              ? 'Sobram ${CurrencyFormatter.format(available - _simulatedAmount!)} '
                                  'depois dessa compra.'
                              : 'Faltam ${CurrencyFormatter.format(_simulatedAmount! - available)} '
                                  'pra fechar sem afetar suas metas.',
                          style: AppTypography.body,
                          textAlign: TextAlign.center,
                        ),
                      ],
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

class _SummaryLine extends StatelessWidget {
  const _SummaryLine({
    required this.label,
    required this.value,
    required this.palette,
    this.emphasis = false,
  });

  final String label;
  final double value;
  final AppPalette palette;
  final bool emphasis;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: emphasis ? AppTypography.bodyEmphasis : AppTypography.body,
          ),
          Text(
            CurrencyFormatter.format(value),
            style: (emphasis ? AppTypography.amountMedium : AppTypography.bodyEmphasis).copyWith(
              color: value < 0 ? palette.warning : null,
            ),
          ),
        ],
      ),
    );
  }
}
