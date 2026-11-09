import 'package:avanilands_admin/core/router/redirect.dart';
import 'package:avanilands_admin/features/auth/admin_user.dart';
import 'package:avanilands_admin/features/auth/auth_controller.dart';
import 'package:flutter_test/flutter_test.dart';

AdminUser _admin(AdminRole role) => AdminUser(
  userId: 'u1',
  fullName: 'Test Admin',
  email: 'test@avanilands.test',
  role: role,
  isActive: true,
  createdAt: DateTime(2026, 11, 8),
);

String? _go(AuthState auth, String location) =>
    authRedirect(auth, Uri.parse(location));

void main() {
  group('signed out', () {
    const out = SignedOut();

    test('sign-in pages stay open', () {
      expect(_go(out, '/login'), isNull);
      expect(_go(out, '/forgot-password'), isNull);
    });

    test('app pages go to sign-in and remember where you were', () {
      expect(_go(out, '/'), '/login');
      expect(_go(out, '/activity?x=1'), '/login?from=%2Factivity%3Fx%3D1');
      expect(_go(out, '/set-password'), '/login');
    });

    test('splash passes its target on to sign-in', () {
      expect(_go(out, '/splash?from=%2Fsettings'), '/login?from=%2Fsettings');
    });
  });

  group('loading', () {
    test('waits on the splash page, keeping the target', () {
      expect(_go(const AuthLoading(), '/admins'), '/splash?from=%2Fadmins');
      expect(_go(const AuthLoading(), '/splash?from=%2Fadmins'), isNull);
    });
  });

  group('signed in', () {
    final admin = SignedInAdmin(_admin(AdminRole.admin));
    final superAdmin = SignedInAdmin(_admin(AdminRole.superAdmin));

    test('leaves the sign-in page for the saved target or the dashboard', () {
      expect(_go(admin, '/login'), '/');
      expect(_go(admin, '/login?from=%2Factivity'), '/activity');
      expect(_go(admin, '/splash?from=%2Factivity'), '/activity');
    });

    test('ignores unsafe return targets', () {
      expect(_go(admin, '/login?from=https%3A%2F%2Fevil.example'), '/');
      expect(_go(admin, '/login?from=%2F%2Fevil.example'), '/');
      expect(_go(admin, '/login?from=%2Flogin'), '/');
    });

    test('super-admin pages are closed to admins', () {
      expect(_go(admin, '/settings'), '/');
      expect(_go(admin, '/admins'), '/');
      expect(_go(admin, '/content'), '/');
      expect(_go(superAdmin, '/content'), isNull);
      expect(_go(superAdmin, '/settings'), isNull);
      expect(_go(superAdmin, '/admins'), isNull);
    });

    test('a reset link forces a new password first', () {
      final mustSet = SignedInAdmin(
        _admin(AdminRole.admin),
        mustSetPassword: true,
      );
      expect(_go(mustSet, '/'), '/set-password');
      expect(_go(mustSet, '/set-password'), isNull);
    });
  });
}
