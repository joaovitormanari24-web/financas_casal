import 'package:equatable/equatable.dart';

/// Objetivo do mês (briefing, seção 38): quanto o casal quer guardar.
class MonthlyPlan extends Equatable {
  const MonthlyPlan({
    required this.id,
    required this.householdId,
    required this.referenceMonth,
    required this.savingsTarget,
    this.incomeExpected,
  });

  final String id;
  final String householdId;
  final DateTime referenceMonth;
  final double savingsTarget;
  final double? incomeExpected;

  factory MonthlyPlan.fromJson(Map<String, dynamic> json) => MonthlyPlan(
        id: json['id'] as String,
        householdId: json['household_id'] as String,
        referenceMonth: DateTime.parse(json['reference_month'] as String),
        savingsTarget: (json['savings_target'] as num).toDouble(),
        incomeExpected: (json['income_expected'] as num?)?.toDouble(),
      );

  @override
  List<Object?> get props =>
      [id, householdId, referenceMonth, savingsTarget];
}
