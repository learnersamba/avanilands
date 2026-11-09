import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/supabase_client.dart';
import '../enquiries/enquiry_models.dart' show phoneSearchDigits;
import '../properties/properties_repository.dart';
import 'site_visit_models.dart';

class SiteVisitPage {
  const SiteVisitPage({required this.items, required this.total});

  final List<SiteVisit> items;
  final int total;
}

class SiteVisitsRepository {
  SiteVisitsRepository(this._client);

  final SupabaseClient _client;

  /// Upcoming visits soonest first; past visits latest first.
  Future<SiteVisitPage> list(SiteVisitQuery query) async {
    var request = _client.from('site_visits').select(SiteVisit.select);
    final search = cleanSearch(query.search);
    final upper = search.toUpperCase();
    final digits = phoneSearchDigits(search);
    if (RegExp(r'^AL-\d+$').hasMatch(upper)) {
      final property = await _client
          .from('properties')
          .select('id')
          .eq('code', upper)
          .maybeSingle();
      request = request.eq(
        'property_id',
        property?['id'] as String? ?? '00000000-0000-0000-0000-000000000000',
      );
    } else if (digits != null) {
      request = request.like('phone', '%$digits%');
    } else if (search.isNotEmpty) {
      request = request.or(
        'reference.ilike.%$search%,name.ilike.%$search%,email.ilike.%$search%',
      );
    }
    if (query.status != null) {
      request = request.eq('status', query.status!.value);
    }
    if (query.propertyId != null) {
      request = request.eq('property_id', query.propertyId!);
    }
    if (query.mine) {
      request = request.eq('assigned_to', _client.auth.currentUser!.id);
    }
    final today = indiaToday();
    var newestFirst = false;
    if (query.date != null) {
      request = request.eq('visit_date', query.date!);
    } else {
      switch (query.when) {
        case SiteVisitWhen.upcoming:
          request = request.gte('visit_date', today);
        case SiteVisitWhen.today:
          request = request.eq('visit_date', today);
        case SiteVisitWhen.week:
          request = request
              .gte('visit_date', today)
              .lte('visit_date', addDaysKey(today, 7));
        case SiteVisitWhen.past:
          request = request.lt('visit_date', today);
          newestFirst = true;
        case SiteVisitWhen.all:
          newestFirst = true;
      }
    }
    final from = (query.page - 1) * SiteVisitQuery.pageSize;
    final response = await request
        .order('visit_date', ascending: !newestFirst)
        .order('slot', ascending: !newestFirst)
        .order('id', ascending: true)
        .range(from, from + SiteVisitQuery.pageSize - 1)
        .count(CountOption.exact);
    return SiteVisitPage(
      items: response.data.map(SiteVisit.fromJson).toList(),
      total: response.count,
    );
  }

  /// Open visits per day in a month, for the calendar: {"2026-11-14": 2}.
  Future<Map<String, Map<SiteVisitStatus, int>>> monthCounts(
    int year,
    int month,
  ) async {
    final first = dateKey(DateTime.utc(year, month));
    final last = dateKey(DateTime.utc(year, month + 1, 0));
    final rows = await _client
        .from('site_visits')
        .select('visit_date, status')
        .gte('visit_date', first)
        .lte('visit_date', last)
        .neq('status', 'cancelled');
    final counts = <String, Map<SiteVisitStatus, int>>{};
    for (final row in rows) {
      final day = counts.putIfAbsent(row['visit_date'] as String, () => {});
      final status = SiteVisitStatus.parse(row['status'] as String?);
      day[status] = (day[status] ?? 0) + 1;
    }
    return counts;
  }

  Future<SiteVisit> get(String id) async => SiteVisit.fromJson(
    await _client
        .from('site_visits')
        .select(SiteVisit.select)
        .eq('id', id)
        .single(),
  );

