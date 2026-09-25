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
}
