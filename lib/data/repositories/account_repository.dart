import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/accounts.dart';

class AccountRepository {
  AccountRepository(this._client);

  final SupabaseClient _client;

  Future<List<Account>> fetchForHousehold(String householdId) async {
    final rows = await _client
        .from('accounts')
        .select()
        .eq('household_id', householdId)
        .order('created_at');
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

  Future<void> delete(String id) async {
    await _client.from('accounts').delete().eq('id', id);
  }
}
