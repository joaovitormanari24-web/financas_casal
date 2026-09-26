import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/bank_connection.dart';

class BankConnectionRepository {
  BankConnectionRepository(this._client);

  final SupabaseClient _client;

  Future<List<BankConnection>> fetchForHousehold(String householdId) async {
    final rows = await _client
        .from('bank_connections')
        .select()
        .eq('household_id', householdId)
        .order('created_at');
    return rows.map((row) => BankConnection.fromJson(row)).toList();
  }

  Future<String> createConnectToken() async {
    final response = await _client.functions.invoke('pluggy-connect-token');
    final data = response.data as Map<String, dynamic>;
    return data['connectToken'] as String;
  }

  /// Registra (ou re-sincroniza) um Item — chamado logo após o widget
  /// Pluggy Connect concluir a conexão, e de novo em "Sincronizar agora".
  Future<void> syncItem({required String itemId, String? institutionName}) async {
    await _client.functions.invoke(
      'pluggy-sync-item',
      body: {
        'itemId': itemId,
        if (institutionName != null) 'institutionName': institutionName,
      },
    );
  }
}
