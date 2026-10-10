/**
 * Ports `flutter_app/lib/services/food/models/category.dart`'s `Category`
 * (issue #382): one food-home category chip (e.g. "Pizza", "Burgers").
 */
export interface Category {
  id: string;
  name: string;
  iconUrl: string;
}

/** A raw `item_categories` row, as selected by `fetchCategories` below. */
export interface CategoryRow {
  id: string;
  name: string | null;
  icon_url: string | null;
}

/** Mirrors `Category.fromMap`'s column names and `?? 'Unknown'`/`?? ''` fallbacks. */
export function categoryFromRow(row: CategoryRow): Category {
  return {
    id: String(row.id),
    name: row.name ?? 'Unknown',
    iconUrl: row.icon_url ?? '',
  };
}
