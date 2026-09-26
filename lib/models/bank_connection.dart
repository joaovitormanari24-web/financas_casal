import 'package:equatable/equatable.dart';

/// Uma instituição bancária conectada via Pluggy (Open Finance) por um
/// membro do household — um "Item", na terminologia da Pluggy.
class BankConnection extends Equatable {
  const BankConnection({
    required this.id,
    required this.householdId,
    required this.memberId,
    required this.pluggyItemId,
    required this.status,
    this.institutionName,
    this.lastSyncedAt,
  });

  final String id;
  final String householdId;
  final String memberId;
  final String pluggyItemId;
  final String status;
  final String? institutionName;
  final DateTime? lastSyncedAt;

  factory BankConnection.fromJson(Map<String, dynamic> json) => BankConnection(
        id: json['id'] as String,
        householdId: json['household_id'] as String,
        memberId: json['member_id'] as String,
        pluggyItemId: json['pluggy_item_id'] as String,
        status: json['status'] as String,
        institutionName: json['institution_name'] as String?,
        lastSyncedAt: json['last_synced_at'] == null
            ? null
            : DateTime.parse(json['last_synced_at'] as String),
      );

  @override
  List<Object?> get props => [id, householdId, memberId, pluggyItemId, status, lastSyncedAt];
}
