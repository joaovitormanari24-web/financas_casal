import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/finance_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../models/goal.dart';
import '../../../shared/utils/category_icons.dart';
import '../../../shared/utils/currency_formatter.dart';
import 'add_goal_screen.dart';
import 'goal_detail_screen.dart';

class GoalsScreen extends ConsumerWidget {
  const GoalsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goalsAsync = ref.watch(goalsProvider);
    final palette = AppColors.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Metas')),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(goalsProvider);
            await ref.read(goalsProvider.future);
          },
          child: goalsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator(strokeWidth: 2)),
            error: (_, __) => ListView(
              children: [
                const SizedBox(height: AppSpacing.xxl),
                Center(
                  child: Text(
                    'Não foi possível carregar as metas.',
                    style: AppTypography.body,
                  ),
                ),
              ],
            ),
            data: (goals) {
              if (goals.isEmpty) {
                return ListView(
                  children: [
                    const SizedBox(height: AppSpacing.xxl),
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.screenPadding,
                        ),
                        child: Text(
                          'Nenhuma meta ainda. Crie um cofrinho pra algo que '
                          'vocês querem juntar dinheiro.',
                          style: AppTypography.body,
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ],
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.all(AppSpacing.screenPadding),
                itemCount: goals.length,
                separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
                itemBuilder: (context, index) => _GoalCard(goal: goals[index]),
              );
            },
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const AddGoalScreen()),
        ),
        backgroundColor: palette.textPrimary,
        foregroundColor: palette.background,
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _GoalCard extends StatelessWidget {
  const _GoalCard({required this.goal});

  final Goal goal;

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.of(context);

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => GoalDetailScreen(goal: goal)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: palette.accentMuted,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(categoryIconData(goal.icon), size: 18, color: palette.accent),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(goal.name, style: AppTypography.subtitle),
                  ),
                  Text(
                    '${(goal.progress * 100).round()}%',
                    style: AppTypography.captionEmphasis.copyWith(color: palette.accent),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.pill),
                child: LinearProgressIndicator(
                  value: goal.progress,
                  minHeight: 8,
                  backgroundColor: palette.backgroundSecondary,
                  valueColor: AlwaysStoppedAnimation(palette.accent),
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                '${CurrencyFormatter.format(goal.currentAmount)} de '
                '${CurrencyFormatter.format(goal.targetAmount)}',
                style: AppTypography.caption.copyWith(color: palette.textSecondary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
