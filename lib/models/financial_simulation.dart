import 'package:equatable/equatable.dart';

enum SimulationKind { purchase, installment, whatIf }

extension SimulationKindX on SimulationKind {
  String get dbValue => switch (this) {
        SimulationKind.purchase => 'purchase',
        SimulationKind.installment => 'installment',
        SimulationKind.whatIf => 'what_if',
      };
}

/// Registro de uma simulação "Podemos gastar?" — histórico salvo pra dar
/// contexto futuro, mesmo sem tela própria de consulta ainda.
class FinancialSimulation extends Equatable {
  const FinancialSimulation({
    required this.id,
    required this.householdId,
    required this.createdByMemberId,
    required this.kind,
    required this.input,
    required this.result,
  });

  final String id;
  final String householdId;
  final String createdByMemberId;
  final SimulationKind kind;
  final Map<String, dynamic> input;
  final Map<String, dynamic> result;

  Map<String, dynamic> toInsertJson() => {
        'household_id': householdId,
        'created_by_member_id': createdByMemberId,
        'kind': kind.dbValue,
        'input': input,
        'result': result,
      };

  @override
  List<Object?> get props => [id, householdId, kind, input, result];
}
