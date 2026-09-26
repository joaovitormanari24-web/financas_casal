import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/category.dart';

class CategoryRepository {
  CategoryRepository(this._client);

  final SupabaseClient _client;

  /// Categorias globais (household_id null) + personalizadas do household —
  /// a policy "categories_select" já filtra isso no banco.
  Future<List<Category>> fetchForHousehold(String householdId) async {
    final rows = await _client
        .from('categories')
        .select()
        .or('household_id.is.null,household_id.eq.$householdId')
        .order('name');
    return rows.map((row) => Category.fromJson(row)).toList();
  }

  Future<Category> create({
    required String householdId,
    required String name,
    required String icon,
    required String colorHex,
  }) async {
    final row = await _client
        .from('categories')
        .insert({
          'household_id': householdId,
          'name': name,
          'icon': icon,
          'color_hex': colorHex,
          'is_custom': true,
        })
        .select()
        .single();
    return Category.fromJson(row);
  }

  Future<void> update({
    required String id,
    required String name,
    required String icon,
    required String colorHex,
  }) async {
    await _client.from('categories').update({
      'name': name,
      'icon': icon,
      'color_hex': colorHex,
    }).eq('id', id);
  }

  Future<void> delete(String id) async {
    await _client.from('categories').delete().eq('id', id);
  }
}
