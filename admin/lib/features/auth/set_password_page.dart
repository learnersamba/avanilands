import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/errors.dart';
import '../../core/validators.dart';
import '../../core/widgets/common.dart';
import 'auth_controller.dart';
import 'auth_layout.dart';

/// Used after accepting an invitation, after a reset link, and from the
/// profile menu ("Change password").
class SetPasswordPage extends ConsumerStatefulWidget {
  const SetPasswordPage({super.key});

  @override
  ConsumerState<SetPasswordPage> createState() => _SetPasswordPageState();
}

class _SetPasswordPageState extends ConsumerState<SetPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(authControllerProvider.notifier)
          .setPassword(_password.text);
      if (!mounted) return;
      showMessage(context, 'Password saved.');
      context.go('/');
    } catch (error) {
      if (mounted) setState(() => _error = friendlyError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    final required = auth is SignedInAdmin && auth.mustSetPassword;
    final name = auth is SignedInAdmin ? auth.admin.fullName : '';
    return AuthLayout(
      title: required ? 'Choose a new password' : 'Set your password',
      subtitle: name.isEmpty ? null : 'Signed in as $name.',
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_error != null) FormMessage(message: _error!),
            TextFormField(
              controller: _password,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'New password',
                helperText:
                    'At least 10 characters, with letters and a number.',
              ),
              autofillHints: const [AutofillHints.newPassword],
              validator: Validators.newPassword,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _confirm,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Repeat new password',
              ),
              validator: (value) => value == _password.text
                  ? null
                  : 'The passwords do not match.',
              onFieldSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _busy ? null : _submit,
              child: const Text('Save password'),
            ),
            if (!required) ...[
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => context.go('/'),
                child: const Text('Cancel'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
