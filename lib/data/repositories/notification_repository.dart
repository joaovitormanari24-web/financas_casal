import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/app_notification.dart';

class NotificationRepository {
  NotificationRepository(this._client);

  final SupabaseClient _client;

  Future<List<AppNotification>> fetchForHousehold(String householdId) async {
    final rows = await _client
        .from('notifications')
        .select()
        .eq('household_id', householdId)
        .order('created_at', ascending: false)
        .limit(50);
    return rows.map((row) => AppNotification.fromJson(row)).toList();
  }

  Future<void> markRead(String id) async {
    await _client
        .from('notifications')
        .update({'read_at': DateTime.now().toIso8601String()})
        .eq('id', id);
  }

  Future<void> markAllRead(String householdId) async {
    await _client
        .from('notifications')
        .update({'read_at': DateTime.now().toIso8601String()})
        .eq('household_id', householdId)
        .filter('read_at', 'is', null);
  }
}
