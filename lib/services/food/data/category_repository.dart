import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/category.dart';

class CategoryRepository {
  CategoryRepository({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  /// Default page size for the unbounded category list.
  ///
  /// The home screen does not yet page through categories — see issue #61
  /// — so this only bounds the worst case. A real pagination contract is
  /// left as a follow-up.
  static const int defaultPageSize = 50;

  /// Fetches categories, bounded to [limit] rows starting at [offset].
  Future<List<Category>> fetchCategories({
    int limit = defaultPageSize,
    int offset = 0,
  }) async {
    final rows = await _client
        .from('item_categories')
        .select('id, name, icon_url')
        .order('name')
        .range(offset, offset + limit - 1);

    return rows.map(Category.fromMap).toList();
  }
}
