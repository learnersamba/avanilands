import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors.dart';
import '../../core/formatting.dart';
import '../../core/theme.dart';
import '../../core/validators.dart';
import '../../core/widgets/common.dart';
import '../auth/admin_user.dart';
import '../auth/auth_controller.dart';
import 'admins_repository.dart';

/// Super admins invite admins, change roles and deactivate accounts.
class AdminsPage extends ConsumerWidget {
  const AdminsPage({super.key});

  Future<void> _run(
    BuildContext context,
    WidgetRef ref,
    Future<void> Function() action,
    String done,
  ) async {
    try {
      await action();
      ref.invalidate(adminUsersProvider);
      if (context.mounted) showMessage(context, done);
    } catch (error) {
      if (context.mounted) {
        showMessage(context, friendlyError(error), error: true);
      }
    }
  }

  Future<void> _onAction(
    BuildContext context,
    WidgetRef ref,
    AdminUser admin,
    String action,
  ) async {
    final repository = ref.read(adminsRepositoryProvider);
    switch (action) {
      case 'make_super':
        await _run(
          context,
          ref,
          () => repository.setRole(admin.userId, AdminRole.superAdmin),
          '${admin.fullName} is now a super admin.',
        );
      case 'make_admin':
        await _run(
          context,
          ref,
          () => repository.setRole(admin.userId, AdminRole.admin),
          '${admin.fullName} is now an admin.',
        );
      case 'deactivate':
        final ok = await confirmAction(
          context,
          title: 'Deactivate ${admin.fullName}?',
          message:
              'They lose access straight away and cannot sign in again until reactivated. '
              'Their past activity stays in the log.',
          confirmLabel: 'Deactivate',
          destructive: true,
        );
        if (ok && context.mounted) {
          await _run(
            context,
            ref,
            () => repository.setActive(admin.userId, active: false),
            '${admin.fullName} has been deactivated.',
          );
        }
      case 'reactivate':
        await _run(
          context,
          ref,
          () => repository.setActive(admin.userId, active: true),
          '${admin.fullName} can sign in again.',
        );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(currentAdminProvider);
    return PageBody(
      children: [
        PageHeader(
          title: 'Admin users',
          subtitle: 'People who can sign in to this panel. Customers never appear here.',
          actions: [
            FilledButton.icon(
              onPressed: () async {
                final invited = await showDialog<String>(
                  context: context,
                  builder: (_) => const _InviteDialog(),
                );
                if (invited != null && context.mounted) {
                  ref.invalidate(adminUsersProvider);
                  showMessage(context, 'Invitation sent to $invited.');
                }
              },
              icon: const Icon(Icons.person_add_alt, size: 18),
              label: const Text('Invite admin'),
            ),
          ],
        ),
        Card(
          child: AsyncValueView(
            value: ref.watch(adminUsersProvider),
            onRetry: () => ref.invalidate(adminUsersProvider),
            data: (admins) => SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('Name')),
                  DataColumn(label: Text('Email')),
                  DataColumn(label: Text('Role')),
                  DataColumn(label: Text('Status')),
                  DataColumn(label: Text('Added')),
                  DataColumn(label: Text('')),
                ],
                rows: [
                  for (final admin in admins)
                    DataRow(
                      cells: [
                        DataCell(
                          Text(
                            admin.userId == me.userId
                                ? '${admin.fullName} (you)'
                                : admin.fullName,
                          ),
                        ),
                        DataCell(Text(admin.email)),
                        DataCell(Text(admin.role.label)),
                        DataCell(
                          admin.isActive
                              ? const Pill(
                                  label: 'Active',
                                  color: BrandColors.available,
                                )
                              : const Pill(
                                  label: 'Deactivated',
                                  color: BrandColors.sold,
                                ),
                        ),
                        DataCell(Text(formatDate(admin.createdAt))),
                        DataCell(
                          admin.userId == me.userId
                              ? const Tooltip(
                                  message: 'You cannot change your own access.',
                                  child: Icon(
                                    Icons.lock_outline,
                                    size: 18,
                                    color: BrandColors.sold,
                                  ),
                                )
                              : PopupMenuButton<String>(
                                  tooltip: 'Actions',
                                  onSelected: (action) =>
                                      _onAction(context, ref, admin, action),
                                  itemBuilder: (_) => [
                                    if (admin.role == AdminRole.admin)
                                      const PopupMenuItem(
                                        value: 'make_super',
                                        child: Text('Make super admin'),
                                      ),
                                    if (admin.role == AdminRole.superAdmin)
                                      const PopupMenuItem(
                                        value: 'make_admin',
                                        child: Text('Make admin'),
                                      ),
                                    if (admin.isActive)
                                      const PopupMenuItem(
                                        value: 'deactivate',
                                        child: Text('Deactivate'),
                                      )
                                    else
                                      const PopupMenuItem(
                                        value: 'reactivate',
                                        child: Text('Reactivate'),
                                      ),
                                  ],
                                ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Super admins can also manage admin users and settings, and undo a "Sold" status.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}

/// Returns the invited email when the invitation was sent.
class _InviteDialog extends ConsumerStatefulWidget {
  const _InviteDialog();

  @override
  ConsumerState<_InviteDialog> createState() => _InviteDialogState();
}

class _InviteDialogState extends ConsumerState<_InviteDialog> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  AdminRole _role = AdminRole.admin;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(adminsRepositoryProvider)
          .invite(
            fullName: _name.text,
            email: _email.text,
            role: _role,
            redirectTo: '${Uri.base.origin}/set-password',
          );
      if (mounted) Navigator.pop(context, _email.text.trim().toLowerCase());
    } catch (error) {
      if (mounted) setState(() => _error = friendlyError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Invite an admin'),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'They get an email with a link to set their password.',
              ),
              const SizedBox(height: 16),
              if (_error != null) ...[
                Text(
                  _error!,
                  style: const TextStyle(color: BrandColors.danger),
                ),
                const SizedBox(height: 12),
              ],
              TextFormField(
                controller: _name,
                decoration: const InputDecoration(labelText: 'Full name'),
                validator: (value) =>
                    Validators.required(value, field: 'Name') ??
                    Validators.maxLength(value, 80),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _email,
                decoration: const InputDecoration(labelText: 'Email'),
                keyboardType: TextInputType.emailAddress,
                validator: Validators.email,
                onFieldSubmitted: (_) => _busy ? null : _send(),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<AdminRole>(
                initialValue: _role,
                decoration: const InputDecoration(labelText: 'Role'),
                items: [
                  for (final role in AdminRole.values)
                    DropdownMenuItem(value: role, child: Text(role.label)),
                ],
                onChanged: (role) =>
                    setState(() => _role = role ?? AdminRole.admin),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _busy ? null : _send,
          child: Text(_busy ? 'Sending…' : 'Send invitation'),
        ),
      ],
    );
  }
}
