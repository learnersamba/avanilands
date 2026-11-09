import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/supabase_client.dart';
import '../auth/admin_user.dart';

class AdminsRepository {
  AdminsRepository(this._client);

  final SupabaseClient _client;

  Future<List<AdminUser>> list() async {
    final rows = await _client
        .from('admin_users')
        .select()
        .order('created_at', ascending: true);
    return rows.map(AdminUser.fromJson).toList();
  }

  Future<void> setRole(String userId, AdminRole role) => _client
      .from('admin_users')
      .update({'role': role.value})
      .eq('user_id', userId)
      .select()
      .single();

  Future<void> setActive(String userId, {required bool active}) => _client
      .from('admin_users')
      .update({'is_active': active})
      .eq('user_id', userId)
      .select()
      .single();

  /// Sends an invitation email (Edge Function `invite-admin`, super admins only).
  Future<void> invite({
    required String fullName,
    required String email,
    required AdminRole role,
    required String redirectTo,
  }) async {
    await _client.functions.invoke(
      'invite-admin',
      body: {
        'full_name': fullName.trim(),
        'email': email.trim().toLowerCase(),
        'role': role.value,
        'redirect_to': redirectTo,
      },
    );
  }
}

final adminsRepositoryProvider = Provider<AdminsRepository>(
  (ref) => AdminsRepository(ref.watch(supabaseProvider)),
);

final adminUsersProvider = FutureProvider.autoDispose<List<AdminUser>>(
  (ref) => ref.watch(adminsRepositoryProvider).list(),
);

/// user id → full name, for showing who did what.
final adminNamesProvider = Provider.autoDispose<Map<String, String>>((ref) {
  final admins = ref.watch(adminUsersProvider).value ?? const [];
  return {for (final admin in admins) admin.userId: admin.fullName};
});
