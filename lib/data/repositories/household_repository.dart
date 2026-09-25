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

  Future<List<HouseholdMember>> fetchMembers(String householdId) async {
    final rows = await _client
        .from('household_members')
        .select()
        .eq('household_id', householdId)
        .order('created_at');
    return rows.map((row) => HouseholdMember.fromJson(row)).toList();
  }

  /// O registro de membro do usuário logado dentro deste household —
  /// usado como valor padrão de "pago por" ao lançar uma transação.
  Future<HouseholdMember?> fetchCurrentMember(String householdId) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return null;

    final row = await _client
        .from('household_members')
        .select()
        .eq('household_id', householdId)
        .eq('user_id', userId)
        .maybeSingle();

    return row == null ? null : HouseholdMember.fromJson(row);
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
