import 'package:equatable/equatable.dart';

/// Meta / cofrinho visual (briefing, seções 20 e 37).
class Goal extends Equatable {
  const Goal({
    required this.id,
    required this.householdId,
    required this.name,
    required this.targetAmount,
    required this.currentAmount,
    this.targetDate,
    this.monthlyContribution,
    this.icon = 'target',
  });

  final String id;
  final String householdId;
  final String name;
  final double targetAmount;
  final double currentAmount;
  final DateTime? targetDate;
  final double? monthlyContribution;
  final String icon;

  double get progress =>
      targetAmount <= 0 ? 0 : (currentAmount / targetAmount).clamp(0, 1);

  factory Goal.fromJson(Map<String, dynamic> json) => Goal(
        id: json['id'] as String,
        householdId: json['household_id'] as String,
        name: json['name'] as String,
        targetAmount: (json['target_amount'] as num).toDouble(),
        currentAmount: (json['current_amount'] as num).toDouble(),
        targetDate: json['target_date'] == null
            ? null
            : DateTime.parse(json['target_date'] as String),
        monthlyContribution: (json['monthly_contribution'] as num?)
            ?.toDouble(),
        icon: json['icon'] as String? ?? 'target',
      );

  @override
  List<Object?> get props =>
      [id, householdId, name, targetAmount, currentAmount, targetDate];
}

/// Aporte a uma meta (briefing, seção 20 — "ao adicionar dinheiro").
class GoalContribution extends Equatable {
  const GoalContribution({
    required this.id,
    required this.goalId,
    required this.amount,
    required this.date,
    required this.memberId,
  });

  final String id;
  final String goalId;
  final double amount;
  final DateTime date;
  final String memberId;

  factory GoalContribution.fromJson(Map<String, dynamic> json) =>
      GoalContribution(
        id: json['id'] as String,
        goalId: json['goal_id'] as String,
        amount: (json['amount'] as num).toDouble(),
        date: DateTime.parse(json['date'] as String),
        memberId: json['member_id'] as String,
      );

  @override
  List<Object?> get props => [id, goalId, amount, date];
}
