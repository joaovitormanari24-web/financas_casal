import 'package:flutter/material.dart' show DateTimeRange;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/repositories/account_repository.dart';
import '../../data/repositories/budget_repository.dart';
import '../../data/repositories/category_repository.dart';
import '../../data/repositories/financial_simulation_repository.dart';
import '../../data/repositories/goal_repository.dart';
import '../../data/repositories/notification_repository.dart';
import '../../data/repositories/push_subscription_repository.dart';
import '../../data/repositories/recurring_transaction_repository.dart';
import '../../data/repositories/transaction_repository.dart';
import '../../models/accounts.dart';
import '../../models/app_notification.dart';
import '../../models/budget.dart';
import '../../models/category.dart';
import '../../models/enums.dart';
import '../../models/goal.dart';
import '../../models/household.dart';
import '../../models/transaction.dart';
import 'app_providers.dart';

final categoryRepositoryProvider = Provider<CategoryRepository>((ref) {
  return CategoryRepository(ref.watch(supabaseClientProvider));
});

final transactionRepositoryProvider = Provider<TransactionRepository>((ref) {
  return TransactionRepository(ref.watch(supabaseClientProvider));
});

final goalRepositoryProvider = Provider<GoalRepository>((ref) {
  return GoalRepository(ref.watch(supabaseClientProvider));
});

final goalsProvider = FutureProvider<List<Goal>>((ref) async {
  final household = await ref.watch(currentHouseholdProvider.future);
  if (household == null) return const [];
  return ref.watch(goalRepositoryProvider).fetchForHousehold(household.id);
});

final recurringTransactionRepositoryProvider = Provider<RecurringTransactionRepository>((ref) {
  return RecurringTransactionRepository(ref.watch(supabaseClientProvider));
});

final recurringTransactionsProvider = FutureProvider<List<RecurringTransaction>>((ref) async {
  final household = await ref.watch(currentHouseholdProvider.future);
  if (household == null) return const [];
  return ref.watch(recurringTransactionRepositoryProvider).fetchForHousehold(household.id);
});

/// Mês de referência exibido na Home — controla o dashboard e a lista de
/// lançamentos. Sempre o primeiro dia do mês.
final selectedMonthProvider = StateProvider<DateTime>((ref) {
  final now = DateTime.now();
  return DateTime(now.year, now.month, 1);
});

/// Intervalo de datas customizado — quando não nulo, tem prioridade sobre
/// [selectedMonthProvider] na Home (dashboard e lista de lançamentos).
final customDateRangeProvider = StateProvider<DateTimeRange?>((ref) => null);

final categoriesProvider = FutureProvider<List<Category>>((ref) async {
  final household = await ref.watch(currentHouseholdProvider.future);
  if (household == null) return const [];
  return ref.watch(categoryRepositoryProvider).fetchForHousehold(household.id);
});

final householdMembersProvider = FutureProvider<List<HouseholdMember>>((ref) async {
  final household = await ref.watch(currentHouseholdProvider.future);
  if (household == null) return const [];
  return ref.watch(householdRepositoryProvider).fetchMembers(household.id);
});

/// Registro de membro do usuário logado — usado como padrão de "pago por".
final currentMemberProvider = FutureProvider<HouseholdMember?>((ref) async {
  final household = await ref.watch(currentHouseholdProvider.future);
  if (household == null) return null;
  return ref.watch(householdRepositoryProvider).fetchCurrentMember(household.id);
});

final transactionsProvider = FutureProvider<List<Transaction>>((ref) async {
  final household = await ref.watch(currentHouseholdProvider.future);
  if (household == null) return const [];
  final repo = ref.watch(transactionRepositoryProvider);

  final customRange = ref.watch(customDateRangeProvider);
  if (customRange != null) {
    return repo.fetchForDateRange(
      householdId: household.id,
      start: customRange.start,
      end: customRange.end.add(const Duration(days: 1)),
    );
  }

  final month = ref.watch(selectedMonthProvider);
  return repo.fetchForMonth(householdId: household.id, referenceMonth: month);
});

