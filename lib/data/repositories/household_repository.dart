import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/household.dart';

/// Onboarding e leitura do household do usuário atual. Criação/entrada
/// passam por funções `security definer` no banco — ver
/// `supabase/migrations/0002_household_onboarding.sql`.
class HouseholdRepository {
  HouseholdRepository(this._client);

  final SupabaseClient _client;

  /// Retorna o household do usuário logado, ou `null` se ele ainda não
  /// pertence a nenhum (fluxo de onboarding).
  Future<Household?> fetchCurrentHousehold() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return null;

    final membership = await _client
        .from('household_members')
        .select('household_id')
        .eq('user_id', userId)
        .limit(1)
        .maybeSingle();

    if (membership == null) return null;

    final householdJson = await _client
        .from('households')
        .select()
        .eq('id', membership['household_id'] as String)
        .single();

    return Household.fromJson(householdJson);
  }

  Future<String> createHousehold({
    required String householdName,
    required String displayName,
  }) async {
    final householdId = await _client.rpc(
      'create_household',
      params: {'household_name': householdName, 'display_name': displayName},
    );
    return householdId as String;
  }

  Future<String> createInvite({required String householdId}) async {
    final code = await _client.rpc(
      'create_household_invite',
      params: {'target_household_id': householdId},
    );
    return code as String;
  }

  Future<String> redeemInvite({
    required String code,
    required String displayName,
  }) async {
    final householdId = await _client.rpc(
      'redeem_household_invite',
      params: {'invite_code': code, 'display_name': displayName},
    );
    return householdId as String;
  }
}
