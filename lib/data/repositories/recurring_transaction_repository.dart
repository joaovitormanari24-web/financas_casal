import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/transaction.dart';

class RecurringTransactionRepository {
  RecurringTransactionRepository(this._client);

  final SupabaseClient _client;

  Future<List<RecurringTransaction>> fetchForHousehold(String householdId) async {
    final rows = await _client
        .from('recurring_transactions')
        .select()
        .eq('household_id', householdId)
        .order('created_at');
    return rows.map((row) => RecurringTransaction.fromJson(row)).toList();
  }

  Future<void> create(RecurringTransaction recurring) async {
    await _client.from('recurring_transactions').insert(recurring.toInsertJson());
  }

  Future<void> setActive(String id, bool active) async {
    await _client.from('recurring_transactions').update({'active': active}).eq('id', id);
  }

  Future<void> delete(String id) async {
    await _client.from('recurring_transactions').delete().eq('id', id);
  }
}