/// Texto de busca por descrição na lista de lançamentos da Home.
final transactionSearchQueryProvider = StateProvider<String>((ref) => '');

/// Filtro opcional por categoria na lista de lançamentos.
final transactionCategoryFilterProvider = StateProvider<String?>((ref) => null);

/// Filtro opcional por forma de pagamento na lista de lançamentos.
final transactionPaymentMethodFilterProvider = StateProvider<PaymentMethod?>((ref) => null);

/// [transactionsProvider] já filtrado pela busca/categoria/forma de
/// pagamento selecionados — o que a Home efetivamente lista.
final filteredTransactionsProvider = Provider<List<Transaction>>((ref) {
  final transactions = ref.watch(transactionsProvider).valueOrNull ?? const [];
  final query = ref.watch(transactionSearchQueryProvider).trim().toLowerCase();
  final categoryId = ref.watch(transactionCategoryFilterProvider);
  final paymentMethod = ref.watch(transactionPaymentMethodFilterProvider);

  return transactions.where((t) {
    if (query.isNotEmpty && !t.description.toLowerCase().contains(query)) return false;
    if (categoryId != null && t.categoryId != categoryId) return false;
    if (paymentMethod != null && t.paymentMethod != paymentMethod) return false;
    return true;
  }).toList();
});

/// Resumo do mês selecionado: receitas, despesas e saldo.
class MonthSummary {
  const MonthSummary({required this.income, required this.expense});

  final double income;
  final double expense;

  double get balance => income - expense;
}

final monthSummaryProvider = Provider<MonthSummary>((ref) {
  final transactions = ref.watch(transactionsProvider).valueOrNull ?? const [];
  double income = 0;
  double expense = 0;
  for (final t in transactions) {
    if (t.type.name == 'income') {
      income += t.amount;
    } else if (t.type.name == 'expense') {
      expense += t.amount;
    }
  }
  return MonthSummary(income: income, expense: expense);
});

final budgetRepositoryProvider = Provider<BudgetRepository>((ref) {
  return BudgetRepository(ref.watch(supabaseClientProvider));
});

final budgetsProvider = FutureProvider<List<Budget>>((ref) async {
  final household = await ref.watch(currentHouseholdProvider.future);
  if (household == null) return const [];
  final month = ref.watch(selectedMonthProvider);
  return ref.watch(budgetRepositoryProvider).fetchForMonth(
        householdId: household.id,
        referenceMonth: month,
      );
});

/// Cruza o limite definido para a categoria no mês com o total já gasto
/// (via [transactionsProvider]), pra alimentar a barra de progresso.
class CategoryBudgetProgress {
  const CategoryBudgetProgress({required this.budget, required this.spent});

  final Budget budget;
  final double spent;

  double get progress =>
      budget.limitAmount <= 0 ? 0 : (spent / budget.limitAmount).clamp(0, 2);
  bool get isOverBudget => spent > budget.limitAmount;
}

final categoryBudgetProgressProvider = Provider<List<CategoryBudgetProgress>>((ref) {
  final budgets = ref.watch(budgetsProvider).valueOrNull ?? const [];
  final transactions = ref.watch(transactionsProvider).valueOrNull ?? const [];

  final spentByCategory = <String, double>{};
  for (final t in transactions) {
    if (t.type != TransactionType.expense) continue;
    spentByCategory.update(t.categoryId, (v) => v + t.amount, ifAbsent: () => t.amount);
  }

  return budgets
      .map((b) => CategoryBudgetProgress(budget: b, spent: spentByCategory[b.categoryId] ?? 0))
      .toList();
});

final financialSimulationRepositoryProvider = Provider<FinancialSimulationRepository>((ref) {
  return FinancialSimulationRepository(ref.watch(supabaseClientProvider));
});

