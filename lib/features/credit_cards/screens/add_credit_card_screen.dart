import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/app_providers.dart';
import '../../../core/providers/finance_providers.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../models/accounts.dart';
import '../../../shared/utils/haptics.dart';

class AddCreditCardScreen extends ConsumerStatefulWidget {
  const AddCreditCardScreen({super.key});

  @override
  ConsumerState<AddCreditCardScreen> createState() => _AddCreditCardScreenState();
}

class _AddCreditCardScreenState extends ConsumerState<AddCreditCardScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _institutionController = TextEditingController();
  final _limitController = TextEditingController();

  int _closingDay = 1;
  int _dueDay = 10;
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _nameController.dispose();
    _institutionController.dispose();
    _limitController.dispose();
    super.dispose();
  }

  double? _parseAmount(String raw) {
    final normalized = raw.replaceAll('.', '').replaceAll(',', '.');
    return double.tryParse(normalized);
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
      final card = CreditCard(
        id: '',
        householdId: household.id,
        name: _nameController.text.trim(),
        institution: _institutionController.text.trim(),
        limit: _parseAmount(_limitController.text) ?? 0,
        closingDay: _closingDay,
        dueDay: _dueDay,
      );
      await ref.read(creditCardRepositoryProvider).create(card);
      ref.invalidate(creditCardsProvider);
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
      appBar: AppBar(title: const Text('Novo cartão')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.screenPadding),
          child: Form(
            key: _formKey,
            child: ListView(
              children: [
                TextFormField(
                  controller: _nameController,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(hintText: 'Nome (ex.: "Nubank")'),
                  validator: (value) =>
                      (value == null || value.trim().isEmpty) ? 'Informe um nome' : null,
                ),
                const SizedBox(height: AppSpacing.sm),
                TextFormField(
                  controller: _institutionController,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(hintText: 'Instituição (ex.: "Nubank")'),
                  validator: (value) =>
                      (value == null || value.trim().isEmpty) ? 'Informe a instituição' : null,
                ),
                const SizedBox(height: AppSpacing.sm),
                TextFormField(
                  controller: _limitController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(hintText: 'Limite', prefixText: 'R\$ '),
                  validator: (value) {
                    final amount = _parseAmount(value ?? '');
                    if (amount == null || amount < 0) return 'Informe um limite válido';
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.lg),
                Text('Dia do fechamento', style: AppTypography.captionEmphasis),
                const SizedBox(height: AppSpacing.xs),
                Wrap(
                  spacing: AppSpacing.xs,
                  runSpacing: AppSpacing.xs,
                  children: List.generate(31, (i) => i + 1).map((day) {
                    return ChoiceChip(
                      label: Text('$day'),
                      selected: day == _closingDay,
                      onSelected: (_) => setState(() => _closingDay = day),
                    );
                  }).toList(),
                ),
                const SizedBox(height: AppSpacing.lg),
                Text('Dia do vencimento', style: AppTypography.captionEmphasis),
                const SizedBox(height: AppSpacing.xs),
                Wrap(
                  spacing: AppSpacing.xs,
                  runSpacing: AppSpacing.xs,
                  children: List.generate(31, (i) => i + 1).map((day) {
                    return ChoiceChip(
                      label: Text('$day'),
                      selected: day == _dueDay,
                      onSelected: (_) => setState(() => _dueDay = day),
                    );
                  }).toList(),
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
