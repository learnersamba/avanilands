import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/supabase_client.dart';

/// One notification for the signed-in admin (written by the database).
class AppNotification {
  const AppNotification({
    required this.id,
    required this.kind,
    required this.title,
    this.body,
    this.link,
    required this.createdAt,
    this.readAt,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) =>
      AppNotification(
        id: (json['id'] as num).toInt(),
        kind: json['kind'] as String,
        title: json['title'] as String,
        body: json['body'] as String?,
        link: json['link'] as String?,
        createdAt: DateTime.parse(json['created_at'] as String),
        readAt: json['read_at'] == null
            ? null
            : DateTime.parse(json['read_at'] as String),
      );

  final int id;
  final String kind;
  final String title;
  final String? body;

  /// An admin panel path, e.g. `/enquiries/<id>`.
  final String? link;
  final DateTime createdAt;
  final DateTime? readAt;

  bool get isUnread => readAt == null;

  IconData get icon => switch (kind) {
    'enquiry' => Icons.mail_outline,
    'site_visit' => Icons.event_available_outlined,
    'booking' => Icons.key_outlined,
    'payment' => Icons.payments_outlined,
    'customer' => Icons.person_add_alt,
    _ => Icons.notifications_none,
  };
}

class NotificationsRepository {
  NotificationsRepository(this._client);

  final SupabaseClient _client;

  Future<List<AppNotification>> list({bool unreadOnly = false}) async {
    var request = _client
        .from('notifications')
        .select('id, kind, title, body, link, created_at, read_at');
    if (unreadOnly) request = request.isFilter('read_at', null);
    final rows = await request
        .order('created_at', ascending: false)
        .order('id', ascending: false)
        .limit(100);
    return rows.map(AppNotification.fromJson).toList();
  }

  Future<int> unreadCount() async {
    final response = await _client
        .from('notifications')
        .select('id')
        .isFilter('read_at', null)
        .count(CountOption.exact);
    return response.count;
  }

  Future<void> markRead(int id) => _client
      .from('notifications')
      .update({'read_at': DateTime.now().toUtc().toIso8601String()})
      .eq('id', id)
      .isFilter('read_at', null);

  Future<void> markAllRead() => _client
      .from('notifications')
      .update({'read_at': DateTime.now().toUtc().toIso8601String()})
      .isFilter('read_at', null);

  /// Any change to my notifications (row rules: only mine arrive).
  void Function() watch(String userId, void Function() onChange) {
    final channel = _client
        .channel('admin-notifications-$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'notifications',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: (_) => onChange(),
        )
        .subscribe();
    return () => _client.removeChannel(channel);
  }
}

final notificationsRepositoryProvider = Provider<NotificationsRepository>(
  (ref) => NotificationsRepository(ref.watch(supabaseProvider)),
);

final unreadNotificationsProvider = FutureProvider.autoDispose<int>(
  (ref) => ref.watch(notificationsRepositoryProvider).unreadCount(),
);

final notificationsProvider = FutureProvider.autoDispose
    .family<List<AppNotification>, bool>(
      (ref, unreadOnly) => ref
          .watch(notificationsRepositoryProvider)
          .list(unreadOnly: unreadOnly),
    );
