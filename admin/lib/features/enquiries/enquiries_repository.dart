import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/supabase_client.dart';
import '../properties/properties_repository.dart';
import 'enquiry_models.dart';

class EnquiryPage {
  const EnquiryPage({required this.items, required this.total});

  final List<Enquiry> items;
  final int total;
}

class EnquiriesRepository {
  EnquiriesRepository(this._client);

  final SupabaseClient _client;

  /// The filtered request, newest first. Search understands references
  /// (ENQ-…), property codes (AL-…), phone numbers, names and emails.
  Future<PostgrestTransformBuilder<PostgrestList>> _filtered(
    EnquiryQuery query,
  ) async {
    var request = _client.from('enquiries').select(Enquiry.select);
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
    final duration = query.range.duration;
    if (duration != null) {
      request = request.gte(
        'created_at',
        DateTime.now().toUtc().subtract(duration).toIso8601String(),
      );
    }
    switch (query.assignee) {
      case EnquiryAssignee.me:
        request = request.eq('assigned_to', _client.auth.currentUser!.id);
      case EnquiryAssignee.nobody:
        request = request.isFilter('assigned_to', null);
      case EnquiryAssignee.anyone:
        break;
    }
    return request
        .order('created_at', ascending: false)
        .order('id', ascending: true);
  }

  Future<EnquiryPage> list(EnquiryQuery query) async {
    final from = (query.page - 1) * EnquiryQuery.pageSize;
    final response = await (await _filtered(query))
        .range(from, from + EnquiryQuery.pageSize - 1)
        .count(CountOption.exact);
    return EnquiryPage(
      items: response.data.map(Enquiry.fromJson).toList(),
      total: response.count,
    );
  }

  /// Every enquiry matching the filters (for CSV), fetched in batches.
  Future<List<Enquiry>> exportAll(EnquiryQuery query, {int max = 10000}) async {
    const batch = 1000;
    final all = <Enquiry>[];
    for (var from = 0; from < max; from += batch) {
      final rows = await (await _filtered(query)).range(from, from + batch - 1);
      all.addAll(rows.map(Enquiry.fromJson));
      if (rows.length < batch) break;
    }
    return all;
  }

  Future<Enquiry> get(String id) async => Enquiry.fromJson(
    await _client
        .from('enquiries')
        .select(Enquiry.select)
        .eq('id', id)
        .single(),
  );

  Future<List<EnquiryNote>> notes(String enquiryId) async {
    final rows = await _client
        .from('enquiry_notes')
        .select()
        .eq('enquiry_id', enquiryId)
        .order('created_at', ascending: true)
        .order('id', ascending: true);
    return rows.map(EnquiryNote.fromJson).toList();
  }

  /// Status change (with an optional note) goes through the database
  /// function so every change is recorded in the timeline.
  Future<void> updateStatus(String id, EnquiryStatus status, String? note) =>
      _client.rpc<void>(
        'update_enquiry_status',
        params: {'p_enquiry_id': id, 'p_status': status.value, 'p_note': note},
      );

  Future<void> addNote(String id, String note) => _client.rpc<void>(
    'add_enquiry_note',
    params: {'p_enquiry_id': id, 'p_note': note},
  );

  Future<void> assign(String id, String? adminId) => _client
      .from('enquiries')
      .update({'assigned_to': adminId})
      .eq('id', id)
      .select('id')
      .single();

  Future<List<Enquiry>> forProperty(String propertyId, {int limit = 10}) async {
    final rows = await _client
        .from('enquiries')
        .select(Enquiry.select)
        .eq('property_id', propertyId)
        .order('created_at', ascending: false)
        .limit(limit);
    return rows.map(Enquiry.fromJson).toList();
  }

  /// New or changed enquiries, as they happen (Supabase Realtime).
  /// Returns a function that stops listening.
  void Function() watch({
    required void Function(Map<String, dynamic> row) onInsert,
    required void Function() onChange,
  }) {
    final channel = _client
        .channel('admin-enquiries')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'enquiries',
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

final enquiriesRepositoryProvider = Provider<EnquiriesRepository>(
  (ref) => EnquiriesRepository(ref.watch(supabaseProvider)),
);

final enquiryPageProvider = FutureProvider.autoDispose
    .family<EnquiryPage, EnquiryQuery>(
      (ref, query) => ref.watch(enquiriesRepositoryProvider).list(query),
    );

final enquiryProvider = FutureProvider.autoDispose.family<Enquiry, String>(
  (ref, id) => ref.watch(enquiriesRepositoryProvider).get(id),
);

final enquiryNotesProvider = FutureProvider.autoDispose
    .family<List<EnquiryNote>, String>(
      (ref, id) => ref.watch(enquiriesRepositoryProvider).notes(id),
    );

final propertyEnquiriesProvider = FutureProvider.autoDispose
    .family<List<Enquiry>, String>(
      (ref, propertyId) =>
          ref.watch(enquiriesRepositoryProvider).forProperty(propertyId),
    );
