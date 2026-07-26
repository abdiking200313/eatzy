import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/category.dart';

class CategoryRepository {
  CategoryRepository({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Future<List<Category>> fetchCategories() async {
    final rows = await _client
        .from('item_categories')
        .select('id, name, icon_url');

    return rows.map(Category.fromMap).toList();
  }
}
