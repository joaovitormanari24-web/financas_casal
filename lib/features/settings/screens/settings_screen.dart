import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/app_providers.dart';
import '../../../core/providers/finance_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/utils/haptics.dart';

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

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.of(context);
    final currentMemberAsync = ref.watch(currentMemberProvider);
    final membersAsync = ref.watch(householdMembersProvider);

    currentMemberAsync.whenData((member) {
      if (member != null && _prefilledFrom != member.id) {
        _prefilledFrom = member.id;
        _nameController.text = member.displayName;
      }
    });

    return Scaffold(
      appBar: AppBar(title: const Text('Configurações')),
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
