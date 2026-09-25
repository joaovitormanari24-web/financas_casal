import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/finance_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../models/accounts.dart';
import '../../../shared/utils/currency_formatter.dart';
import '../../../shared/utils/haptics.dart';
import 'add_credit_card_screen.dart';
import 'add_installment_purchase_screen.dart';

class CreditCardsScreen extends ConsumerWidget {
  const CreditCardsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cardsAsync = ref.watch(creditCardsProvider);
    final palette = AppColors.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Cartões')),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(creditCardsProvider);
            await ref.read(creditCardsProvider.future);
          },
          child: cardsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator(strokeWidth: 2)),
            error: (_, __) => ListView(
              children: [
                const SizedBox(height: AppSpacing.xxl),
                Center(child: Text('Não foi possível carregar.', style: AppTypography.body)),
              ],
            ),
            data: (cards) {
              return ListView(
                padding: const EdgeInsets.all(AppSpacing.screenPadding),
                children: [
                  if (cards.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
                      child: Center(
                        child: Text(
                          'Nenhum cartão cadastrado ainda.',
                          style: AppTypography.body,
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  else
                    ...cards.map((card) => _CreditCardTile(card: card)),
                  const SizedBox(height: AppSpacing.lg),
                  OutlinedButton.icon(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const AddCreditCardScreen()),
                    ),
                    icon: const Icon(Icons.add),
                    label: const Text('Novo cartão'),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  ElevatedButton.icon(
                    onPressed: cards.isEmpty
                        ? null
                        : () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const AddInstallmentPurchaseScreen(),
                              ),
                            ),
                    icon: const Icon(Icons.credit_card),
                    label: const Text('Nova compra parcelada'),
                  ),
                  if (cards.isEmpty) ...[
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Cadastre um cartão antes de lançar uma compra parcelada.',
                      style: AppTypography.caption.copyWith(color: palette.textTertiary),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _CreditCardTile extends ConsumerWidget {
  const _CreditCardTile({required this.card});

  final CreditCard card;

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir cartão?'),
        content: const Text(
          'Compras parceladas já lançadas com este cartão não são excluídas.',
        ),
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
      await ref.read(creditCardRepositoryProvider).delete(card.id);
      ref.invalidate(creditCardsProvider);
      Haptics.success();
    } catch (_) {
      Haptics.warning();
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = AppColors.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(color: palette.accentMuted, shape: BoxShape.circle),
              child: Icon(Icons.credit_card_rounded, size: 20, color: palette.accent),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(card.name, style: AppTypography.body),
                  Text(
                    '${card.institution} · limite ${CurrencyFormatter.format(card.limit)} '
                    '· fecha dia ${card.closingDay} · vence dia ${card.dueDay}',
                    style: AppTypography.caption.copyWith(color: palette.textTertiary),
                  ),
                ],
              ),
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
