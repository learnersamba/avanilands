import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/supabase_client.dart';
import '../enquiries/enquiry_models.dart' show phoneSearchDigits;
import '../properties/properties_repository.dart';
import 'booking_models.dart';

class BookingPage {
  const BookingPage({required this.items, required this.total});

  final List<Booking> items;
  final int total;
}

class BookingsRepository {
  BookingsRepository(this._client);

  final SupabaseClient _client;

  Future<BookingPage> list(BookingQuery query) async {
    var request = _client.from('bookings').select(Booking.select);
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
    } else if (query.open) {
      request = request.not('status', 'in', '(completed,cancelled)');
    }
    if (query.propertyId != null) {
      request = request.eq('property_id', query.propertyId!);
    }
    final from = (query.page - 1) * BookingQuery.pageSize;
    final response = await request
        .order('created_at', ascending: false)
        .order('id', ascending: true)
        .range(from, from + BookingQuery.pageSize - 1)
        .count(CountOption.exact);
    return BookingPage(
      items: response.data.map(Booking.fromJson).toList(),
      total: response.count,
    );
  }

  Future<Booking> get(String id) async => Booking.fromJson(
    await _client.from('bookings').select(Booking.select).eq('id', id).single(),
  );

  Future<List<BookingNote>> notes(String id) async {
    final rows = await _client
        .from('booking_notes')
        .select()
        .eq('booking_id', id)
        .order('created_at', ascending: true)
        .order('id', ascending: true);
    return rows.map(BookingNote.fromJson).toList();
  }

  /// One step; the database checks the order, the role and the property.
  Future<void> act(
    String id,
    String action, {
    String? note,
    double? amount,
    String? receivedOn,
    String? paymentMethod,
    String? paymentReference,
    double? agreedPrice,
  }) => _client.rpc<void>(
    'update_booking',
    params: {
      'p_booking_id': id,
      'p_action': action,
      'p_note': (note?.trim().isEmpty ?? true) ? null : note!.trim(),
      'p_amount': amount,
      'p_received_on': receivedOn,
      'p_payment_method': paymentMethod,
      'p_payment_reference': paymentReference,
      'p_agreed_price': agreedPrice,
    },
  );

  Future<void> addNote(String id, String note) => _client.rpc<void>(
    'add_booking_note',
    params: {'p_booking_id': id, 'p_note': note},
  );

  Future<void> assign(String id, String? adminId) => _client
      .from('bookings')
      .update({'assigned_to': adminId})
      .eq('id', id)
      .select('id')
      .single();

  /// The team starts a booking (e.g. after a site visit). Returns its id.
  Future<String> create({
    required String propertyId,
    required String name,
    required String phone,
    String? email,
    String? siteVisitId,
    double? agreedPrice,
    String? note,
  }) async => await _client.rpc<String>(
    'create_booking',
    params: {
      'p_property_id': propertyId,
      'p_name': name,
      'p_phone': phone,
      'p_email': email,
      'p_site_visit_id': siteVisitId,
      'p_agreed_price': agreedPrice,
      'p_note': note,
    },
  );

  Future<List<Booking>> forProperty(String propertyId, {int limit = 10}) async {
    final rows = await _client
        .from('bookings')
        .select(Booking.select)
        .eq('property_id', propertyId)
        .order('created_at', ascending: false)
        .limit(limit);
    return rows.map(Booking.fromJson).toList();
  }

  void Function() watch({
    required void Function(Map<String, dynamic> row) onInsert,
    required void Function() onChange,
  }) {
    final channel = _client
        .channel('admin-bookings')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'bookings',
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

final bookingsRepositoryProvider = Provider<BookingsRepository>(
  (ref) => BookingsRepository(ref.watch(supabaseProvider)),
);

final bookingPageProvider = FutureProvider.autoDispose
    .family<BookingPage, BookingQuery>(
      (ref, query) => ref.watch(bookingsRepositoryProvider).list(query),
    );

final bookingProvider = FutureProvider.autoDispose.family<Booking, String>(
  (ref, id) => ref.watch(bookingsRepositoryProvider).get(id),
);

final bookingNotesProvider = FutureProvider.autoDispose
    .family<List<BookingNote>, String>(
      (ref, id) => ref.watch(bookingsRepositoryProvider).notes(id),
    );

final propertyBookingsProvider = FutureProvider.autoDispose
    .family<List<Booking>, String>(
      (ref, propertyId) =>
          ref.watch(bookingsRepositoryProvider).forProperty(propertyId),
    );
