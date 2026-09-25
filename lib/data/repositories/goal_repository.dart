import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/goal.dart';

class GoalRepository {
  GoalRepository(this._client);

  final SupabaseClient _client;

  Future<List<Goal>> fetchForHousehold(String householdId) async {
    final rows = await _client
        .from('goals')
        .select()
        .eq('household_id', householdId)
        .order('created_at');
    return rows.map((row) => Goal.fromJson(row)).toList();
  }

  Future<Goal> create({
    required String householdId,
    required String name,
    required double targetAmount,
    DateTime? targetDate,
    double? monthlyContribution,
    String icon = 'target',
  }) async {
    final row = await _client
        .from('goals')
        .insert({
          'household_id': householdId,
          'name': name,
          'target_amount': targetAmount,
          'target_date': targetDate?.toIso8601String(),
          'monthly_contribution': monthlyContribution,
          'icon': icon,
        })
        .select()
        .single();
    return Goal.fromJson(row);
  }

  Future<void> delete(String id) async {
    await _client.from('goals').delete().eq('id', id);
  }

  /// Insere um aporte — o trigger `on_goal_contribution_change` no banco já
  /// atualiza `goals.current_amount` automaticamente.
  Future<void> contribute({
    required String goalId,
    required String memberId,
    required double amount,
  }) async {
    await _client.from('goal_contributions').insert({
      'goal_id': goalId,
      'member_id': memberId,
      'amount': amount,
    });
  }
}
