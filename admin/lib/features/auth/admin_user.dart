enum AdminRole {
  superAdmin('super_admin', 'Super admin'),
  admin('admin', 'Admin');

  const AdminRole(this.value, this.label);

  final String value;
  final String label;

  static AdminRole parse(String value) =>
      values.firstWhere((role) => role.value == value, orElse: () => admin);
}

/// A row of `admin_users`.
class AdminUser {
  const AdminUser({
    required this.userId,
    required this.fullName,
    required this.email,
    required this.role,
    required this.isActive,
    required this.createdAt,
  });

  factory AdminUser.fromJson(Map<String, dynamic> json) => AdminUser(
    userId: json['user_id'] as String,
    fullName: json['full_name'] as String,
    email: json['email'] as String,
    role: AdminRole.parse(json['role'] as String),
    isActive: json['is_active'] as bool,
    createdAt: DateTime.parse(json['created_at'] as String),
  );

  final String userId;
  final String fullName;
  final String email;
  final AdminRole role;
  final bool isActive;
  final DateTime createdAt;

  bool get isSuperAdmin => role == AdminRole.superAdmin;
}
