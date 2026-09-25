import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/providers/app_providers.dart';
import '../../../core/providers/finance_providers.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../models/enums.dart';
import '../../../models/transaction.dart' as models;
import '../../../shared/utils/category_icons.dart';
import '../../../shared/utils/haptics.dart';

class AddTransactionScreen extends ConsumerStatefulWidget {
  const AddTransactionScreen({this.existing, super.key});

  /// Quando presente, a tela edita este lançamento em vez de criar um novo.
  final models.Transaction? existing;

  bool get isEditing => existing != null;

  @override
  ConsumerState<AddTransactionScreen> createState() => _AddTransactionScreenState();
}

class _AddTransactionScreenState extends ConsumerState<AddTransactionScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _amountController;
  late final TextEditingController _descriptionController;

  late TransactionType _type;
  late PaymentMethod _paymentMethod;
  String? _categoryId;
  String? _paidByMemberId;
  late DateTime _date;
  bool _isSubmitting = false;
  bool _isDeleting = false;
  String? _errorMessage;

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
    _date = existing?.date ?? DateTime.now();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
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
      final transaction = models.Transaction(
        id: widget.existing?.id ?? '',
        householdId: household.id,
        type: _type,
        amount: _parseAmount(_amountController.text)!,
        description: _descriptionController.text.trim(),
        categoryId: _categoryId!,
        date: _date,
        paidByMemberId: _paidByMemberId!,
        paymentMethod: _paymentMethod,
      );
      final repository = ref.read(transactionRepositoryProvider);
      if (widget.isEditing) {
        await repository.update(widget.existing!.id, transaction);
      } else {
        await repository.create(transaction);
      }
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
                SegmentedButton<TransactionType>(
                  segments: const [
                    ButtonSegment(
                      value: TransactionType.expense,
                      label: Text('Despesa'),
                    ),
                    ButtonSegment(
                      value: TransactionType.income,
                      label: Text('Receita'),
                    ),
                  ],
                  selected: {_type},
                  onSelectionChanged: (selection) =>
                      setState(() => _type = selection.first),
                ),
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  controller: _amountController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: AppTypography.amountLarge,
                  decoration: const InputDecoration(
                    hintText: '0,00',
                    prefixText: 'R\$ ',
                  ),
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
                const SizedBox(height: AppSpacing.xs),
                categoriesAsync.when(
                  data: (categories) => Wrap(
                    spacing: AppSpacing.xs,
                    runSpacing: AppSpacing.xs,
                    children: categories.map((category) {
                      final selected = category.id == _categoryId;
                      return ChoiceChip(
                        label: Text(category.name),
                        avatar: Icon(categoryIconData(category.icon), size: 18),
                        selected: selected,
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
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('Data', style: AppTypography.captionEmphasis),
                  subtitle: Text(DateFormat('dd/MM/yyyy', 'pt_BR').format(_date)),
                  trailing: const Icon(Icons.calendar_today_rounded, size: 20),
                  onTap: _pickDate,
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
                      : Text(widget.isEditing ? 'Salvar alterações' : 'Salvar'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
