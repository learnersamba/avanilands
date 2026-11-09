import 'package:avanilands_admin/core/formatting.dart';
import 'package:avanilands_admin/features/activity/activity_repository.dart';
import 'package:avanilands_admin/features/activity/activity_text.dart';
import 'package:avanilands_admin/features/bookings/booking_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('each step offers the owner\'s next steps', () {
    List<String> names(BookingStatus s) =>
        actionsFor(s).map((a) => a.value).toList();
    expect(names(BookingStatus.requested), [
      'send_for_approval',
      'approve',
      'cancel',
    ]);
    expect(names(BookingStatus.pendingApproval), ['approve', 'cancel']);
    expect(names(BookingStatus.approved), ['request_payment', 'cancel']);
    expect(names(BookingStatus.paymentPending), ['record_payment', 'cancel']);
    expect(names(BookingStatus.reserved), ['complete', 'cancel']);
    expect(actionsFor(BookingStatus.completed), isEmpty);
    expect(actionsFor(BookingStatus.cancelled), isEmpty);
  });

  test('only super admins approve and complete', () {
    final superOnly = {
      for (final s in BookingStatus.values)
        for (final a in actionsFor(s))
          if (a.superAdminOnly) a.value,
    };
    expect(superOnly, {'approve', 'complete'});
  });

  test('which steps hold the property', () {
    expect(
      BookingStatus.values.where((s) => s.holdsProperty).map((s) => s.value),
      ['approved', 'payment_pending', 'reserved'],
    );
  });

  test('filters in the address', () {
    final query = BookingQuery.fromUri(
      Uri.parse('/bookings?status=reserved&all=1&q=BKG-000001&property=p1'),
    );
    expect(query.status, BookingStatus.reserved);
    expect(query.open, isFalse);
    expect(BookingQuery.fromUri(Uri.parse(query.location)), query);
    expect(const BookingQuery().location, '/bookings');
  });

  test('timeline lines', () {
    BookingNote note(Map<String, dynamic> json) => BookingNote.fromJson({
      'id': 'n',
      'created_at': '2026-11-09T10:00:00Z',
      ...json,
    });
    expect(
      note({
        'status_from': 'payment_pending',
        'status_to': 'reserved',
        'details': {
          'amount_received': 100000,
          'payment_method': 'upi',
          'payment_reference': 'UTR1',
        },
      }).headline(formatRupees),
      'Payment recorded ₹1,00,000 by UPI (ref UTR1)',
    );
    expect(
      note({'status_from': 'reserved', 'status_to': 'cancelled'})
          .headline(formatRupees),
      'Cancelled (was Reserved)',
    );
  });

  test('activity log lines', () {
    AuditEntry entry(Map<String, dynamic> d) => AuditEntry(
      id: 1,
      actorId: null,
      action: 'booking.status_changed',
      entityType: 'booking',
      entityId: 'b1',
      details: d,
      createdAt: DateTime(2026, 11, 9),
    );
    expect(
      describeActivity(entry({'reference': 'BKG-000001', 'to': 'approved'})),
      'Booking BKG-000001: approved (property reserved)',
    );
    expect(
      describeActivity(entry({'reference': 'BKG-000001', 'to': 'completed'})),
      'Booking BKG-000001: sale completed (property sold)',
    );
  });
}
