import 'package:equatable/equatable.dart';

/// Representa o casal. Todos os dados financeiros pertencem a um
/// household — nunca a um usuário isolado (briefing, seção 9).
class Household extends Equatable {
  const Household({
    required this.id,
    required this.name,
    required this.createdAt,
  });

  final String id;
  final String name;
  final DateTime createdAt;

  factory Household.fromJson(Map<String, dynamic> json) => Household(
        id: json['id'] as String,
        name: json['name'] as String,
        createdAt: DateTime.parse(json['created_at'] as String),
      );

  Map<String, dynamic> toInsertJson() => {'name': name};

  @override
  List<Object?> get props => [id, name, createdAt];
}

/// Vínculo entre um usuário autenticado e um household.
class HouseholdMember extends Equatable {
  const HouseholdMember({
    required this.id,
    required this.householdId,
    required this.userId,
    required this.displayName,
  });

  final String id;
  final String householdId;
  final String userId;
  final String displayName;

  factory HouseholdMember.fromJson(Map<String, dynamic> json) =>
      HouseholdMember(
        id: json['id'] as String,
        householdId: json['household_id'] as String,
        userId: json['user_id'] as String,
        displayName: json['display_name'] as String,
      );

  @override
  List<Object?> get props => [id, householdId, userId, displayName];
}
