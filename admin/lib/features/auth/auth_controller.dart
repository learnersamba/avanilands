import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../../core/errors.dart';
import '../../core/supabase_client.dart';
import 'admin_user.dart';

sealed class AuthState {
  const AuthState();
}

/// Checking the saved session or the admin record.
class AuthLoading extends AuthState {
  const AuthLoading();
}

class SignedOut extends AuthState {
  const SignedOut({this.message});

  /// Why the admin is on the sign-in page, e.g. "Your session ended."
  final String? message;
}

class SignedInAdmin extends AuthState {
  const SignedInAdmin(this.admin, {this.mustSetPassword = false});

  final AdminUser admin;

  /// True after following a password-reset link: the admin must choose a
  /// new password before doing anything else.
  final bool mustSetPassword;
}

final authControllerProvider = NotifierProvider<AuthController, AuthState>(
  AuthController.new,
);

/// Tracks the Supabase session and makes sure the signed-in user is an
/// active admin. Anyone else is signed out straight away (the database
/// would refuse them anyway; this keeps the screens honest).
class AuthController extends Notifier<AuthState> {
  StreamSubscription<sb.AuthState>? _subscription;
  String? _loadingFor;
  String? _signOutMessage;
  bool _signOutRequested = false;
  bool _mustSetPassword = false;

  sb.SupabaseClient get _client => ref.read(supabaseProvider);

  @override
  AuthState build() {
    final client = ref.watch(supabaseProvider);
    _subscription = client.auth.onAuthStateChange.listen(
      _onAuthChange,
      onError: (Object error) {
        // e.g. an expired invite or reset link in the address bar.
        state = SignedOut(message: friendlyError(error));
      },
    );
    ref.onDispose(() => _subscription?.cancel());

    final session = client.auth.currentSession;
    if (session == null) return const SignedOut();
    Future.microtask(() => _loadAdmin(session.user.id));
    return const AuthLoading();
  }

  void _onAuthChange(sb.AuthState data) {
    if (data.event == sb.AuthChangeEvent.passwordRecovery) {
      _mustSetPassword = true;
    }
    final session = data.session;
    if (session == null) {
      if (state is SignedOut) return;
      final message =
          _signOutMessage ??
          (_signOutRequested
              ? null
              : 'Your session ended. Please sign in again.');
      _signOutMessage = null;
      _signOutRequested = false;
      _mustSetPassword = false;
      state = SignedOut(message: message);
      return;
    }
    final current = state;
    if (current is SignedInAdmin &&
        current.admin.userId == session.user.id &&
        current.mustSetPassword == _mustSetPassword) {
      return; // token refresh, profile update, …
    }
    _loadAdmin(session.user.id);
  }

  Future<void> _loadAdmin(String userId) async {
    if (_loadingFor == userId) return;
    _loadingFor = userId;
    if (state is! SignedInAdmin) state = const AuthLoading();
    try {
      final row = await _client
          .from('admin_users')
          .select()
          .eq('user_id', userId)
          .maybeSingle();
      if (row == null || row['is_active'] != true) {
        await _signOutWith(
          row == null
              ? 'This account does not have admin access.'
              : 'This admin account has been deactivated.',
        );
        return;
      }
      // An invited admin arrives signed in by the email link but has no
      // password yet; make them choose one before anything else.
      final user = _client.auth.currentUser;
      if (user?.invitedAt != null &&
          user?.userMetadata?['password_set'] != true) {
        _mustSetPassword = true;
      }
      state = SignedInAdmin(
        AdminUser.fromJson(row),
        mustSetPassword: _mustSetPassword,
      );
    } catch (error) {
      await _signOutWith(friendlyError(error));
    } finally {
      _loadingFor = null;
    }
  }

  Future<void> _signOutWith(String message) async {
    _signOutMessage = message;
    try {
      await _client.auth.signOut();
    } catch (_) {
      // Signing out locally still happens; ignore network errors.
    }
    state = SignedOut(message: message);
  }

  /// Throws on wrong credentials; the caller shows [friendlyError].
  Future<void> signIn(String email, String password) async {
    final response = await _client.auth.signInWithPassword(
      email: email.trim().toLowerCase(),
      password: password,
    );
    final user = response.user;
    if (user != null) await _loadAdmin(user.id);
  }

  Future<void> signOut() async {
    _signOutRequested = true;
    await _client.auth.signOut();
  }

  /// Emails a link that opens /set-password.
  Future<void> sendPasswordReset(String email, {required String redirectTo}) =>
      _client.auth.resetPasswordForEmail(
        email.trim().toLowerCase(),
        redirectTo: redirectTo,
      );

  Future<void> setPassword(String password) async {
    await _client.auth.updateUser(
      sb.UserAttributes(password: password, data: {'password_set': true}),
    );
    _mustSetPassword = false;
    final current = state;
    if (current is SignedInAdmin) state = SignedInAdmin(current.admin);
  }

  /// Re-reads the signed-in admin's own record (e.g. after a name change).
  Future<void> refreshProfile() async {
    final current = state;
    if (current is SignedInAdmin) await _loadAdmin(current.admin.userId);
  }
}

/// The signed-in admin. Only use below the router's auth guard.
final currentAdminProvider = Provider<AdminUser>((ref) {
  final auth = ref.watch(authControllerProvider);
  if (auth is SignedInAdmin) return auth.admin;
  throw StateError('No admin is signed in.');
});
