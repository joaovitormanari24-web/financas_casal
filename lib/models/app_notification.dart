import 'package:equatable/equatable.dart';

/// Alerta/insight do household (briefing, seção 36) — ex.: orçamento
/// estourado, conta recorrente lançada, meta atingida.
class AppNotification extends Equatable {
  const AppNotification({
    required this.id,
    required this.householdId,
    required this.title,
    required this.body,
    required this.kind,
    this.memberId,
    this.readAt,
    required this.createdAt,
  });

  final String id;
  final String householdId;
  final String? memberId;
  final String title;
  final String body;
  final String kind;
  final DateTime? readAt;
  final DateTime createdAt;

  bool get isRead => readAt != null;

  factory AppNotification.fromJson(Map<String, dynamic> json) => AppNotification(
        id: json['id'] as String,
        householdId: json['household_id'] as String,
        memberId: json['member_id'] as String?,
        title: json['title'] as String,
        body: json['body'] as String,
        kind: json['kind'] as String? ?? 'info',
        readAt: json['read_at'] == null ? null : DateTime.parse(json['read_at'] as String),
        createdAt: DateTime.parse(json['created_at'] as String),
      );

  @override
  List<Object?> get props => [id, householdId, title, body, kind, readAt, createdAt];
}
