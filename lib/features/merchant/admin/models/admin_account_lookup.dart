/// The result of `admin_lookup_profile_by_email` (see
/// `supabase/migrations/20260921020000_add_admin_role_management_rpcs.sql`):
/// enough about a matched account for the admin screen to confirm it found
/// the right one before changing its role.
class AdminAccountLookup {
  const AdminAccountLookup({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.role,
  });

  /// `profiles.id` (== `auth.uid()`).
  final String id;

  final String firstName;
  final String lastName;

  /// Current `profiles.role`: `customer`, `merchant`, or `admin`.
  final String role;

  String get displayName {
    final name = '$firstName $lastName'.trim();
    return name.isEmpty ? id : name;
  }

  factory AdminAccountLookup.fromMap(Map<String, dynamic> map) =>
      AdminAccountLookup(
        id: map['id'] as String,
        firstName: map['firstname'] as String? ?? '',
        lastName: map['lastname'] as String? ?? '',
        role: map['role'] as String,
      );
}
