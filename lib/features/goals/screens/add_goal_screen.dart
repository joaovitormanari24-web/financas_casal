import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/providers/app_providers.dart';
import '../../../core/providers/finance_providers.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../models/goal.dart';
import '../../../shared/utils/haptics.dart';

class AddGoalScreen extends ConsumerStatefulWidget {
  const AddGoalScreen({this.existing, super.key});

  /// Quando presente, a tela edita esta meta em vez de criar uma nova.
  final Goal? existing;

  bool get isEditing => existing != null;

  @override
  ConsumerState<AddGoalScreen> createState() => _AddGoalScreenState();
}

class _AddGoalScreenState extends ConsumerState<AddGoalScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _targetAmountController;
  late final TextEditingController _monthlyContributionController;

  DateTime? _targetDate;
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _nameController = TextEditingController(text: existing?.name ?? '');
    _targetAmountController = TextEditingController(
      text: existing == null ? '' : existing.targetAmount.toStringAsFixed(2).replaceAll('.', ','),
    );
    _monthlyContributionController = TextEditingController(
      text: existing?.monthlyContribution == null
          ? ''
          : existing!.monthlyContribution!.toStringAsFixed(2).replaceAll('.', ','),
    );
    _targetDate = existing?.targetDate;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _targetAmountController.dispose();
    _monthlyContributionController.dispose();
    super.dispose();
  }

  double? _parseAmount(String raw) {
    if (raw.trim().isEmpty) return null;
    final normalized = raw.replaceAll('.', '').replaceAll(',', '.');
    return double.tryParse(normalized);
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _targetDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _targetDate = picked);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final household = ref.read(currentHouseholdProvider).valueOrNull;
    if (household == null) return;

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final repository = ref.read(goalRepositoryProvider);
      if (widget.isEditing) {
        await repository.update(
          id: widget.existing!.id,
          name: _nameController.text.trim(),
          targetAmount: _parseAmount(_targetAmountController.text)!,
          targetDate: _targetDate,
          monthlyContribution: _parseAmount(_monthlyContributionController.text),
        );
      } else {
        await repository.create(
          householdId: household.id,
          name: _nameController.text.trim(),
          targetAmount: _parseAmount(_targetAmountController.text)!,
          targetDate: _targetDate,
          monthlyContribution: _parseAmount(_monthlyContributionController.text),
        );
      }
      ref.invalidate(goalsProvider);
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
    return Scaffold(
      appBar: AppBar(title: Text(widget.isEditing ? 'Editar meta' : 'Nova meta')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.screenPadding),
          child: Form(
            key: _formKey,
            child: ListView(
              children: [
                TextFormField(
                  controller: _nameController,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(hintText: 'Nome da meta (ex.: "Viagem")'),
                  validator: (value) =>
                      (value == null || value.trim().isEmpty) ? 'Informe um nome' : null,
                ),
                const SizedBox(height: AppSpacing.sm),
                TextFormField(
                  controller: _targetAmountController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: AppTypography.amountMedium,
                  decoration: const InputDecoration(hintText: '0,00', prefixText: 'R\$ '),
                  validator: (value) {
                    final amount = _parseAmount(value ?? '');
                    if (amount == null || amount <= 0) return 'Informe um valor válido';
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.sm),
                TextFormField(
                  controller: _monthlyContributionController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    hintText: 'Aporte mensal planejado (opcional)',
                    prefixText: 'R\$ ',
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('Data alvo (opcional)', style: AppTypography.captionEmphasis),
                  subtitle: Text(
                    _targetDate == null
                        ? 'Sem data definida'
                        : DateFormat('dd/MM/yyyy', 'pt_BR').format(_targetDate!),
                  ),
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
                      : Text(widget.isEditing ? 'Salvar alterações' : 'Criar meta'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
