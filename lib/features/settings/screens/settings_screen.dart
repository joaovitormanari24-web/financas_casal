import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/providers/app_lock_provider.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/providers/finance_providers.dart';
import '../../../core/providers/theme_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../models/accounts.dart';
import '../../../models/category.dart';
import '../../../shared/services/push_notification_service.dart';
import '../../../shared/utils/category_icons.dart';
import '../../../shared/utils/currency_formatter.dart';
import '../../../shared/utils/haptics.dart';
import '../../transactions/screens/add_category_dialog.dart';
import '../../accounts/screens/account_detail_screen.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _nameController = TextEditingController();
  final _pushService = const PushNotificationService();
  bool _isSavingName = false;
  bool _isLeaving = false;
  bool _isDeletingAccount = false;
  String? _prefilledFrom;

  bool _pushSupported = true;
  bool _pushEnabled = false;
  bool _isTogglingPush = false;

  @override
  void initState() {
    super.initState();
    unawaited(_checkPushStatus());
  }

  Future<void> _checkPushStatus() async {
    if (!_pushService.isSupported) {
      if (mounted) setState(() => _pushSupported = false);
      return;
    }
    try {
      final endpoint = await _pushService.currentEndpoint();
      if (mounted) setState(() => _pushEnabled = endpoint != null);
    } catch (_) {
      // Mantém o switch desligado — usuário pode tentar ativar manualmente.
    }
  }

  Future<void> _togglePush(bool value) async {
    final member = ref.read(currentMemberProvider).valueOrNull;
    final household = ref.read(currentHouseholdProvider).valueOrNull;
    if (member == null || household == null) return;

    setState(() => _isTogglingPush = true);
    try {
      if (value) {
        final sub = await _pushService.subscribe();
        await ref.read(pushSubscriptionRepositoryProvider).save(
              householdId: household.id,
              memberId: member.id,
              endpoint: sub.endpoint,
              p256dh: sub.p256dh,
              auth: sub.auth,
            );
        if (mounted) setState(() => _pushEnabled = true);
      } else {
        final endpoint = await _pushService.currentEndpoint();
        await _pushService.unsubscribe();
        if (endpoint != null) {
          await ref.read(pushSubscriptionRepositoryProvider).deleteByEndpoint(endpoint);
        }
        if (mounted) setState(() => _pushEnabled = false);
      }
      Haptics.success();
    } catch (_) {
      Haptics.warning();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Não foi possível ativar. Verifique a permissão de notificações do navegador.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isTogglingPush = false);
    }
  }

  Future<String?> _promptForNewPin() async {
    final pinController = TextEditingController();
    final confirmController = TextEditingController();
    String? error;
    final result = await showDialog<String>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Criar PIN'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: pinController,
                obscureText: true,
                autofocus: true,
                keyboardType: TextInputType.number,
                maxLength: 4,
                decoration: const InputDecoration(labelText: 'PIN (4 dígitos)', counterText: ''),
              ),
              TextField(
                controller: confirmController,
                obscureText: true,
                keyboardType: TextInputType.number,
                maxLength: 4,
                decoration: const InputDecoration(labelText: 'Confirme o PIN', counterText: ''),
              ),
              if (error != null) ...[
                const SizedBox(height: AppSpacing.xs),
                Text(error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () {
                final pin = pinController.text.trim();
                final confirm = confirmController.text.trim();
                if (pin.length != 4 || int.tryParse(pin) == null) {
                  setDialogState(() => error = 'Use 4 dígitos numéricos');
                  return;
                }
                if (pin != confirm) {
                  setDialogState(() => error = 'Os PINs não coincidem');
                  return;
                }
                Navigator.of(context).pop(pin);
              },
              child: const Text('Salvar'),
            ),
          ],
        ),
      ),
    );
    pinController.dispose();
    confirmController.dispose();
    return result;
  }

  Future<String?> _promptForCurrentPin() async {
    final controller = TextEditingController();
    String? error;
    final result = await showDialog<String>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Confirme o PIN atual'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: controller,
                obscureText: true,
                autofocus: true,
                keyboardType: TextInputType.number,
                maxLength: 4,
                decoration: const InputDecoration(labelText: 'PIN', counterText: ''),
              ),
              if (error != null) ...[
                const SizedBox(height: AppSpacing.xs),
                Text(error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () {
                final pin = controller.text.trim();
                if (!ref.read(appLockProvider.notifier).verify(pin)) {
                  setDialogState(() => error = 'PIN incorreto');
                  return;
                }
                Navigator.of(context).pop(pin);
              },
              child: const Text('Confirmar'),
            ),
          ],
        ),
      ),
    );
    controller.dispose();
    return result;
  }

  Future<void> _enablePinLock() async {
    final pin = await _promptForNewPin();
    if (pin == null) return;
    await ref.read(appLockProvider.notifier).setPin(pin);
    ref.read(appUnlockedProvider.notifier).state = true;
    Haptics.success();
  }

  Future<void> _disablePinLock() async {
    final pin = await _promptForCurrentPin();
    if (pin == null) return;
    await ref.read(appLockProvider.notifier).clearPin();
    Haptics.success();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _saveName(String memberId) async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    setState(() => _isSavingName = true);
    try {
      await ref.read(householdRepositoryProvider).updateDisplayName(
            memberId: memberId,
            displayName: name,
          );
      await ref.read(profileRepositoryProvider).updateFullName(name);
      ref.invalidate(householdMembersProvider);
      ref.invalidate(currentMemberProvider);
      ref.invalidate(currentProfileProvider);
      Haptics.success();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Nome atualizado.')),
        );
      }
    } catch (_) {
      Haptics.warning();
    } finally {
      if (mounted) setState(() => _isSavingName = false);
    }
  }

  Future<void> _leaveHousehold(String memberId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sair do household?'),
        content: const Text(
          'Você perde acesso aos lançamentos, metas e recorrências '
          'compartilhados. Essa ação não pode ser desfeita.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(
              'Sair',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _isLeaving = true);
    try {
      await ref.read(householdRepositoryProvider).leaveHousehold(memberId);
      ref.invalidate(currentHouseholdProvider);
      Haptics.success();
      if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (_) {
      Haptics.warning();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Não foi possível sair — você já tem lançamentos registrados '
              'neste household.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLeaving = false);
    }
  }

  Future<void> _deleteAccountAndData() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir sua conta e todos os dados?'),
        content: const Text(
          'Isso apaga seu login permanentemente e, se você for o único membro '
          'do household, todos os lançamentos, metas, orçamentos e '
          'configurações junto. Não pode ser desfeito.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(
              'Excluir tudo',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _isDeletingAccount = true);
    try {
      await ref.read(supabaseClientProvider).functions.invoke('delete-account');
      Haptics.success();
      if (mounted) await ref.read(authRepositoryProvider).signOut();
    } on FunctionsHttpException catch (e) {
      final details = e.details;
      final message = details is Map
          ? details['message'] as String?
          : null;
      Haptics.warning();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message ?? 'Não foi possível excluir sua conta agora.'),
          ),
        );
      }
    } catch (_) {
      Haptics.warning();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Não foi possível excluir sua conta. Tente novamente.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isDeletingAccount = false);
    }
  }

  Future<void> _editCategory(Category category) async {
    final result = await showAddCategoryDialog(
      context,
      existing: NewCategoryResult(
        name: category.name,
        icon: category.icon,
        colorHex: category.colorHex,
      ),
    );
    if (result == null) return;

    try {
      await ref.read(categoryRepositoryProvider).update(
            id: category.id,
            name: result.name,
            icon: result.icon,
            colorHex: result.colorHex,
          );
      ref.invalidate(categoriesProvider);
      Haptics.success();
    } catch (_) {
      Haptics.warning();
    }
  }

  Future<void> _deleteCategory(Category category) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir categoria?'),
        content: Text('Lançamentos que já usam "${category.name}" não são afetados.'),
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
      await ref.read(categoryRepositoryProvider).delete(category.id);
      ref.invalidate(categoriesProvider);
      Haptics.success();
    } catch (_) {
      Haptics.warning();
    }
  }

  Future<({String name, double initialBalance})?> _promptAccountDetails({Account? existing}) async {
    final nameController = TextEditingController(text: existing?.name ?? '');
    final balanceController = TextEditingController(
      text: existing == null
          ? ''
          : existing.initialBalance.toStringAsFixed(2).replaceAll('.', ','),
    );
    final result = await showDialog<({String name, double initialBalance})>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(existing == null ? 'Nova conta' : 'Editar conta'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(hintText: 'Nome (ex.: "Nubank")'),
            ),
            const SizedBox(height: AppSpacing.xs),
            TextField(
              controller: balanceController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(hintText: 'Saldo inicial', prefixText: 'R\$ '),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              final name = nameController.text.trim();
              if (name.isEmpty) return;
              final raw = balanceController.text.trim().replaceAll('.', '').replaceAll(',', '.');
              final balance = double.tryParse(raw) ?? 0;
              Navigator.of(context).pop((name: name, initialBalance: balance));
            },
            child: Text(existing == null ? 'Criar' : 'Salvar'),
          ),
        ],
      ),
    );
    nameController.dispose();
    balanceController.dispose();
    return result;
  }

  Future<void> _addAccount() async {
    final input = await _promptAccountDetails();
    if (input == null) return;

    final household = ref.read(currentHouseholdProvider).valueOrNull;
    if (household == null) return;

    try {
      await ref.read(accountRepositoryProvider).create(
            Account(
              id: '',
              householdId: household.id,
              name: input.name,
              ownerMemberId: null,
              initialBalance: input.initialBalance,
            ),
          );
      ref.invalidate(accountsProvider);
      Haptics.success();
    } catch (_) {
      Haptics.warning();
    }
  }

  Future<void> _editAccount(Account account) async {
    final input = await _promptAccountDetails(existing: account);
    if (input == null) return;

    try {
      await ref.read(accountRepositoryProvider).update(
            id: account.id,
            name: input.name,
            initialBalance: input.initialBalance,
          );
      ref.invalidate(accountsProvider);
      Haptics.success();
    } catch (_) {
      Haptics.warning();
    }
  }

  Future<void> _deleteAccount(String id) async {
    try {
      await ref.read(accountRepositoryProvider).delete(id);
      ref.invalidate(accountsProvider);
      Haptics.success();
    } catch (_) {
      Haptics.warning();
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.of(context);
    final currentMemberAsync = ref.watch(currentMemberProvider);
    final membersAsync = ref.watch(householdMembersProvider);
    final categoriesAsync = ref.watch(categoriesProvider);
    final accountsAsync = ref.watch(accountsProvider);
    final themeMode = ref.watch(themeModeProvider);

    currentMemberAsync.whenData((member) {
      if (member != null && _prefilledFrom != member.id) {
        _prefilledFrom = member.id;
        _nameController.text = member.displayName;
      }
    });

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: 'Voltar',
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: const Text('Configurações'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.screenPadding),
          children: [
            Text('Seu nome', style: AppTypography.captionEmphasis),
            const SizedBox(height: AppSpacing.xs),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _nameController,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(hintText: 'Seu nome'),
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                currentMemberAsync.maybeWhen(
                  data: (member) => member == null
                      ? const SizedBox.shrink()
                      : IconButton(
                          icon: _isSavingName
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.check_circle_outline_rounded),
                          onPressed: _isSavingName ? null : () => _saveName(member.id),
                        ),
                  orElse: () => const SizedBox.shrink(),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            Text('Membros do household', style: AppTypography.captionEmphasis),
            const SizedBox(height: AppSpacing.xs),
            membersAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
                child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
              ),
              error: (_, __) => Text(
                'Não foi possível carregar.',
                style: AppTypography.caption,
              ),
              data: (members) {
                final currentId = currentMemberAsync.valueOrNull?.id;
                return Card(
                  child: Column(
                    children: members.map((member) {
                      final isSelf = member.id == currentId;
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: palette.accentMuted,
                          foregroundColor: palette.accent,
                          child: Text(
                            member.displayName.isEmpty
                                ? '?'
                                : member.displayName[0].toUpperCase(),
                          ),
                        ),
                        title: Text(member.displayName),
                        trailing: isSelf
                            ? Text('Você', style: AppTypography.caption)
                            : null,
                      );
                    }).toList(),
                  ),
                );
              },
            ),
            const SizedBox(height: AppSpacing.lg),
            Text('Tema', style: AppTypography.captionEmphasis),
            const SizedBox(height: AppSpacing.xs),
            Card(
              child: RadioGroup<ThemeMode>(
                groupValue: themeMode,
                onChanged: (mode) => ref.read(themeModeProvider.notifier).setThemeMode(mode!),
                child: const Column(
                  children: [
                    RadioListTile<ThemeMode>(title: Text('Claro'), value: ThemeMode.light),
                    RadioListTile<ThemeMode>(title: Text('Escuro'), value: ThemeMode.dark),
                    RadioListTile<ThemeMode>(
                      title: Text('Automático'),
                      value: ThemeMode.system,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text('Notificações', style: AppTypography.captionEmphasis),
            const SizedBox(height: AppSpacing.xs),
            Card(
              child: SwitchListTile(
                title: const Text('Avisos push no navegador'),
                subtitle: Text(
                  !_pushSupported
                      ? 'Não suportado neste navegador.'
                      : 'Conta recorrente lançada, orçamento estourado e metas atingidas, '
                          'mesmo com o app fechado.',
                  style: AppTypography.caption,
                ),
                value: _pushEnabled,
                onChanged: (!_pushSupported || _isTogglingPush)
                    ? null
                    : (value) => unawaited(_togglePush(value)),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text('Segurança', style: AppTypography.captionEmphasis),
            const SizedBox(height: AppSpacing.xs),
            Consumer(
              builder: (context, ref, _) {
                final hasPin = ref.watch(appLockProvider).valueOrNull != null;
                return Card(
                  child: SwitchListTile(
                    title: const Text('Bloquear o app com PIN'),
                    subtitle: Text(
                      hasPin
                          ? 'Ativado neste dispositivo.'
                          : 'Pede um PIN de 4 dígitos toda vez que o app é aberto.',
                      style: AppTypography.caption,
                    ),
                    value: hasPin,
                    onChanged: (value) => unawaited(value ? _enablePinLock() : _disablePinLock()),
                  ),
                );
              },
            ),
            const SizedBox(height: AppSpacing.lg),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Categorias personalizadas', style: AppTypography.captionEmphasis),
                TextButton.icon(
                  onPressed: () async {
                    final result = await showAddCategoryDialog(context);
                    if (result == null) return;
                    final household = ref.read(currentHouseholdProvider).valueOrNull;
                    if (household == null) return;
                    try {
                      await ref.read(categoryRepositoryProvider).create(
                            householdId: household.id,
                            name: result.name,
                            icon: result.icon,
                            colorHex: result.colorHex,
                          );
                      ref.invalidate(categoriesProvider);
                      Haptics.success();
                    } catch (_) {
                      Haptics.warning();
                    }
                  },
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Nova'),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            categoriesAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
                child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
              ),
              error: (_, __) => Text('Não foi possível carregar.', style: AppTypography.caption),
              data: (categories) {
                final custom = categories.where((c) => c.isCustom).toList();
                if (custom.isEmpty) {
                  return Text(
                    'Nenhuma categoria personalizada ainda.',
                    style: AppTypography.caption.copyWith(color: palette.textTertiary),
                  );
                }
                return Card(
                  child: Column(
                    children: custom.map((category) {
                      final color = colorFromHex(category.colorHex);
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: color.withValues(alpha: 0.15),
                          foregroundColor: color,
                          child: Icon(categoryIconData(category.icon), size: 18),
                        ),
                        title: Text(category.name),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit_outlined, size: 20),
                              onPressed: () => _editCategory(category),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline_rounded, size: 20),
                              onPressed: () => _deleteCategory(category),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                );
              },
            ),
            const SizedBox(height: AppSpacing.lg),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Contas', style: AppTypography.captionEmphasis),
                TextButton.icon(
                  onPressed: () => _addAccount(),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Nova'),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            accountsAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
                child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
              ),
              error: (_, __) => Text('Não foi possível carregar.', style: AppTypography.caption),
              data: (accounts) {
                if (accounts.isEmpty) {
                  return Text(
                    'Nenhuma conta cadastrada ainda.',
                    style: AppTypography.caption.copyWith(color: palette.textTertiary),
                  );
                }
                return Card(
                  child: Column(
                    children: accounts.map((account) {
                      return ListTile(
                        leading: const Icon(Icons.account_balance_outlined),
                        title: Text(account.name),
                        subtitle: Text(
                          CurrencyFormatter.format(account.currentBalance ?? account.initialBalance),
                          style: AppTypography.caption,
                        ),
                        onTap: () => unawaited(
                          Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => AccountDetailScreen(account: account)),
                          ),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit_outlined, size: 20),
                              onPressed: () => _editAccount(account),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline_rounded, size: 20),
                              onPressed: () => _deleteAccount(account.id),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                );
              },
            ),
            const SizedBox(height: AppSpacing.xxl),
            OutlinedButton(
              onPressed: _isLeaving || currentMemberAsync.valueOrNull == null
                  ? null
                  : () => _leaveHousehold(currentMemberAsync.value!.id),
              style: OutlinedButton.styleFrom(
                foregroundColor: palette.warning,
                side: BorderSide(color: palette.warning),
              ),
              child: _isLeaving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Sair do household'),
            ),
            const SizedBox(height: AppSpacing.sm),
            OutlinedButton(
              onPressed: _isDeletingAccount ? null : () => unawaited(_deleteAccountAndData()),
              style: OutlinedButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.error,
                side: BorderSide(color: Theme.of(context).colorScheme.error),
              ),
              child: _isDeletingAccount
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Excluir minha conta e dados'),
            ),
          ],
        ),
      ),
    );
  }
}
