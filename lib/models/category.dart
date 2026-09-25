import 'package:equatable/equatable.dart';

/// Categoria de transação (briefing, seção 29). O household começa com
/// categorias padrão e pode criar categorias personalizadas.
class Category extends Equatable {
  const Category({
    required this.id,
    required this.householdId,
    required this.name,
    required this.icon,
    required this.colorHex,
    this.isCustom = false,
  });

  final String id;

  /// null para categorias globais padrão do sistema.
  final String? householdId;
  final String name;

  /// Nome do ícone (mapeado para IconData na camada de UI).
  final String icon;
  final String colorHex;
  final bool isCustom;

  factory Category.fromJson(Map<String, dynamic> json) => Category(
        id: json['id'] as String,
        householdId: json['household_id'] as String?,
        name: json['name'] as String,
        icon: json['icon'] as String,
        colorHex: json['color_hex'] as String,
        isCustom: json['is_custom'] as bool? ?? false,
      );

  @override
  List<Object?> get props => [id, householdId, name, icon, colorHex];
}
