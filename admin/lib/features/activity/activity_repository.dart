import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/supabase_client.dart';

/// A row of `audit_logs`.
class AuditEntry {
  const AuditEntry({
    required this.id,
    required this.actorId,
    required this.action,
    required this.entityType,
    required this.entityId,
    required this.details,
    required this.createdAt,
  });

  factory AuditEntry.fromJson(Map<String, dynamic> json) => AuditEntry(
    id: json['id'] as int,
    actorId: json['actor_id'] as String?,
    action: json['action'] as String,
    entityType: json['entity_type'] as String,
    entityId: json['entity_id'] as String?,
    details: (json['details'] as Map?)?.cast<String, dynamic>() ?? const {},
    createdAt: DateTime.parse(json['created_at'] as String),
  );

  final int id;
  final String? actorId;
  final String action;
  final String entityType;
  final String? entityId;
  final Map<String, dynamic> details;
  final DateTime createdAt;

  /// The property this entry belongs to, if any.
  String? get propertyId =>
      details['property_id'] as String? ??
      (entityType == 'property' ? entityId : null);
}

class ActivityFilter {
  const ActivityFilter({this.entityType, this.actorId, this.from, this.to});

  final String? entityType;
  final String? actorId;
  final DateTime? from;

  /// Inclusive: the whole of this day.
  final DateTime? to;
}

/// A page of entries plus the property codes they mention.
class ActivityFeed {
  const ActivityFeed({required this.entries, required this.propertyCodes});

  final List<AuditEntry> entries;
  final Map<String, String> propertyCodes;
}

class ActivityRepository {
  ActivityRepository(this._client);

  final SupabaseClient _client;

  Future<ActivityFeed> fetch({
    ActivityFilter filter = const ActivityFilter(),
    int offset = 0,
    int limit = 50,
  }) async {
    var query = _client.from('audit_logs').select();
    if (filter.entityType != null) {
      query = query.eq('entity_type', filter.entityType!);
    }
    if (filter.actorId != null) query = query.eq('actor_id', filter.actorId!);
    if (filter.from != null) {
      query = query.gte('created_at', filter.from!.toUtc().toIso8601String());
    }
    if (filter.to != null) {
      final endOfDay = DateTime(
        filter.to!.year,
        filter.to!.month,
        filter.to!.day + 1,
      );
      query = query.lt('created_at', endOfDay.toUtc().toIso8601String());
    }
    final rows = await query
        .order('created_at', ascending: false)
        .order('id', ascending: false)
        .range(offset, offset + limit - 1);
    final entries = rows.map(AuditEntry.fromJson).toList();
    return ActivityFeed(
      entries: entries,
      propertyCodes: await _propertyCodes(entries),
    );
  }

  Future<Map<String, String>> _propertyCodes(List<AuditEntry> entries) async {
    final ids = entries
        .map((entry) => entry.propertyId)
        .whereType<String>()
        .toSet();
    if (ids.isEmpty) return const {};
    final rows = await _client
        .from('properties')
        .select('id, code')
        .inFilter('id', ids.toList());
    return {for (final row in rows) row['id'] as String: row['code'] as String};
  }
}

final activityRepositoryProvider = Provider<ActivityRepository>(
  (ref) => ActivityRepository(ref.watch(supabaseProvider)),
);

/// The latest 10 entries, for the dashboard.
final recentActivityProvider = FutureProvider.autoDispose<ActivityFeed>(
  (ref) => ref.watch(activityRepositoryProvider).fetch(limit: 10),
);
