import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/profile.dart';

class ProfileRepository {
  ProfileRepository(this._client);

  final SupabaseClient _client;

  Future<Profile?> fetchCurrent() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return null;

    final row = await _client.from('profiles').select().eq('id', userId).maybeSingle();
    return row == null ? null : Profile.fromJson(row);
  }

  Future<void> updateFullName(String fullName) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;
    await _client.from('profiles').update({'full_name': fullName}).eq('id', userId);
  }
}
