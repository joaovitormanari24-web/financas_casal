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

  Future<RecurringTransaction> create(RecurringTransaction recurring) async {
    final row = await _client
        .from('recurring_transactions')
        .insert(recurring.toInsertJson())
        .select()
        .single();
    return RecurringTransaction.fromJson(row);
  }

  /// Registra que, a partir de [effectiveDate], o valor passa a ser
  /// [newAmount] — usado pelo gerador em vez do valor original.
  Future<void> addAmountChange({
    required String recurringTransactionId,
    required DateTime effectiveDate,
    required double newAmount,
  }) async {
    await _client.from('recurring_transaction_amount_changes').insert({
      'recurring_transaction_id': recurringTransactionId,
      'effective_date': effectiveDate.toIso8601String(),
      'new_amount': newAmount,
    });
  }

  Future<void> setActive(String id, bool active) async {
    await _client.from('recurring_transactions').update({'active': active}).eq('id', id);
  }

  Future<void> delete(String id) async {
    await _client.from('recurring_transactions').delete().eq('id', id);
  }
}
