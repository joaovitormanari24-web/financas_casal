import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/enums.dart';
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

  /// Cria a recorrência, o reajuste de valor opcional e o lançamento do
  /// ciclo atual (se já devido) numa única chamada atômica — evita a
  /// recorrência ficar "órfã" sem lançamento por causa de uma janela de
  /// leitura entre chamadas separadas.
  Future<String> createWithInitialOccurrence(
    RecurringTransaction recurring, {
    DateTime? amountChangeDate,
    double? amountChangeNewAmount,
  }) async {
    final newId = await _client.rpc('create_recurring_transaction', params: {
      'p_household_id': recurring.householdId,
      'p_description': recurring.description,
      'p_amount': recurring.amount,
      'p_category_id': recurring.categoryId,
      'p_frequency': recurring.frequency.dbValue,
      'p_day_of_cycle': recurring.dayOfCycle,
      'p_payment_method': recurring.paymentMethod.dbValue,
      'p_paid_by_member_id': recurring.paidByMemberId,
      'p_end_date': recurring.endDate?.toIso8601String(),
      'p_reminder_days_before': recurring.reminderDaysBefore,
      'p_amount_change_date': amountChangeDate?.toIso8601String(),
      'p_amount_change_new_amount': amountChangeNewAmount,
    });
    return newId as String;
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
