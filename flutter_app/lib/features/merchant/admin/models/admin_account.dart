/// One row of `admin_list_profiles` (see
/// `supabase/migrations/20260922000000_add_admin_list_profiles_rpc.sql`):
/// what the admin "Accounts" list shows for each account, and enough to
/// change its role.
class AdminAccount {
  const AdminAccount({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.role,
  });

  /// `profiles.id` (== `auth.uid()`).
  final String id;

  final String firstName;
  final String lastName;

  /// The account's sign-up email (`auth.users.email`); empty when the
  /// account has none.
  final String email;

  /// Current `profiles.role`: `customer`, `merchant`, or `admin`.
  final String role;

  String get displayName {
    final name = '$firstName $lastName'.trim();
    if (name.isNotEmpty) return name;
    return email.isEmpty ? id : email;
  }

  AdminAccount copyWith({String? role}) => AdminAccount(
    id: id,
    firstName: firstName,
    lastName: lastName,
    email: email,
    role: role ?? this.role,
  );

  factory AdminAccount.fromMap(Map<String, dynamic> map) => AdminAccount(
    id: map['id'] as String,
    firstName: map['firstname'] as String? ?? '',
    lastName: map['lastname'] as String? ?? '',
    email: map['email'] as String? ?? '',
    role: map['role'] as String,
  );
}
