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

  Future<Transaction> update(String id, Transaction transaction) async {
    final row = await _client
        .from('transactions')
        .update(transaction.toInsertJson())
        .eq('id', id)
        .select()
        .single();
    return Transaction.fromJson(row);
  }

  Future<void> delete(String id) async {
    await _client.from('transactions').delete().eq('id', id);
  }

  /// Cria o plano de parcelamento e já lança todas as parcelas futuras —
  /// elas entram automaticamente na previsão dos meses seguintes, sem
  /// precisar cadastrar uma a uma.
  Future<void> createInstallmentPurchase({
    required String householdId,
    required String description,
    required double totalAmount,
    required int installmentCount,
    required DateTime firstDueDate,
    required String creditCardId,
    required String categoryId,
    required String paidByMemberId,
  }) async {
    final baseAmount = double.parse((totalAmount / installmentCount).toStringAsFixed(2));
    final lastAmount = double.parse(
      (totalAmount - baseAmount * (installmentCount - 1)).toStringAsFixed(2),
    );

    final planRow = await _client
        .from('installment_plans')
        .insert({
          'household_id': householdId,
          'description': description,
          'total_amount': totalAmount,
          'installment_count': installmentCount,
          'installment_amount': baseAmount,
          'first_due_date': firstDueDate.toIso8601String(),
          'credit_card_id': creditCardId,
        })
        .select()
        .single();
    final planId = planRow['id'] as String;

    final rows = List.generate(installmentCount, (i) {
      final isLast = i == installmentCount - 1;
      return {
        'household_id': householdId,
        'type': 'expense',
        'amount': isLast ? lastAmount : baseAmount,
        'description': '$description (${i + 1}/$installmentCount)',
        'category_id': categoryId,
        'date': _addMonthsClamped(firstDueDate, i).toIso8601String(),
        'paid_by_member_id': paidByMemberId,
        'payment_method': 'credit',
        'credit_card_id': creditCardId,
        'installment_plan_id': planId,
        'installment_number': i + 1,
        'installment_total': installmentCount,
      };
    });

    await _client.from('transactions').insert(rows);
  }
}

/// Soma [months] a [date], ajustando o dia se o mês de destino for mais
/// curto (ex.: 31/01 + 1 mês -> 28/02, não 03/03).
DateTime _addMonthsClamped(DateTime date, int months) {
  final totalMonths = date.month - 1 + months;
  final year = date.year + totalMonths ~/ 12;
  final month = totalMonths % 12 + 1;
  final lastDayOfMonth = DateTime(year, month + 1, 0).day;
  final day = date.day > lastDayOfMonth ? lastDayOfMonth : date.day;
  return DateTime(year, month, day);
}
