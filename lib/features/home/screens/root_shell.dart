import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/finance_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../credit_cards/screens/credit_cards_screen.dart';
import '../../goals/screens/goals_screen.dart';
import '../../recurring/screens/recurring_transactions_screen.dart';
import 'home_shell.dart';

/// Navegação por abas da área logada (Home / Metas). Mantém o estado de
/// cada aba com [IndexedStack] em vez de recriar as telas ao trocar.
class RootShell extends ConsumerStatefulWidget {
  const RootShell({super.key});

  @override
  ConsumerState<RootShell> createState() => _RootShellState();
}

class _RootShellState extends ConsumerState<RootShell> {
  int _index = 0;

  static const _tabs = [
    HomeShell(),
    GoalsScreen(),
    RecurringTransactionsScreen(),
    CreditCardsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    // Mantém a sincronização em tempo real ativa enquanto o usuário está
    // logado — lançamentos/aportes do parceiro(a) aparecem sem recarregar.
    ref.watch(realtimeSyncProvider);

    final palette = AppColors.of(context);

    return Scaffold(
      body: IndexedStack(index: _index, children: _tabs),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (value) => setState(() => _index = value),
        backgroundColor: palette.surface,
        indicatorColor: palette.accentMuted,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.track_changes_outlined),
            selectedIcon: Icon(Icons.track_changes_rounded),
            label: 'Metas',
          ),
          NavigationDestination(
            icon: Icon(Icons.autorenew_outlined),
            selectedIcon: Icon(Icons.autorenew_rounded),
            label: 'Recorrentes',
          ),
          NavigationDestination(
            icon: Icon(Icons.credit_card_outlined),
            selectedIcon: Icon(Icons.credit_card_rounded),
            label: 'Cartões',
          ),
        ],
      ),
    );
  }
}
