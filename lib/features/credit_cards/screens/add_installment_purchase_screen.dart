import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/providers/app_providers.dart';
import '../../../core/providers/finance_providers.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/utils/category_icons.dart';
import '../../../shared/utils/currency_formatter.dart';
import '../../../shared/utils/haptics.dart';

class AddInstallmentPurchaseScreen extends ConsumerStatefulWidget {
  const AddInstallmentPurchaseScreen({super.key});

  @override
  ConsumerState<AddInstallmentPurchaseScreen> createState() =>
      _AddInstallmentPurchaseScreenState();
}

class _AddInstallmentPurchaseScreenState
    extends ConsumerState<AddInstallmentPurchaseScreen> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  final _totalAmountController = TextEditingController();

  String? _categoryId;
  String? _creditCardId;
  String? _paidByMemberId;
  int _installmentCount = 2;
  DateTime _firstDueDate = DateTime.now();
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _descriptionController.dispose();
    _totalAmountController.dispose();
    super.dispose();
  }

  double? _parseAmount(String raw) {
    final normalized = raw.replaceAll('.', '').replaceAll(',', '.');
    return double.tryParse(normalized);
  }

  Future<void> _pickFirstDueDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _firstDueDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _firstDueDate = picked);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_categoryId == null) {
      setState(() => _errorMessage = 'Escolha uma categoria');
      return;
    }
    if (_creditCardId == null) {
      setState(() => _errorMessage = 'Escolha o cartão');
      return;
    }
    if (_paidByMemberId == null) {
      setState(() => _errorMessage = 'Escolha quem pagou');
      return;
    }

    final household = ref.read(currentHouseholdProvider).valueOrNull;
    if (household == null) return;

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      await ref.read(transactionRepositoryProvider).createInstallmentPurchase(
            householdId: household.id,
            description: _descriptionController.text.trim(),
            totalAmount: _parseAmount(_totalAmountController.text)!,
            installmentCount: _installmentCount,
            firstDueDate: _firstDueDate,
            creditCardId: _creditCardId!,
            categoryId: _categoryId!,
            paidByMemberId: _paidByMemberId!,
          );
      ref.invalidate(transactionsProvider);
      Haptics.success();
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      Haptics.warning();
      setState(() => _errorMessage = 'Não foi possível salvar. Tente novamente.');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(categoriesProvider);
    final cardsAsync = ref.watch(creditCardsProvider);
    final membersAsync = ref.watch(householdMembersProvider);
    final currentMemberAsync = ref.watch(currentMemberProvider);

    currentMemberAsync.whenData((member) {
      if (member != null && _paidByMemberId == null) {
        _paidByMemberId = member.id;
      }
    });
    cardsAsync.whenData((cards) {
      if (cards.isNotEmpty && _creditCardId == null) {
        _creditCardId = cards.first.id;
      }
    });

    final totalAmount = _parseAmount(_totalAmountController.text);
    final installmentPreview = totalAmount == null || totalAmount <= 0
        ? null
        : totalAmount / _installmentCount;

    return Scaffold(
      appBar: AppBar(title: const Text('Compra parcelada')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.screenPadding),
          child: Form(
            key: _formKey,
            child: ListView(
              children: [
                TextFormField(
                  controller: _descriptionController,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(hintText: 'Descrição (ex.: "Geladeira")'),
                  validator: (value) =>
                      (value == null || value.trim().isEmpty) ? 'Informe uma descrição' : null,
                ),
                const SizedBox(height: AppSpacing.sm),
                TextFormField(
                  controller: _totalAmountController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: AppTypography.amountMedium,
                  decoration: const InputDecoration(
                    hintText: 'Valor total',
                    prefixText: 'R\$ ',
                  ),
                  onChanged: (_) => setState(() {}),
                  validator: (value) {
                    final amount = _parseAmount(value ?? '');
                    if (amount == null || amount <= 0) return 'Informe um valor válido';
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.lg),
                Text('Número de parcelas', style: AppTypography.captionEmphasis),
                const SizedBox(height: AppSpacing.xs),
                Wrap(
                  spacing: AppSpacing.xs,
                  runSpacing: AppSpacing.xs,
                  children: List.generate(24, (i) => i + 1).map((count) {
                    return ChoiceChip(
                      label: Text('${count}x'),
                      selected: count == _installmentCount,
                      onSelected: (_) => setState(() => _installmentCount = count),
                    );
                  }).toList(),
                ),
                if (installmentPreview != null) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    '${_installmentCount}x de ${CurrencyFormatter.format(installmentPreview)}',
                    style: AppTypography.caption,
                  ),
                ],
                const SizedBox(height: AppSpacing.lg),
                Text('Cartão', style: AppTypography.captionEmphasis),
                const SizedBox(height: AppSpacing.xs),
                cardsAsync.when(
                  data: (cards) => Wrap(
                    spacing: AppSpacing.xs,
                    runSpacing: AppSpacing.xs,
                    children: cards.map((card) {
                      return ChoiceChip(
                        label: Text(card.name),
                        selected: card.id == _creditCardId,
                        onSelected: (_) => setState(() => _creditCardId = card.id),
                      );
                    }).toList(),
                  ),
                  loading: () => const Padding(
                    padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
                    child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                  ),
                  error: (_, __) => Text(
                    'Não foi possível carregar os cartões',
                    style: AppTypography.caption,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Text('Categoria', style: AppTypography.captionEmphasis),
                const SizedBox(height: AppSpacing.xs),
                categoriesAsync.when(
                  data: (categories) => Wrap(
                    spacing: AppSpacing.xs,
                    runSpacing: AppSpacing.xs,
                    children: categories.map((category) {
                      return ChoiceChip(
                        label: Text(category.name),
                        avatar: Icon(categoryIconData(category.icon), size: 18),
                        selected: category.id == _categoryId,
                        onSelected: (_) => setState(() => _categoryId = category.id),
                      );
                    }).toList(),
                  ),
                  loading: () => const Padding(
                    padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
                    child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                  ),
                  error: (_, __) => Text(
                    'Não foi possível carregar categorias',
                    style: AppTypography.caption,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                membersAsync.maybeWhen(
                  data: (members) {
                    if (members.length <= 1) return const SizedBox.shrink();
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Pago por', style: AppTypography.captionEmphasis),
                        const SizedBox(height: AppSpacing.xs),
                        Wrap(
                          spacing: AppSpacing.xs,
                          children: members.map((member) {
                            return ChoiceChip(
                              label: Text(member.displayName),
                              selected: member.id == _paidByMemberId,
                              onSelected: (_) =>
                                  setState(() => _paidByMemberId = member.id),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                      ],
                    );
                  },
                  orElse: () => const SizedBox.shrink(),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('Primeira parcela vence em', style: AppTypography.captionEmphasis),
                  subtitle: Text(DateFormat('dd/MM/yyyy', 'pt_BR').format(_firstDueDate)),
                  trailing: const Icon(Icons.calendar_today_rounded, size: 20),
                  onTap: _pickFirstDueDate,
                ),
                if (_errorMessage != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    _errorMessage!,
                    style: AppTypography.caption.copyWith(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.lg),
                ElevatedButton(
                  onPressed: _isSubmitting ? null : _submit,
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Salvar'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