final accountRepositoryProvider = Provider<AccountRepository>((ref) {
  return AccountRepository(ref.watch(supabaseClientProvider));
});

final accountsProvider = FutureProvider<List<Account>>((ref) async {
  final household = await ref.watch(currentHouseholdProvider.future);
  if (household == null) return const [];
  return ref.watch(accountRepositoryProvider).fetchForHousehold(household.id);
});

final notificationRepositoryProvider = Provider<NotificationRepository>((ref) {
  return NotificationRepository(ref.watch(supabaseClientProvider));
});

final notificationsProvider = FutureProvider<List<AppNotification>>((ref) async {
  final household = await ref.watch(currentHouseholdProvider.future);
  if (household == null) return const [];
  return ref.watch(notificationRepositoryProvider).fetchForHousehold(household.id);
});

final pushSubscriptionRepositoryProvider = Provider<PushSubscriptionRepository>((ref) {
  return PushSubscriptionRepository(ref.watch(supabaseClientProvider));
});

final unreadNotificationsCountProvider = Provider<int>((ref) {
  final notifications = ref.watch(notificationsProvider).valueOrNull ?? const [];
  return notifications.where((n) => !n.isRead).length;
});

/// Totais de um mês pro gráfico de evolução — independente do mês
/// selecionado na Home, sempre os últimos 6 meses a partir de hoje.
class MonthlyTotals {
  const MonthlyTotals({required this.month, required this.income, required this.expense});

  final DateTime month;
  final double income;
  final double expense;
}

final monthlyTrendProvider = FutureProvider<List<MonthlyTotals>>((ref) async {
  final household = await ref.watch(currentHouseholdProvider.future);
  if (household == null) return const [];

  final now = DateTime.now();
  final start = DateTime(now.year, now.month - 5, 1);
  final end = DateTime(now.year, now.month + 1, 1);

  final transactions = await ref.watch(transactionRepositoryProvider).fetchForDateRange(
        householdId: household.id,
        start: start,
        end: end,
      );

  final incomeByMonth = <DateTime, double>{};
  final expenseByMonth = <DateTime, double>{};
  final months = List.generate(6, (i) => DateTime(start.year, start.month + i, 1));
  for (final month in months) {
    incomeByMonth[month] = 0;
    expenseByMonth[month] = 0;
  }

  for (final t in transactions) {
    final month = DateTime(t.date.year, t.date.month, 1);
    if (t.type == TransactionType.income) {
      incomeByMonth[month] = (incomeByMonth[month] ?? 0) + t.amount;
    } else if (t.type == TransactionType.expense) {
      expenseByMonth[month] = (expenseByMonth[month] ?? 0) + t.amount;
    }
  }

  return months
      .map((month) => MonthlyTotals(
            month: month,
            income: incomeByMonth[month] ?? 0,
            expense: expenseByMonth[month] ?? 0,
          ))
      .toList();
});

/// Assina mudanças em tempo real de `transactions` e `goals` do household
/// atual e invalida os providers correspondentes — assim, um lançamento ou
/// aporte feito pelo parceiro(a) aparece sem precisar reabrir o app.
/// Ativado assistindo esse provider a partir de um widget de longa duração
/// (ex.: [RootShell]).
final realtimeSyncProvider = Provider<void>((ref) {
  final household = ref.watch(currentHouseholdProvider).valueOrNull;
  if (household == null) return;

  final client = ref.watch(supabaseClientProvider);
  final channel = client
      .channel('household-${household.id}')
      .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'transactions',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'household_id',
          value: household.id,
        ),
        callback: (_) => ref.invalidate(transactionsProvider),
      )
      .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'goals',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'household_id',
          value: household.id,
        ),
        callback: (_) => ref.invalidate(goalsProvider),
      )
      .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'notifications',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'household_id',
          value: household.id,
        ),
        callback: (_) => ref.invalidate(notificationsProvider),
      )
      .subscribe();

  ref.onDispose(() => client.removeChannel(channel));
});
