import 'package:avanilands_admin/core/errors.dart';
import 'package:avanilands_admin/core/validators.dart';
import 'package:avanilands_admin/features/auth/auth_controller.dart';
import 'package:avanilands_admin/features/auth/login_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart'
    show AuthException, PostgrestException;

/// Records sign-in attempts instead of calling Supabase.
class _FakeAuth extends AuthController {
  _FakeAuth(this._initial);

  final AuthState _initial;
  final attempts = <String>[];

  @override
  AuthState build() => _initial;

  @override
  Future<void> signIn(String email, String password) async {
    attempts.add(email);
    throw const AuthException('Invalid login credentials', statusCode: '400');
  }
}

Future<_FakeAuth> _pump(
  WidgetTester tester, {
  AuthState initial = const SignedOut(),
}) async {
  final fake = _FakeAuth(initial);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [authControllerProvider.overrideWith(() => fake)],
      child: const MaterialApp(home: LoginPage()),
    ),
  );
  return fake;
}

void main() {
  testWidgets('empty form is not sent', (tester) async {
    final fake = await _pump(tester);
    await tester.tap(find.byKey(const Key('login-submit')));
    await tester.pump();
    expect(find.text('Email is required.'), findsOneWidget);
    expect(find.text('Password is required.'), findsOneWidget);
    expect(fake.attempts, isEmpty);
  });

  testWidgets('wrong password shows a friendly message', (tester) async {
    final fake = await _pump(tester);
    await tester.enterText(
      find.byKey(const Key('login-email')),
      'admin@avanilands.test',
    );
    await tester.enterText(
      find.byKey(const Key('login-password')),
      'not-the-password',
    );
    await tester.tap(find.byKey(const Key('login-submit')));
    await tester.pumpAndSettle();
    expect(fake.attempts, ['admin@avanilands.test']);
    expect(find.text('Wrong email or password.'), findsOneWidget);
  });

  testWidgets('shows why the admin was signed out', (tester) async {
    await _pump(
      tester,
      initial: const SignedOut(
        message: 'This account does not have admin access.',
      ),
    );
    expect(
      find.text('This account does not have admin access.'),
      findsOneWidget,
    );
  });

  group('friendlyError', () {
    test('database rule sentences pass through', () {
      expect(
        friendlyError(
          const PostgrestException(
            message: 'Add a cover image before publishing.',
            code: '23514',
          ),
        ),
        'Add a cover image before publishing.',
      );
    });

    test('raw constraint errors are replaced', () {
      expect(
        friendlyError(
          const PostgrestException(
            message: 'new row for relation "properties" violates check constraint "x"',
            code: '23514',
          ),
        ),
        'Some details are not valid. Please check the form.',
      );
    });
  });

  group('validators', () {
    test('new password needs length, letters and a number', () {
      expect(Validators.newPassword('short1'), isNotNull);
      expect(Validators.newPassword('longpassword'), isNotNull);
      expect(Validators.newPassword('longpassword7'), isNull);
    });

    test('WhatsApp number', () {
      expect(Validators.whatsapp('919000000000'), isNull);
      expect(Validators.whatsapp('+91 90000 00000'), isNotNull);
      expect(Validators.whatsapp(''), isNull);
    });
  });
}
