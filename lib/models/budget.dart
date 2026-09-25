import 'package:equatable/equatable.dart';

/// Orçamento mensal por categoria (briefing, seção 35).
class Budget extends Equatable {
  const Budget({
    required this.id,
    required this.householdId,
    required this.categoryId,
    required this.limitAmount,
    required this.referenceMonth,
  });

  final String id;
  final String householdId;
  final String categoryId;
  final double limitAmount;

  /// Primeiro dia do mês de referência (ex.: 2026-09-01).
  final DateTime referenceMonth;

  factory Budget.fromJson(Map<String, dynamic> json) => Budget(
        id: json['id'] as String,
        householdId: json['household_id'] as String,
        categoryId: json['category_id'] as String,
        limitAmount: (json['limit_amount'] as num).toDouble(),
        referenceMonth: DateTime.parse(json['reference_month'] as String),
      );

  @override
  List<Object?> get props =>
      [id, householdId, categoryId, limitAmount, referenceMonth];
}
