import 'package:equatable/equatable.dart';

class Profile extends Equatable {
  const Profile({
    required this.id,
    required this.fullName,
    this.avatarUrl,
  });

  final String id;
  final String fullName;
  final String? avatarUrl;

  factory Profile.fromJson(Map<String, dynamic> json) => Profile(
        id: json['id'] as String,
        fullName: json['full_name'] as String,
        avatarUrl: json['avatar_url'] as String?,
      );

  /// Primeiro nome, usado nas saudações contextuais da Home
  /// (briefing, seção 65).
  String get firstName => fullName.split(' ').first;

  @override
  List<Object?> get props => [id, fullName, avatarUrl];
}
