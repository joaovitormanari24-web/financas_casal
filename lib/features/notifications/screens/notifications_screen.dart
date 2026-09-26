import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/providers/app_providers.dart';
import '../../../core/providers/finance_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/utils/haptics.dart';

IconData _iconForKind(String kind) => switch (kind) {
      'budget' => Icons.warning_amber_rounded,
      'budget_warning' => Icons.hourglass_bottom_rounded,
      'recurring' => Icons.autorenew_rounded,
      'goal' => Icons.track_changes_rounded,
      'reminder' => Icons.notifications_active_outlined,
      _ => Icons.info_outline_rounded,
    };

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notificationsAsync = ref.watch(notificationsProvider);
    final palette = AppColors.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notificações'),
        actions: [
          IconButton(
            icon: const Icon(Icons.done_all_rounded),
            tooltip: 'Marcar todas como lidas',
            onPressed: () async {
              final household = ref.read(currentHouseholdProvider).valueOrNull;
              if (household == null) return;
              try {
                await ref.read(notificationRepositoryProvider).markAllRead(household.id);
                ref.invalidate(notificationsProvider);
                Haptics.tapLight();
              } catch (_) {
                Haptics.warning();
              }
            },
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(notificationsProvider);
            await ref.read(notificationsProvider.future);
          },
          child: notificationsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator(strokeWidth: 2)),
            error: (_, __) => ListView(
              children: [
                const SizedBox(height: AppSpacing.xxl),
                Center(
                  child: Text('Não foi possível carregar.', style: AppTypography.body),
                ),
              ],
            ),
            data: (notifications) {
              if (notifications.isEmpty) {
                return ListView(
                  children: [
                    const SizedBox(height: AppSpacing.xxl),
                    Center(
                      child: Text(
                        'Nenhuma notificação ainda.',
                        style: AppTypography.body,
                      ),
                    ),
                  ],
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.all(AppSpacing.screenPadding),
                itemCount: notifications.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final notification = notifications[index];
                  return ListTile(
                    onTap: notification.isRead
                        ? null
                        : () async {
                            try {
                              await ref
                                  .read(notificationRepositoryProvider)
                                  .markRead(notification.id);
                              ref.invalidate(notificationsProvider);
                            } catch (_) {
                              Haptics.warning();
                            }
                          },
                    leading: Icon(
                      _iconForKind(notification.kind),
                      color: notification.isRead ? palette.textTertiary : palette.accent,
                    ),
                    title: Text(
                      notification.title,
                      style: notification.isRead
                          ? AppTypography.body
                          : AppTypography.bodyEmphasis,
                    ),
                    subtitle: Text(notification.body, style: AppTypography.caption),
                    trailing: Text(
                      DateFormat('dd/MM HH:mm', 'pt_BR').format(notification.createdAt),
                      style: AppTypography.caption.copyWith(color: palette.textTertiary),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}
