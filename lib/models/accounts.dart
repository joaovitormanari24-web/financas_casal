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
    this.initialBalance = 0,
    this.currentBalance,
  });

  final String id;
  final String householdId;
  final String name;

  /// Membro dono da conta, ou null para conta conjunta.
  final String? ownerMemberId;
  final String? externalSource;

  /// Saldo declarado no momento em que a conta foi cadastrada no app.
  final double initialBalance;

  /// [initialBalance] + receitas - despesas lançadas nela — só vem
  /// preenchido quando a conta é buscada via a view `account_balances`
  /// (ver [AccountRepository.fetchForHousehold]).
  final double? currentBalance;

  factory Account.fromJson(Map<String, dynamic> json) => Account(
        id: json['id'] as String,
        householdId: json['household_id'] as String,
        name: json['name'] as String,
        ownerMemberId: json['owner_member_id'] as String?,
        externalSource: json['external_source'] as String?,
        initialBalance: (json['initial_balance'] as num?)?.toDouble() ?? 0,
        currentBalance: (json['current_balance'] as num?)?.toDouble(),
      );

  Map<String, dynamic> toInsertJson() => {
        'household_id': householdId,
        'name': name,
        'owner_member_id': ownerMemberId,
        'external_source': externalSource,
        'initial_balance': initialBalance,
      };

  @override
  List<Object?> get props => [id, householdId, name, ownerMemberId, initialBalance, currentBalance];
}
