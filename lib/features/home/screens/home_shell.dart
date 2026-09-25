import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/app_providers.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/utils/haptics.dart';

/// Shell temporário da área logada. Vira a navegação por abas (Home,
/// Lançamentos, Metas, Perfil) na próxima etapa.
class HomeShell extends ConsumerWidget {
  const HomeShell({super.key});

  Future<void> _showInviteCode(BuildContext context, WidgetRef ref, String householdId) async {
    try {
      final code = await ref
          .read(householdRepositoryProvider)
          .createInvite(householdId: householdId);
      if (!context.mounted) return;
      unawaited(showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Código de convite'),
          content: Text(
            'Compartilhe "$code" com seu parceiro(a). Válido por 7 dias.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Fechar'),
            ),
          ],
        ),
      ));
    } catch (_) {
      Haptics.warning();
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final householdAsync = ref.watch(currentHouseholdProvider);

    return Scaffold(
      appBar: AppBar(
        title: householdAsync.when(
          data: (household) => Text(household?.name ?? 'Finanças do Casal'),
          loading: () => const Text('Finanças do Casal'),
          error: (_, __) => const Text('Finanças do Casal'),
        ),
        actions: [
          householdAsync.maybeWhen(
            data: (household) => household == null
                ? const SizedBox.shrink()
                : IconButton(
                    icon: const Icon(Icons.person_add_alt_outlined),
                    tooltip: 'Convidar parceiro(a)',
                    onPressed: () =>
                        unawaited(_showInviteCode(context, ref, household.id)),
                  ),
            orElse: () => const SizedBox.shrink(),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sair',
            onPressed: () => unawaited(ref.read(authRepositoryProvider).signOut()),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.screenPadding),
        child: Center(
          child: Text(
            'Home em construção — próximo passo: resumo do mês, lançamentos e metas.',
            style: AppTypography.body,
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
