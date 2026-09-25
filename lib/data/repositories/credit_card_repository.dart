import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/accounts.dart';

class CreditCardRepository {
  CreditCardRepository(this._client);

  final SupabaseClient _client;

  Future<List<CreditCard>> fetchForHousehold(String householdId) async {
    final rows = await _client
        .from('credit_cards')
        .select()
        .eq('household_id', householdId)
        .order('created_at');
    return rows.map((row) => CreditCard.fromJson(row)).toList();
  }

  Future<CreditCard> create(CreditCard card) async {
    final row = await _client
        .from('credit_cards')
        .insert(card.toInsertJson())
        .select()
        .single();
    return CreditCard.fromJson(row);
  }

  Future<void> delete(String id) async {
    await _client.from('credit_cards').delete().eq('id', id);
  }
}
