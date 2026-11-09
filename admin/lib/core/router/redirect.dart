import '../../features/auth/auth_controller.dart';

/// Pages anyone can open.
const publicPaths = {'/login', '/forgot-password'};

/// Pages only super admins can open.
const superAdminPaths = {'/settings', '/admins', '/content'};

/// Where the router should send someone, or null to stay.
/// Kept free of Flutter so it can be unit-tested.
String? authRedirect(AuthState auth, Uri uri) {
  final path = uri.path;
  switch (auth) {
    case AuthLoading():
      if (path == '/splash') return null;
      return _withFrom('/splash', uri.toString());
    case SignedOut():
      if (publicPaths.contains(path)) return null;
      final from = path == '/splash'
          ? uri.queryParameters['from']
          : uri.toString();
      return _withFrom('/login', from);
    case SignedInAdmin(:final admin, :final mustSetPassword):
      if (mustSetPassword) {
        return path == '/set-password' ? null : '/set-password';
      }
      if (publicPaths.contains(path) || path == '/splash') {
        return safeReturnPath(uri.queryParameters['from']) ?? '/';
      }
      if (superAdminPaths.contains(path) && !admin.isSuperAdmin) return '/';
      return null;
  }
}

String _withFrom(String target, String? from) {
  final safe = safeReturnPath(from);
  if (safe == null || safe == '/') return target;
  return '$target?from=${Uri.encodeComponent(safe)}';
}

/// Only same-site app paths; never back to the sign-in pages.
String? safeReturnPath(String? from) {
  if (from == null || !from.startsWith('/') || from.startsWith('//')) {
    return null;
  }
  final path = Uri.parse(from).path;
  if (publicPaths.contains(path) ||
      path == '/splash' ||
      path == '/set-password') {
    return null;
  }
  return from;
}
