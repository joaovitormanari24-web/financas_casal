import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/providers/app_providers.dart';
import '../../../core/providers/finance_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_motion.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../models/category.dart';
import '../../../models/enums.dart';
import '../../../models/transaction.dart' as models;
import '../../../shared/utils/category_icons.dart';
import '../../../shared/utils/haptics.dart';
import '../../../shared/utils/payment_method_icons.dart';
import 'add_category_dialog.dart';

/// Como o lançamento se repete. Só é escolhido na criação — editar um
/// lançamento existente nunca muda seu modo.
enum TxRepeatMode { once, installments, recurring }

const _weekdayLabels = {
  1: 'Segunda',
  2: 'Terça',
  3: 'Quarta',
  4: 'Quinta',
  5: 'Sexta',
  6: 'Sábado',
  7: 'Domingo',
};

class AddTransactionScreen extends ConsumerStatefulWidget {
  const AddTransactionScreen({
    this.existing,
    this.initialTxRepeatMode = TxRepeatMode.once,
    super.key,
  });

  /// Quando presente, a tela edita este lançamento em vez de criar um novo.
  final models.Transaction? existing;

  /// Modo pré-selecionado ao abrir pra criar um novo lançamento (ex.: a aba
  /// "Recorrentes" abre já em [TxRepeatMode.recurring]). Ignorado ao editar.
  final TxRepeatMode initialTxRepeatMode;

  bool get isEditing => existing != null;

  @override
  ConsumerState<AddTransactionScreen> createState() => _AddTransactionScreenState();
}

