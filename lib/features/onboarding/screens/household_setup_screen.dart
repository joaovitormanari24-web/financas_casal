import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers/app_providers.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/utils/haptics.dart';

/// Passo obrigatório após o cadastro: o casal precisa de um household
/// para que os dados financeiros nunca fiquem soltos num usuário isolado
/// (briefing, seção 9). Refresh do go_router acontece automaticamente
/// via [AppRouter._redirect] ao completar este fluxo.
class HouseholdSetupScreen extends ConsumerStatefulWidget {
  const HouseholdSetupScreen({super.key});

  @override
  ConsumerState<HouseholdSetupScreen> createState() =>
      _HouseholdSetupScreenState();
}

class _HouseholdSetupScreenState extends ConsumerState<HouseholdSetupScreen> {
  bool _isJoining = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.screenPadding,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: AppSpacing.xl),
              Text('Vamos começar', style: AppTypography.title),
              const SizedBox(height: AppSpacing.xxs),
              Text(
                'Crie um espaço para o casal ou entre com um código de '
                'convite de quem já criou.',
                style: AppTypography.body,
              ),
              const SizedBox(height: AppSpacing.lg),
              _SetupModeToggle(
                isJoining: _isJoining,
                onChanged: (value) => setState(() => _isJoining = value),
              ),
              const SizedBox(height: AppSpacing.lg),
              Expanded(
                child: _isJoining
                    ? const _JoinHouseholdForm()
                    : const _CreateHouseholdForm(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SetupModeToggle extends StatelessWidget {
  const _SetupModeToggle({
    required this.isJoining,
    required this.onChanged,
  });

  final bool isJoining;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _SegmentTab(
            label: 'Criar',
            selected: !isJoining,
            onTap: () => onChanged(false),
          ),
        ),
        const SizedBox(width: AppSpacing.xs),
        Expanded(
          child: _SegmentTab(
            label: 'Entrar com código',
            selected: isJoining,
            onTap: () => onChanged(true),
          ),
        ),
      ],
    );
  }
}

class _SegmentTab extends StatelessWidget {
  const _SegmentTab({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        backgroundColor: selected ? scheme.primary : null,
        foregroundColor: selected ? scheme.onPrimary : null,
        side: BorderSide(color: scheme.primary.withValues(alpha: 0.3)),
      ),
      child: Text(label),
    );
  }
}

class _CreateHouseholdForm extends ConsumerStatefulWidget {
  const _CreateHouseholdForm();

  @override
  ConsumerState<_CreateHouseholdForm> createState() =>
      _CreateHouseholdFormState();
}

class _CreateHouseholdFormState extends ConsumerState<_CreateHouseholdForm> {
  final _formKey = GlobalKey<FormState>();
  final _householdNameController = TextEditingController();
  final _displayNameController = TextEditingController();

  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _householdNameController.dispose();
    _displayNameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      await ref.read(householdRepositoryProvider).createHousehold(
            householdName: _householdNameController.text.trim(),
            displayName: _displayNameController.text.trim(),
          );
      ref.invalidate(currentHouseholdProvider);
      Haptics.success();
      if (mounted) context.go(AppRoutes.home);
    } catch (_) {
      Haptics.warning();
      setState(() => _errorMessage = 'Não foi possível criar o espaço. Tente novamente.');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: _householdNameController,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(hintText: 'Nome do espaço (ex.: "Nós dois")'),
            validator: (value) =>
                (value == null || value.trim().isEmpty) ? 'Informe um nome' : null,
          ),
          const SizedBox(height: AppSpacing.sm),
          TextFormField(
            controller: _displayNameController,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(hintText: 'Como te chamamos?'),
            validator: (value) =>
                (value == null || value.trim().isEmpty) ? 'Informe seu nome' : null,
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
                : const Text('Criar espaço'),
          ),
        ],
      ),
    );
  }
}

class _JoinHouseholdForm extends ConsumerStatefulWidget {
  const _JoinHouseholdForm();

  @override
  ConsumerState<_JoinHouseholdForm> createState() => _JoinHouseholdFormState();
}

class _JoinHouseholdFormState extends ConsumerState<_JoinHouseholdForm> {
  final _formKey = GlobalKey<FormState>();
  final _codeController = TextEditingController();
  final _displayNameController = TextEditingController();

  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _codeController.dispose();
    _displayNameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      await ref.read(householdRepositoryProvider).redeemInvite(
            code: _codeController.text.trim().toUpperCase(),
            displayName: _displayNameController.text.trim(),
          );
      ref.invalidate(currentHouseholdProvider);
      Haptics.success();
      if (mounted) context.go(AppRoutes.home);
    } catch (_) {
      Haptics.warning();
      setState(() => _errorMessage = 'Código inválido ou expirado.');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: _codeController,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(hintText: 'Código de convite'),
            validator: (value) =>
                (value == null || value.trim().isEmpty) ? 'Informe o código' : null,
          ),
          const SizedBox(height: AppSpacing.sm),
          TextFormField(
            controller: _displayNameController,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(hintText: 'Como te chamamos?'),
            validator: (value) =>
                (value == null || value.trim().isEmpty) ? 'Informe seu nome' : null,
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
                : const Text('Entrar'),
          ),
        ],
      ),
    );
  }
}
