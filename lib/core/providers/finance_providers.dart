import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/category_repository.dart';
import '../../data/repositories/goal_repository.dart';
import '../../data/repositories/transaction_repository.dart';
import '../../models/category.dart';
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

/// Mês de referência exibido na Home — controla o dashboard e a lista de
/// lançamentos. Sempre o primeiro dia do mês.
final selectedMonthProvider = StateProvider<DateTime>((ref) {
  final now = DateTime.now();
  return DateTime(now.year, now.month, 1);
});

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
  final month = ref.watch(selectedMonthProvider);
  return ref.watch(transactionRepositoryProvider).fetchForMonth(
        householdId: household.id,
        referenceMonth: month,
      );
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
