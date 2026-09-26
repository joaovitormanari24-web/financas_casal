import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/providers/finance_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../models/accounts.dart';
import '../../../models/enums.dart';
import '../../../models/transaction.dart';
import '../../../shared/utils/currency_formatter.dart';
import '../../transactions/screens/add_transaction_screen.dart';

/// Extrato de uma conta: saldo (inicial + atual) e os lançamentos vinculados
/// a ela, de qualquer mês — complementa a lista simples de contas em
/// Configurações.
class AccountDetailScreen extends ConsumerStatefulWidget {
  const AccountDetailScreen({required this.account, super.key});

  final Account account;

  @override
  ConsumerState<AccountDetailScreen> createState() => _AccountDetailScreenState();
}

class _AccountDetailScreenState extends ConsumerState<AccountDetailScreen> {
  late Future<List<Transaction>> _transactionsFuture;

  @override
  void initState() {
    super.initState();
    _transactionsFuture = _load();
  }

  Future<List<Transaction>> _load() {
    return ref.read(accountRepositoryProvider).fetchTransactions(widget.account.id);
  }

  Future<void> _refresh() async {
    ref.invalidate(accountsProvider);
    final future = _load();
    setState(() => _transactionsFuture = future);
    await future;
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.of(context);
    final balance = widget.account.currentBalance ?? widget.account.initialBalance;

    return Scaffold(
      appBar: AppBar(title: Text(widget.account.name)),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.screenPadding),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    children: [
                      Text('Saldo atual', style: AppTypography.caption),
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        CurrencyFormatter.format(balance),
                        style: AppTypography.displayAmount,
                      ),
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        'Saldo inicial: ${CurrencyFormatter.format(widget.account.initialBalance)}',
                        style: AppTypography.caption.copyWith(color: palette.textTertiary),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text('Lançamentos', style: AppTypography.title),
              const SizedBox(height: AppSpacing.xs),
              FutureBuilder<List<Transaction>>(
                future: _transactionsFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: AppSpacing.xl),
                      child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                    );
                  }
                  if (snapshot.hasError) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
                      child: Text(
                        'Não foi possível carregar.',
                        style: AppTypography.body,
                      ),
                    );
                  }
                  final transactions = snapshot.data ?? const [];
                  if (transactions.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
                      child: Center(
                        child: Text(
                          'Nenhum lançamento vinculado a essa conta ainda.',
                          style: AppTypography.body,
                        ),
                      ),
                    );
                  }
                  return Column(
                    children: transactions.map((t) {
                      final isExpense = t.type == TransactionType.expense;
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(t.description),
                        subtitle: Text(
                          DateFormat('dd/MM/yyyy', 'pt_BR').format(t.date),
                          style: AppTypography.caption,
                        ),
                        trailing: Text(
                          '${isExpense ? '-' : '+'} ${CurrencyFormatter.format(t.amount)}',
                          style: AppTypography.bodyEmphasis.copyWith(
                            color: isExpense ? palette.expense : palette.income,
                          ),
                        ),
                        onTap: () async {
                          await Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => AddTransactionScreen(existing: t)),
                          );
                          if (mounted) await _refresh();
                        },
                      );
                    }).toList(),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
