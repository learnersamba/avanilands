import 'package:avanilands_admin/features/notifications/notifications_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('notifications read from the database', () {
    final unread = AppNotification.fromJson({
      'id': 7,
      'kind': 'payment',
      'title': 'Payment recorded: BKG-000003',
      'body': '₹1,00,000 · Kumar · AL-0002',
      'link': '/bookings/b1',
      'created_at': '2026-11-09T10:00:00Z',
      'read_at': null,
    });
    expect(unread.isUnread, isTrue);
    expect(unread.icon, Icons.payments_outlined);
    expect(unread.link, '/bookings/b1');

    final read = AppNotification.fromJson({
      'id': 8,
      'kind': 'customer',
      'title': 'New customer account',
      'body': null,
      'link': null,
      'created_at': '2026-11-09T10:00:00Z',
      'read_at': '2026-11-09T11:00:00Z',
    });
    expect(read.isUnread, isFalse);
    expect(read.icon, Icons.person_add_alt);
  });
}