class _AddTransactionScreenState extends ConsumerState<AddTransactionScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _amountController;
  late final TextEditingController _descriptionController;
  final _newAmountController = TextEditingController();

  late TransactionType _type;
  late PaymentMethod _paymentMethod;
  String? _categoryId;
  String? _paidByMemberId;
  String? _accountId;
  late DateTime _date;
  bool _isSubmitting = false;
  bool _isDeleting = false;
  String? _errorMessage;

  late TxRepeatMode _repeatMode;

  // Parcelado.
  int _installmentCount = 2;

  // Recorrente.
  RecurrenceFrequency _frequency = RecurrenceFrequency.monthly;
  int _dayOfCycle = 1;
  bool _hasEndDate = false;
  DateTime? _endDate;
  bool _hasAmountChange = false;
  DateTime? _amountChangeDate;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _amountController = TextEditingController(
      text: existing == null ? '' : existing.amount.toStringAsFixed(2).replaceAll('.', ','),
    );
    _descriptionController = TextEditingController(text: existing?.description ?? '');
    _type = existing?.type ?? TransactionType.expense;
    _paymentMethod = existing?.paymentMethod ?? PaymentMethod.pix;
    _categoryId = existing?.categoryId;
    _paidByMemberId = existing?.paidByMemberId;
    _accountId = existing?.accountId;
    _date = existing?.date ?? DateTime.now();
    _repeatMode = widget.isEditing ? TxRepeatMode.once : widget.initialTxRepeatMode;
    if (_repeatMode == TxRepeatMode.recurring) _type = TransactionType.expense;
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    _newAmountController.dispose();
    super.dispose();
  }

  double? _parseAmount(String raw) {
    if (raw.trim().isEmpty) return null;
    final normalized = raw.replaceAll('.', '').replaceAll(',', '.');
    return double.tryParse(normalized);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_categoryId == null) {
      setState(() => _errorMessage = 'Escolha uma categoria');
      return;
    }
    if (_paidByMemberId == null) {
      setState(() => _errorMessage = 'Escolha quem pagou');
      return;
    }
    if (!widget.isEditing && _repeatMode == TxRepeatMode.recurring) {
      if (_hasEndDate && _endDate == null) {
        setState(() => _errorMessage = 'Escolha a data de término');
        return;
      }
      if (_hasAmountChange &&
          (_amountChangeDate == null || _parseAmount(_newAmountController.text) == null)) {
        setState(() => _errorMessage = 'Preencha o reajuste de valor');
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
      final amount = _parseAmount(_amountController.text)!;

      if (widget.isEditing) {
        final transaction = models.Transaction(
          id: widget.existing!.id,
          householdId: household.id,
          type: _type,
          amount: amount,
          description: _descriptionController.text.trim(),
          categoryId: _categoryId!,
          date: _date,
          paidByMemberId: _paidByMemberId!,
          paymentMethod: _paymentMethod,
          accountId: _accountId,
        );
        await ref.read(transactionRepositoryProvider).update(widget.existing!.id, transaction);
        ref.invalidate(transactionsProvider);
      } else {
        switch (_repeatMode) {
          case TxRepeatMode.once:
            final transaction = models.Transaction(
              id: '',
              householdId: household.id,
              type: _type,
              amount: amount,
              description: _descriptionController.text.trim(),
              categoryId: _categoryId!,
              date: _date,
              paidByMemberId: _paidByMemberId!,
              paymentMethod: _paymentMethod,
              accountId: _accountId,
            );
            await ref.read(transactionRepositoryProvider).create(transaction);
            ref.invalidate(transactionsProvider);
          case TxRepeatMode.installments:
            await ref.read(transactionRepositoryProvider).createInstallmentPurchase(
                  householdId: household.id,
                  description: _descriptionController.text.trim(),
                  installmentAmount: amount,
                  installmentCount: _installmentCount,
                  firstDueDate: _date,
                  categoryId: _categoryId!,
                  paidByMemberId: _paidByMemberId!,
                  paymentMethod: _paymentMethod.dbValue,
                );
            ref.invalidate(transactionsProvider);
          case TxRepeatMode.recurring:
            final recurring = models.RecurringTransaction(
              id: '',
              householdId: household.id,
              description: _descriptionController.text.trim(),
              amount: amount,
              categoryId: _categoryId!,
              frequency: _frequency,
              dayOfCycle: _dayOfCycle,
              active: true,
              paymentMethod: _paymentMethod,
              paidByMemberId: _paidByMemberId,
              endDate: _hasEndDate ? _endDate : null,
            );
            final recurringRepo = ref.read(recurringTransactionRepositoryProvider);
            final created = await recurringRepo.create(recurring);
            if (_hasAmountChange) {
              await recurringRepo.addAmountChange(
                recurringTransactionId: created.id,
                effectiveDate: _amountChangeDate!,
                newAmount: _parseAmount(_newAmountController.text)!,
              );
            }
            ref.invalidate(recurringTransactionsProvider);
        }
      }
      Haptics.success();
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      Haptics.warning();
      setState(() => _errorMessage = 'Não foi possível salvar. Tente novamente.');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir lançamento?'),
        content: const Text('Essa ação não pode ser desfeita.'),
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

    setState(() => _isDeleting = true);
    try {
      await ref.read(transactionRepositoryProvider).delete(widget.existing!.id);
      ref.invalidate(transactionsProvider);
      Haptics.success();
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      Haptics.warning();
      setState(() => _errorMessage = 'Não foi possível excluir. Tente novamente.');
    } finally {
      if (mounted) setState(() => _isDeleting = false);
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _date = picked);
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

  String get _amountHint {
    switch (_repeatMode) {
      case TxRepeatMode.installments:
        return 'Valor de cada parcela';
      case TxRepeatMode.once:
      case TxRepeatMode.recurring:
        return '0,00';
    }
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(categoriesProvider);
    final membersAsync = ref.watch(householdMembersProvider);
    final currentMemberAsync = ref.watch(currentMemberProvider);
    final householdId = ref.watch(currentHouseholdProvider).valueOrNull?.id;
    final accountsAsync = ref.watch(accountsProvider);

    currentMemberAsync.whenData((member) {
      if (member != null && _paidByMemberId == null) {
        _paidByMemberId = member.id;
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEditing ? 'Editar lançamento' : 'Novo lançamento'),
        actions: [
          if (widget.isEditing)
            IconButton(
              icon: _isDeleting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.delete_outline_rounded),
              onPressed: _isDeleting ? null : _delete,
            ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.screenPadding),
          child: Form(
            key: _formKey,
            child: ListView(
              children: [
                if (!widget.isEditing) ...[
                  Text('Repetição', style: AppTypography.captionEmphasis),
                  const SizedBox(height: AppSpacing.xs),
                  Wrap(
                    spacing: AppSpacing.xs,
                    children: [
                      ChoiceChip(
                        label: const Text('Uma vez'),
                        selected: _repeatMode == TxRepeatMode.once,
                        onSelected: (_) => setState(() => _repeatMode = TxRepeatMode.once),
                      ),
                      ChoiceChip(
                        label: const Text('Parcelado'),
                        selected: _repeatMode == TxRepeatMode.installments,
                        onSelected: (_) =>
                            setState(() => _repeatMode = TxRepeatMode.installments),
                      ),
                      ChoiceChip(
                        label: const Text('Recorrente'),
                        selected: _repeatMode == TxRepeatMode.recurring,
                        onSelected: (_) => setState(() {
                          _repeatMode = TxRepeatMode.recurring;
                          _type = TransactionType.expense;
                        }),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),
                ],
                if (_repeatMode != TxRepeatMode.recurring) ...[
                  SegmentedButton<TransactionType>(
                    segments: const [
                      ButtonSegment(value: TransactionType.expense, label: Text('Despesa')),
                      ButtonSegment(value: TransactionType.income, label: Text('Receita')),
                    ],
                    selected: {_type},
                    onSelectionChanged: (selection) =>
                        setState(() => _type = selection.first),
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],
                TextFormField(
                  controller: _amountController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: AppTypography.amountLarge,
                  decoration: InputDecoration(hintText: _amountHint, prefixText: 'R\$ '),
                  validator: (value) {
                    final amount = _parseAmount(value ?? '');
                    if (amount == null || amount <= 0) return 'Informe um valor válido';
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.sm),
                TextFormField(
                  controller: _descriptionController,
                  decoration: const InputDecoration(hintText: 'Descrição'),
                  validator: (value) =>
                      (value == null || value.trim().isEmpty) ? 'Informe uma descrição' : null,
                ),
                const SizedBox(height: AppSpacing.lg),
                Text('Categoria', style: AppTypography.captionEmphasis),
                const SizedBox(height: AppSpacing.sm),
                categoriesAsync.when(
                  data: (categories) => _CategoryGrid(
                    categories: categories,
                    selectedId: _categoryId,
                    householdId: householdId,
                    onSelected: (id) => setState(() => _categoryId = id),
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
                Text('Forma de pagamento', style: AppTypography.captionEmphasis),
                const SizedBox(height: AppSpacing.xs),
                Wrap(
                  spacing: AppSpacing.xs,
                  runSpacing: AppSpacing.xs,
                  children: PaymentMethod.values.map((method) {
                    return ChoiceChip(
                      label: Text(method.label),
                      avatar: Icon(paymentMethodIconData(method), size: 16),
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
                accountsAsync.maybeWhen(
                  data: (accounts) {
                    if (accounts.isEmpty) return const SizedBox.shrink();
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Conta (opcional)', style: AppTypography.captionEmphasis),
                        const SizedBox(height: AppSpacing.xs),
                        Wrap(
                          spacing: AppSpacing.xs,
                          runSpacing: AppSpacing.xs,
                          children: accounts.map((account) {
                            final selected = account.id == _accountId;
                            return ChoiceChip(
                              label: Text(account.name),
                              selected: selected,
                              onSelected: (isSelected) => setState(
                                () => _accountId = isSelected ? account.id : null,
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                      ],
                    );
                  },
                  orElse: () => const SizedBox.shrink(),
                ),
                ..._buildTxRepeatModeFields(),
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
                      : Text(widget.isEditing ? 'Salvar alterações' : 'Salvar'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildTxRepeatModeFields() {
    switch (_repeatMode) {
      case TxRepeatMode.once:
        return [
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text('Data', style: AppTypography.captionEmphasis),
            subtitle: Text(DateFormat('dd/MM/yyyy', 'pt_BR').format(_date)),
            trailing: const Icon(Icons.calendar_today_rounded, size: 20),
            onTap: _pickDate,
          ),
        ];
      case TxRepeatMode.installments:
        return [
          Text('Número de parcelas', style: AppTypography.captionEmphasis),
          const SizedBox(height: AppSpacing.xs),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: List.generate(24, (i) => i + 2).map((count) {
              return ChoiceChip(
                label: Text('${count}x'),
                selected: count == _installmentCount,
                onSelected: (_) => setState(() => _installmentCount = count),
              );
            }).toList(),
          ),
          const SizedBox(height: AppSpacing.sm),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text('Primeira parcela vence em', style: AppTypography.captionEmphasis),
            subtitle: Text(DateFormat('dd/MM/yyyy', 'pt_BR').format(_date)),
            trailing: const Icon(Icons.calendar_today_rounded, size: 20),
            onTap: _pickDate,
          ),
        ];
      case TxRepeatMode.recurring:
        return [
          Text('Frequência', style: AppTypography.captionEmphasis),
          const SizedBox(height: AppSpacing.xs),
          Wrap(
            spacing: AppSpacing.xs,
            children: [RecurrenceFrequency.weekly, RecurrenceFrequency.monthly].map((f) {
              return ChoiceChip(
                label: Text(f.label),
                selected: f == _frequency,
                onSelected: (_) => setState(() {
                  _frequency = f;
                  _dayOfCycle = 1;
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
          const SizedBox(height: AppSpacing.sm),
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
          const SizedBox(height: AppSpacing.xs),
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
              decoration: const InputDecoration(hintText: 'Novo valor', prefixText: 'R\$ '),
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
        ];
    }
  }
}

/// Seletor de categoria em grade: círculo colorido com o ícone da própria
/// categoria, nome embaixo — mais visual que uma linha de chips de texto.
class _CategoryGrid extends ConsumerWidget {
  const _CategoryGrid({
    required this.categories,
    required this.selectedId,
    required this.householdId,
    required this.onSelected,
  });

  final List<Category> categories;
  final String? selectedId;
  final String? householdId;
  final ValueChanged<String> onSelected;

  Future<void> _createCategory(BuildContext context, WidgetRef ref) async {
    if (householdId == null) return;
    final result = await showAddCategoryDialog(context);
    if (result == null) return;

    try {
      final category = await ref.read(categoryRepositoryProvider).create(
            householdId: householdId!,
            name: result.name,
            icon: result.icon,
            colorHex: result.colorHex,
          );
      ref.invalidate(categoriesProvider);
      onSelected(category.id);
      Haptics.success();
    } catch (_) {
      Haptics.warning();
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = AppColors.of(context);

    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: [
        ...categories.map((category) {
        final selected = category.id == selectedId;
        final color = colorFromHex(category.colorHex);

        return GestureDetector(
          onTap: () => onSelected(category.id),
          child: SizedBox(
            width: 72,
            child: Column(
              children: [
                AnimatedContainer(
                  duration: AppMotion.fast,
                  curve: AppMotion.enter,
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: selected ? color : color.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                    border: selected ? Border.all(color: color, width: 2) : null,
                  ),
                  child: Icon(
                    categoryIconData(category.icon),
                    color: selected ? palette.background : color,
                    size: 24,
                  ),
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  category.name,
                  style: selected ? AppTypography.captionEmphasis : AppTypography.caption,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        );
        }),
        GestureDetector(
          onTap: () => unawaited(_createCategory(context, ref)),
          child: SizedBox(
            width: 72,
            child: Column(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: palette.backgroundSecondary,
                    shape: BoxShape.circle,
                    border: Border.all(color: palette.border),
                  ),
                  child: Icon(Icons.add_rounded, color: palette.textSecondary),
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  'Nova',
                  style: AppTypography.caption,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
