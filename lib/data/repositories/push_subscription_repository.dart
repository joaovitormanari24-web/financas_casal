import 'package:supabase_flutter/supabase_flutter.dart';

class PushSubscriptionRepository {
  PushSubscriptionRepository(this._client);

  final SupabaseClient _client;

  Future<void> save({
    required String householdId,
    required String memberId,
    required String endpoint,
    required String p256dh,
    required String auth,
  }) async {
    await _client.from('push_subscriptions').upsert({
      'household_id': householdId,
      'member_id': memberId,
      'endpoint': endpoint,
      'p256dh': p256dh,
      'auth': auth,
    }, onConflict: 'endpoint');
  }

  Future<void> deleteByEndpoint(String endpoint) async {
    await _client.from('push_subscriptions').delete().eq('endpoint', endpoint);
  }

  Future<bool> existsForEndpoint(String endpoint) async {
    final rows = await _client
        .from('push_subscriptions')
        .select('id')
        .eq('endpoint', endpoint)
        .limit(1);
    return rows.isNotEmpty;
  }
}
