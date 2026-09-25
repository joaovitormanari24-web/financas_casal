import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/transaction.dart';

class TransactionRepository {
  TransactionRepository(this._client);

  final SupabaseClient _client;

  /// Lançamentos do household num mês de referência (qualquer dia do mês).
  Future<List<Transaction>> fetchForMonth({
    required String householdId,
    required DateTime referenceMonth,
  }) async {
    final start = DateTime(referenceMonth.year, referenceMonth.month, 1);
    final end = DateTime(referenceMonth.year, referenceMonth.month + 1, 1);

    final rows = await _client
        .from('transactions')
        .select()
        .eq('household_id', householdId)
        .gte('date', start.toIso8601String())
        .lt('date', end.toIso8601String())
        .order('date', ascending: false)
        .order('created_at', ascending: false);

    return rows.map((row) => Transaction.fromJson(row)).toList();
  }

  Future<Transaction> create(Transaction transaction) async {
    final row = await _client
        .from('transactions')
        .insert(transaction.toInsertJson())
        .select()
        .single();
    return Transaction.fromJson(row);
  }

  Future<void> delete(String id) async {
    await _client.from('transactions').delete().eq('id', id);
  }
}