  Future<List<SiteVisitNote>> notes(String id) async {
    final rows = await _client
        .from('site_visit_notes')
        .select()
        .eq('site_visit_id', id)
        .order('created_at', ascending: true)
        .order('id', ascending: true);
    return rows.map(SiteVisitNote.fromJson).toList();
  }

  /// confirm / reschedule / complete / no_show / cancel (database checks the
  /// order of steps and records each in the timeline).
  Future<void> act(
    String id,
    String action, {
    String? note,
    String? date,
    String? slot,
  }) => _client.rpc<void>(
    'update_site_visit',
    params: {
      'p_site_visit_id': id,
      'p_action': action,
      'p_note': (note?.trim().isEmpty ?? true) ? null : note!.trim(),
      'p_visit_date': date,
      'p_slot': slot,
    },
  );

  Future<void> addNote(String id, String note) => _client.rpc<void>(
    'add_site_visit_note',
    params: {'p_site_visit_id': id, 'p_note': note},
  );

  Future<void> assign(String id, String? adminId) => _client
      .from('site_visits')
      .update({'assigned_to': adminId})
      .eq('id', id)
      .select('id')
      .single();

  Future<List<SiteVisit>> forProperty(
    String propertyId, {
    int limit = 10,
  }) async {
    final rows = await _client
        .from('site_visits')
        .select(SiteVisit.select)
        .eq('property_id', propertyId)
        .order('visit_date', ascending: false)
        .limit(limit);
    return rows.map(SiteVisit.fromJson).toList();
  }

  Future<VisitSettings> settings() async => VisitSettings.fromJson(
    await _client
        .from('site_settings')
        .select(VisitSettings.columns)
        .eq('id', 1)
        .single(),
  );

  Future<VisitSettings> saveSettings(VisitSettings settings) async =>
      VisitSettings.fromJson(
        await _client
            .from('site_settings')
            .update(settings.toJson())
            .eq('id', 1)
            .select(VisitSettings.columns)
            .single(),
      );

  /// New or changed visits, as they happen. Returns a function that stops.
  void Function() watch({
    required void Function(Map<String, dynamic> row) onInsert,
    required void Function() onChange,
  }) {
    final channel = _client
        .channel('admin-site-visits')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'site_visits',
          callback: (payload) {
            if (payload.eventType == PostgresChangeEvent.insert) {
              onInsert(payload.newRecord);
            }
            onChange();
          },
        )
        .subscribe();
    return () => _client.removeChannel(channel);
  }
}

final siteVisitsRepositoryProvider = Provider<SiteVisitsRepository>(
  (ref) => SiteVisitsRepository(ref.watch(supabaseProvider)),
);

final siteVisitPageProvider = FutureProvider.autoDispose
    .family<SiteVisitPage, SiteVisitQuery>(
      (ref, query) => ref.watch(siteVisitsRepositoryProvider).list(query),
    );

final siteVisitMonthProvider = FutureProvider.autoDispose
    .family<Map<String, Map<SiteVisitStatus, int>>, (int, int)>(
      (ref, month) => ref
          .watch(siteVisitsRepositoryProvider)
          .monthCounts(month.$1, month.$2),
    );

final siteVisitProvider = FutureProvider.autoDispose.family<SiteVisit, String>(
  (ref, id) => ref.watch(siteVisitsRepositoryProvider).get(id),
);

final siteVisitNotesProvider = FutureProvider.autoDispose
    .family<List<SiteVisitNote>, String>(
      (ref, id) => ref.watch(siteVisitsRepositoryProvider).notes(id),
    );

final propertySiteVisitsProvider = FutureProvider.autoDispose
    .family<List<SiteVisit>, String>(
      (ref, propertyId) =>
          ref.watch(siteVisitsRepositoryProvider).forProperty(propertyId),
    );

final visitSettingsProvider = FutureProvider.autoDispose<VisitSettings>(
  (ref) => ref.watch(siteVisitsRepositoryProvider).settings(),
);
