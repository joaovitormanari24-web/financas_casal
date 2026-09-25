import 'package:equatable/equatable.dart';

/// Conta financeira (briefing, seção 31). Arquitetura preparada para
/// futura integração com Open Finance via o campo [externalSource].
class Account extends Equatable {
  const Account({
    required this.id,
    required this.householdId,
    required this.name,
    required this.ownerMemberId,
    this.externalSource,
  });

  final String id;
  final String householdId;
  final String name;

  /// Membro dono da conta, ou null para conta conjunta.
  final String? ownerMemberId;
  final String? externalSource;

  factory Account.fromJson(Map<String, dynamic> json) => Account(
        id: json['id'] as String,
        householdId: json['household_id'] as String,
        name: json['name'] as String,
        ownerMemberId: json['owner_member_id'] as String?,
        externalSource: json['external_source'] as String?,
      );

  @override
  List<Object?> get props => [id, householdId, name, ownerMemberId];
}

/// Cartão de crédito (briefing, seção 32).
class CreditCard extends Equatable {
  const CreditCard({
    required this.id,
    required this.householdId,
    required this.name,
    required this.institution,
    required this.limit,
    required this.closingDay,
    required this.dueDay,
  });

  final String id;
  final String householdId;
  final String name;
  final String institution;
  final double limit;

  /// Dia do fechamento da fatura (1-31).
  final int closingDay;

  /// Dia do vencimento da fatura (1-31).
  final int dueDay;

  factory CreditCard.fromJson(Map<String, dynamic> json) => CreditCard(
        id: json['id'] as String,
        householdId: json['household_id'] as String,
        name: json['name'] as String,
        institution: json['institution'] as String,
        limit: (json['credit_limit'] as num).toDouble(),
        closingDay: json['closing_day'] as int,
        dueDay: json['due_day'] as int,
      );

  Map<String, dynamic> toInsertJson() => {
        'household_id': householdId,
        'name': name,
        'institution': institution,
        'credit_limit': limit,
        'closing_day': closingDay,
        'due_day': dueDay,
      };

  @override
  List<Object?> get props => [id, householdId, name, institution, limit];
}
