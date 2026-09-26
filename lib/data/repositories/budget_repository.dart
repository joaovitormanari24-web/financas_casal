import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/budget.dart';

class BudgetRepository {
  BudgetRepository(this._client);

  final SupabaseClient _client;

  Future<List<Budget>> fetchForMonth({
    required String householdId,
    required DateTime referenceMonth,
  }) async {
    final start = DateTime(referenceMonth.year, referenceMonth.month, 1);
    final rows = await _client
        .from('budgets')
        .select()
        .eq('household_id', householdId)
        .eq('reference_month', start.toIso8601String());
    return rows.map((row) => Budget.fromJson(row)).toList();
  }

  /// Cria ou atualiza o limite da categoria no mês — a constraint única
  /// (household, categoria, mês) garante que nunca haja duplicidade.
  Future<void> upsert(Budget budget) async {
    await _client
        .from('budgets')
        .upsert(budget.toInsertJson(), onConflict: 'household_id,category_id,reference_month');
  }

  Future<void> delete(String id) async {
    await _client.from('budgets').delete().eq('id', id);
  }
}
