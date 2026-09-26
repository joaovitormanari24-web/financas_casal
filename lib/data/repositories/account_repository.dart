import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/accounts.dart';
import '../../models/transaction.dart';

class AccountRepository {
  AccountRepository(this._client);

  final SupabaseClient _client;

  Future<List<Account>> fetchForHousehold(String householdId) async {
    final rows = await _client
        .from('account_balances')
        .select()
        .eq('household_id', householdId)
        .order('name');
    return rows.map((row) => Account.fromJson(row)).toList();
  }

  Future<Account> create(Account account) async {
    final row = await _client
        .from('accounts')
        .insert(account.toInsertJson())
        .select()
        .single();
    return Account.fromJson(row);
  }

  Future<Account> update({
    required String id,
    required String name,
    required double initialBalance,
  }) async {
    final row = await _client
        .from('accounts')
        .update({'name': name, 'initial_balance': initialBalance})
        .eq('id', id)
        .select()
        .single();
    return Account.fromJson(row);
  }

  Future<List<Transaction>> fetchTransactions(String accountId) async {
    final rows = await _client
        .from('transactions')
        .select()
        .eq('account_id', accountId)
        .order('date', ascending: false);
    return rows.map((row) => Transaction.fromJson(row)).toList();
  }

  Future<void> delete(String id) async {
    await _client.from('accounts').delete().eq('id', id);
  }
}
