import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/app_lock_provider.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/utils/haptics.dart';

/// Tela de bloqueio local — mostrada por cima de tudo (ver [main.dart])
/// enquanto houver um PIN configurado e a sessão atual ainda não foi
/// destravada.
class AppLockScreen extends ConsumerStatefulWidget {
  const AppLockScreen({super.key});

  @override
  ConsumerState<AppLockScreen> createState() => _AppLockScreenState();
}

class _AppLockScreenState extends ConsumerState<AppLockScreen> {
  String _entered = '';
  bool _isWrong = false;

  Future<void> _onDigit(String digit) async {
    if (_entered.length >= 4) return;
    setState(() {
      _entered += digit;
      _isWrong = false;
    });
    if (_entered.length == 4) {
      final ok = ref.read(appLockProvider.notifier).verify(_entered);
      if (ok) {
        Haptics.success();
        ref.read(appUnlockedProvider.notifier).state = true;
      } else {
        Haptics.warning();
        setState(() => _isWrong = true);
        await Future<void>.delayed(const Duration(milliseconds: 500));
        if (mounted) setState(() => _entered = '');
      }
    }
  }

  void _onBackspace() {
    if (_entered.isEmpty) return;
    setState(() => _entered = _entered.substring(0, _entered.length - 1));
  }

  Future<void> _forgotPin() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Esqueceu o PIN?'),
        content: const Text(
          'Vamos te desconectar — ao entrar de novo com seu e-mail e senha, '
          'o bloqueio por PIN é desativado (dá pra configurar um novo depois '
          'em Configurações).',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Sair e entrar de novo'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    await ref.read(appLockProvider.notifier).clearPin();
    ref.read(appUnlockedProvider.notifier).state = true;
    await ref.read(authRepositoryProvider).signOut();
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.of(context);

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.screenPadding),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.lock_outline_rounded, size: 40, color: palette.textSecondary),
              const SizedBox(height: AppSpacing.md),
              Text('Digite seu PIN', style: AppTypography.title),
              const SizedBox(height: AppSpacing.lg),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(4, (i) {
                  final filled = i < _entered.length;
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _isWrong
                          ? palette.expense
                          : (filled ? palette.accent : palette.backgroundSecondary),
                      border: Border.all(color: palette.border),
                    ),
                  );
                }),
              ),
              const SizedBox(height: AppSpacing.xxl),
              _PinPad(onDigit: (d) => unawaited(_onDigit(d)), onBackspace: _onBackspace),
              const SizedBox(height: AppSpacing.lg),
              TextButton(
                onPressed: () => unawaited(_forgotPin()),
                child: const Text('Esqueceu o PIN?'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PinPad extends StatelessWidget {
  const _PinPad({required this.onDigit, required this.onBackspace});

  final ValueChanged<String> onDigit;
  final VoidCallback onBackspace;

  @override
  Widget build(BuildContext context) {
    const rows = [
      ['1', '2', '3'],
      ['4', '5', '6'],
      ['7', '8', '9'],
      ['', '0', '⌫'],
    ];

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: rows.map((row) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: row.map((key) {
              if (key.isEmpty) return const SizedBox(width: 72, height: 56);
              return SizedBox(
                width: 72,
                height: 56,
                child: TextButton(
                  onPressed: key == '⌫' ? onBackspace : () => onDigit(key),
                  child: Text(
                    key,
                    style: AppTypography.title.copyWith(fontSize: key == '⌫' ? 18 : 22),
                  ),
                ),
              );
            }).toList(),
          ),
        );
      }).toList(),
    );
  }
}
