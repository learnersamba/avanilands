import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/errors.dart';
import '../../core/formatting.dart';
import '../../core/theme.dart';
import '../../core/widgets/common.dart';
import 'notifications_repository.dart';

/// Everything that happened for this admin: new enquiries, visit and
/// booking requests, payments, new customers. Newest first.
class NotificationsPage extends ConsumerWidget {
  const NotificationsPage({super.key, required this.unreadOnly});

  final bool unreadOnly;

  void _refresh(WidgetRef ref) {
    ref
      ..invalidate(notificationsProvider)
      ..invalidate(unreadNotificationsProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unread = ref.watch(unreadNotificationsProvider).value ?? 0;
    final repo = ref.read(notificationsRepositoryProvider);
    return PageBody(
      maxWidth: 900,
      children: [
        PageHeader(
          title: 'Notifications',
          subtitle: unread == 0
              ? 'You\'re up to date.'
              : '$unread unread. Older ones are removed after 90 days.',
          actions: [
            OutlinedButton.icon(
              onPressed: unread == 0
                  ? null
                  : () async {
                      try {
                        await repo.markAllRead();
                        _refresh(ref);
                      } catch (error) {
                        if (context.mounted) {
                          showMessage(
                            context,
                            friendlyError(error),
                            error: true,
                          );
                        }
                      }
                    },
              icon: const Icon(Icons.done_all, size: 18),
              label: const Text('Mark all as read'),
            ),
          ],
        ),
        Wrap(
          spacing: 8,
          children: [
            ChoiceChip(
              label: const Text('All'),
              selected: !unreadOnly,
              onSelected: (_) => context.go('/notifications'),
            ),
            ChoiceChip(
              label: Text('Unread ($unread)'),
              selected: unreadOnly,
              onSelected: (_) => context.go('/notifications?unread=1'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Card(
          clipBehavior: Clip.antiAlias,
          child: AsyncValueView(
            value: ref.watch(notificationsProvider(unreadOnly)),
            onRetry: () => ref.invalidate(notificationsProvider(unreadOnly)),
            data: (items) => items.isEmpty
                ? EmptyState(
                    icon: Icons.notifications_none,
                    message: unreadOnly
                        ? 'Nothing unread.'
                        : 'No notifications yet.',
                  )
                : Column(
                    children: [
                      for (final item in items)
                        Material(
                          color: item.isUnread
                              ? BrandColors.sand.withValues(alpha: 0.08)
                              : Colors.transparent,
                          child: ListTile(
                            leading: Icon(item.icon, color: BrandColors.forest),
                            title: Text(
                              item.title,
                              style: TextStyle(
                                fontWeight: item.isUnread
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                              ),
                            ),
                            subtitle: Text(
                              [
                                if (item.body != null) item.body!,
                                formatRelative(item.createdAt),
                              ].join(' · '),
                            ),
                            trailing: item.isUnread
                                ? const Icon(
                                    Icons.circle,
                                    size: 10,
                                    color: BrandColors.danger,
                                    semanticLabel: 'Unread',
                                  )
                                : null,
                            onTap: () async {
                              if (item.isUnread) {
                                await repo.markRead(item.id);
                                _refresh(ref);
                              }
                              if (item.link != null && context.mounted) {
                                context.go(item.link!);
                              }
                            },
                          ),
                        ),
                    ],
                  ),
          ),
        ),
      ],
    );
  }
}
