import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/app_providers.dart';
import '../../../core/providers/finance_providers.dart';
import '../../../core/providers/theme_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../models/accounts.dart';
import '../../../models/category.dart';
import '../../../shared/utils/category_icons.dart';
import '../../../shared/utils/haptics.dart';
import '../../transactions/screens/add_category_dialog.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _nameController = TextEditingController();
  bool _isSavingName = false;
  bool _isLeaving = false;
  String? _prefilledFrom;

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

  Future<void> _addAccount() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Nova conta'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(hintText: 'Nome (ex.: "Nubank")'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: const Text('Criar'),
          ),
        ],
      ),
    );
    if (name == null || name.isEmpty) return;

    final household = ref.read(currentHouseholdProvider).valueOrNull;
    if (household == null) return;

    try {
      await ref.read(accountRepositoryProvider).create(
            Account(id: '', householdId: household.id, name: name, ownerMemberId: null),
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
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline_rounded, size: 20),
                          onPressed: () => _deleteAccount(account.id),
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
          ],
        ),
      ),
    );
  }
}
