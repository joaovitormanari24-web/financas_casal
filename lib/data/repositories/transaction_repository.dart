import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/transaction.dart';

class TransactionRepository {
  TransactionRepository(this._client);

  final SupabaseClient _client;
  static const _receiptsBucket = 'receipts';

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

  /// Lançamentos entre duas datas (inclusive [start], exclusive [end]) —
  /// usado pelo gráfico de evolução mensal, que precisa de vários meses de
  /// uma vez em vez de um mês por consulta.
  Future<List<Transaction>> fetchForDateRange({
    required String householdId,
    required DateTime start,
    required DateTime end,
  }) async {
    final rows = await _client
        .from('transactions')
        .select()
        .eq('household_id', householdId)
        .gte('date', start.toIso8601String())
        .lt('date', end.toIso8601String())
        .order('date');

    return rows.map((row) => Transaction.fromJson(row)).toList();
  }

  /// Busca por descrição em todo o histórico do household (sem recorte de
  /// período) — usada quando a busca da Home tem texto, já que aí faz mais
  /// sentido achar algo de qualquer mês do que só o selecionado.
  Future<List<Transaction>> searchByDescription({
    required String householdId,
    required String query,
  }) async {
    final rows = await _client
        .from('transactions')
        .select()
        .eq('household_id', householdId)
        .ilike('description', '%$query%')
        .order('date', ascending: false)
        .limit(200);
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

  /// Confirma que um lançamento pendente já foi pago — a partir daí ele
  /// passa a contar no saldo real da conta.
  Future<void> markPaid(String id) async {
    await _client.from('transactions').update({'status': 'paid'}).eq('id', id);
  }

  Future<void> markPending(String id) async {
    await _client.from('transactions').update({'status': 'pending'}).eq('id', id);
  }

  /// Envia a foto do comprovante e devolve o caminho salvo no bucket
  /// (não uma URL — o bucket é privado, então exibir exige signed URL).
  Future<String> uploadReceipt({
    required String householdId,
    required String transactionId,
    required Uint8List bytes,
    required String fileExt,
  }) async {
    final path = '$householdId/$transactionId.$fileExt';
    await _client.storage.from(_receiptsBucket).uploadBinary(
          path,
          bytes,
          fileOptions: const FileOptions(upsert: true),
        );
    return path;
  }

  Future<void> deleteReceipt(String path) async {
    await _client.storage.from(_receiptsBucket).remove([path]);
  }

  Future<String> getReceiptSignedUrl(String path) async {
    return _client.storage.from(_receiptsBucket).createSignedUrl(path, 3600);
  }

  Future<void> setReceiptPath(String transactionId, String? path) async {
    await _client.from('transactions').update({'receipt_path': path}).eq('id', transactionId);
  }

  /// Cria o plano de parcelamento e já lança todas as parcelas futuras —
  /// elas entram automaticamente na previsão dos meses seguintes, sem
  /// precisar cadastrar uma a uma. [installmentAmount] é o valor de cada
  /// parcela (não o total) — o casal já sabe quanto paga por mês.
  Future<void> createInstallmentPurchase({
    required String householdId,
    required String description,
    required double installmentAmount,
    required int installmentCount,
    required DateTime firstDueDate,
    required String categoryId,
    required String paidByMemberId,
    required String paymentMethod,
  }) async {
    final planRow = await _client
        .from('installment_plans')
        .insert({
          'household_id': householdId,
          'description': description,
          'total_amount': installmentAmount * installmentCount,
          'installment_count': installmentCount,
          'installment_amount': installmentAmount,
          'first_due_date': firstDueDate.toIso8601String(),
        })
        .select()
        .single();
    final planId = planRow['id'] as String;

    final today = DateTime.now();
    final todayDateOnly = DateTime(today.year, today.month, today.day);

    final rows = List.generate(installmentCount, (i) {
      final dueDate = _addMonthsClamped(firstDueDate, i);
      return {
        'household_id': householdId,
        'type': 'expense',
        'amount': installmentAmount,
        'description': '$description (${i + 1}/$installmentCount)',
        'category_id': categoryId,
        'date': dueDate.toIso8601String(),
        'paid_by_member_id': paidByMemberId,
        'payment_method': paymentMethod,
        'installment_plan_id': planId,
        'installment_number': i + 1,
        'installment_total': installmentCount,
        // Parcela futura nasce pendente — ainda não saiu da conta.
        'status': dueDate.isAfter(todayDateOnly) ? 'pending' : 'paid',
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
