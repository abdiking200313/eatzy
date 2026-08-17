/// Shared helpers for unwrapping Supabase RPC responses.
///
/// These are used by the food, grocery, and pharmacy repositories, which
/// each call a `place_*_order` RPC that is expected to return the new
/// order's id as a scalar value.
library;

/// Extracts a required id from an RPC response [value], trimming whitespace
/// and validating it is non-empty.
///
/// [label] describes what the RPC was for (e.g. `'grocery order'`) and is
/// used to build the [FormatException] message when [value] does not
/// contain a usable id.
String requiredRpcId(Object? value, String label) {
  final id = value?.toString().trim();
  if (id == null || id.isEmpty) {
    throw FormatException('The $label RPC did not return an ID.');
  }
  return id;
}
