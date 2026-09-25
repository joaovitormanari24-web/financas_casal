import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../goals/screens/goals_screen.dart';
import 'home_shell.dart';

/// Navegação por abas da área logada (Home / Metas). Mantém o estado de
/// cada aba com [IndexedStack] em vez de recriar as telas ao trocar.
class RootShell extends StatefulWidget {
  const RootShell({super.key});

  @override
  State<RootShell> createState() => _RootShellState();
}

class _RootShellState extends State<RootShell> {
  int _index = 0;

  static const _tabs = [
    HomeShell(),
    GoalsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
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
        ],
      ),
    );
  }
}
