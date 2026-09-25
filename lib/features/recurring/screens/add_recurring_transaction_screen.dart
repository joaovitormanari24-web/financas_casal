import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/providers/app_providers.dart';
import '../../../core/providers/finance_providers.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../models/enums.dart';
import '../../../models/transaction.dart';
import '../../../shared/utils/category_icons.dart';
import '../../../shared/utils/haptics.dart';

const _weekdayLabels = {
  1: 'Segunda',
  2: 'Terça',
  3: 'Quarta',
  4: 'Quinta',
  5: 'Sexta',
  6: 'Sábado',
  7: 'Domingo',
};

class AddRecurringTransactionScreen extends ConsumerStatefulWidget {
  const AddRecurringTransactionScreen({super.key});

  @override
  ConsumerState<AddRecurringTransactionScreen> createState() =>
      _AddRecurringTransactionScreenState();
}

class _AddRecurringTransactionScreenState
    extends ConsumerState<AddRecurringTransactionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  final _amountController = TextEditingController();
  final _newAmountController = TextEditingController();

  String? _categoryId;
  String? _paidByMemberId;
  RecurrenceFrequency _frequency = RecurrenceFrequency.monthly;
  int _dayOfCycle = 1;
  PaymentMethod _paymentMethod = PaymentMethod.pix;
  bool _isSubmitting = false;
  String? _errorMessage;

  bool _hasEndDate = false;
  DateTime? _endDate;

  bool _hasAmountChange = false;
  DateTime? _amountChangeDate;

  @override
  void dispose() {
    _descriptionController.dispose();
    _amountController.dispose();
    _newAmountController.dispose();
    super.dispose();
  }

  double? _parseAmount(String raw) {
    final normalized = raw.replaceAll('.', '').replaceAll(',', '.');
    return double.tryParse(normalized);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_categoryId == null) {
      setState(() => _errorMessage = 'Escolha uma categoria');
      return;
    }
    if (_hasEndDate && _endDate == null) {
      setState(() => _errorMessage = 'Escolha a data de término');
      return;
    }
    double? newAmount;
    if (_hasAmountChange) {
      if (_amountChangeDate == null) {
        setState(() => _errorMessage = 'Escolha a partir de quando o valor muda');
        return;
      }
      newAmount = _parseAmount(_newAmountController.text);
      if (newAmount == null || newAmount <= 0) {
        setState(() => _errorMessage = 'Informe o novo valor');
        return;
      }
    }

    final household = ref.read(currentHouseholdProvider).valueOrNull;
    if (household == null) return;

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final recurring = RecurringTransaction(
        id: '',
        householdId: household.id,
        description: _descriptionController.text.trim(),
        amount: _parseAmount(_amountController.text)!,
        categoryId: _categoryId!,
        frequency: _frequency,
        dayOfCycle: _dayOfCycle,
        active: true,
        paymentMethod: _paymentMethod,
        paidByMemberId: _paidByMemberId,
        endDate: _hasEndDate ? _endDate : null,
      );
      final repository = ref.read(recurringTransactionRepositoryProvider);
      final created = await repository.create(recurring);
      if (_hasAmountChange) {
        await repository.addAmountChange(
          recurringTransactionId: created.id,
          effectiveDate: _amountChangeDate!,
          newAmount: newAmount!,
        );
      }
      ref.invalidate(recurringTransactionsProvider);
      Haptics.success();
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      Haptics.warning();
      setState(() => _errorMessage = 'Não foi possível salvar. Tente novamente.');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _pickEndDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _endDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _endDate = picked);
  }

  Future<void> _pickAmountChangeDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _amountChangeDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _amountChangeDate = picked);
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(categoriesProvider);
    final membersAsync = ref.watch(householdMembersProvider);
    final currentMemberAsync = ref.watch(currentMemberProvider);

    currentMemberAsync.whenData((member) {
      if (member != null && _paidByMemberId == null) {
        _paidByMemberId = member.id;
      }
    });

    return Scaffold(
      appBar: AppBar(title: const Text('Novo gasto recorrente')),
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
                  decoration: const InputDecoration(
                    hintText: 'Descrição (ex.: "Aluguel", "Netflix")',
                  ),
                  validator: (value) =>
                      (value == null || value.trim().isEmpty) ? 'Informe uma descrição' : null,
                ),
                const SizedBox(height: AppSpacing.sm),
                TextFormField(
                  controller: _amountController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: AppTypography.amountMedium,
                  decoration: const InputDecoration(hintText: '0,00', prefixText: 'R\$ '),
                  validator: (value) {
                    final amount = _parseAmount(value ?? '');
                    if (amount == null || amount <= 0) return 'Informe um valor válido';
                    return null;
                  },
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
                Text('Frequência', style: AppTypography.captionEmphasis),
                const SizedBox(height: AppSpacing.xs),
                Wrap(
                  spacing: AppSpacing.xs,
                  children: [RecurrenceFrequency.weekly, RecurrenceFrequency.monthly]
                      .map((frequency) {
                    return ChoiceChip(
                      label: Text(frequency.label),
                      selected: frequency == _frequency,
                      onSelected: (_) => setState(() {
                        _frequency = frequency;
                        _dayOfCycle = frequency == RecurrenceFrequency.weekly ? 1 : 1;
                      }),
                    );
                  }).toList(),
                ),
                const SizedBox(height: AppSpacing.lg),
                if (_frequency == RecurrenceFrequency.weekly) ...[
                  Text('Dia da semana', style: AppTypography.captionEmphasis),
                  const SizedBox(height: AppSpacing.xs),
                  Wrap(
                    spacing: AppSpacing.xs,
                    runSpacing: AppSpacing.xs,
                    children: _weekdayLabels.entries.map((entry) {
                      return ChoiceChip(
                        label: Text(entry.value),
                        selected: entry.key == _dayOfCycle,
                        onSelected: (_) => setState(() => _dayOfCycle = entry.key),
                      );
                    }).toList(),
                  ),
                ] else ...[
                  Text('Dia do mês', style: AppTypography.captionEmphasis),
                  const SizedBox(height: AppSpacing.xs),
                  Wrap(
                    spacing: AppSpacing.xs,
                    runSpacing: AppSpacing.xs,
                    children: List.generate(31, (i) => i + 1).map((day) {
                      return ChoiceChip(
                        label: Text('$day'),
                        selected: day == _dayOfCycle,
                        onSelected: (_) => setState(() => _dayOfCycle = day),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    'Em meses mais curtos, lança no último dia do mês.',
                    style: AppTypography.caption,
                  ),
                ],
                const SizedBox(height: AppSpacing.lg),
                Text('Forma de pagamento', style: AppTypography.captionEmphasis),
                const SizedBox(height: AppSpacing.xs),
                Wrap(
                  spacing: AppSpacing.xs,
                  runSpacing: AppSpacing.xs,
                  children: PaymentMethod.values.map((method) {
                    return ChoiceChip(
                      label: Text(method.label),
                      selected: method == _paymentMethod,
                      onSelected: (_) => setState(() => _paymentMethod = method),
                    );
                  }).toList(),
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
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('Tem data pra acabar?', style: AppTypography.captionEmphasis),
                  subtitle: Text(
                    _hasEndDate && _endDate != null
                        ? 'Até ${DateFormat('dd/MM/yyyy', 'pt_BR').format(_endDate!)}'
                        : 'Por tempo indeterminado',
                    style: AppTypography.caption,
                  ),
                  value: _hasEndDate,
                  onChanged: (value) {
                    setState(() => _hasEndDate = value);
                    if (value) _pickEndDate();
                  },
                ),
                if (_hasEndDate)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(
                      onPressed: _pickEndDate,
                      child: Text(
                        _endDate == null
                            ? 'Escolher data'
                            : 'Alterar data (${DateFormat('dd/MM/yyyy', 'pt_BR').format(_endDate!)})',
                      ),
                    ),
                  ),
                const SizedBox(height: AppSpacing.sm),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('O valor vai reajustar?', style: AppTypography.captionEmphasis),
                  subtitle: Text(
                    'Ex.: aluguel que aumenta a partir de um mês específico',
                    style: AppTypography.caption,
                  ),
                  value: _hasAmountChange,
                  onChanged: (value) => setState(() => _hasAmountChange = value),
                ),
                if (_hasAmountChange) ...[
                  TextFormField(
                    controller: _newAmountController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      hintText: 'Novo valor',
                      prefixText: 'R\$ ',
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(
                      onPressed: _pickAmountChangeDate,
                      child: Text(
                        _amountChangeDate == null
                            ? 'A partir de quando?'
                            : 'A partir de ${DateFormat('dd/MM/yyyy', 'pt_BR').format(_amountChangeDate!)}',
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.sm),
                if (_errorMessage != null) ...[
                  Text(
                    _errorMessage!,
                    style: AppTypography.caption.copyWith(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                ],
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
