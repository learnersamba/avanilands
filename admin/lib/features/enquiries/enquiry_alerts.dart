import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/browser.dart';
import '../auth/auth_controller.dart';
import '../bookings/bookings_repository.dart';
import '../notifications/notifications_repository.dart';
import '../dashboard/dashboard_repository.dart';
import '../site_visits/site_visit_models.dart';
import '../site_visits/site_visits_repository.dart';
import 'enquiries_repository.dart';

/// Listens for enquiries and site visit requests while the admin panel is
/// open: keeps the badges, dashboard and lists current, and announces each
/// new one (a message in the panel, plus a desktop notification when the tab
/// is in the background and alerts are turned on).
class EnquiryAlerts extends ConsumerStatefulWidget {
  const EnquiryAlerts({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<EnquiryAlerts> createState() => _EnquiryAlertsState();
}

class _EnquiryAlertsState extends ConsumerState<EnquiryAlerts> {
  final _stops = <void Function()>[];

  @override
  void initState() {
    super.initState();
    _stops
      ..add(
        ref
            .read(enquiriesRepositoryProvider)
            .watch(onInsert: _announceEnquiry, onChange: _refreshEnquiries),
      )
      ..add(
        ref
            .read(siteVisitsRepositoryProvider)
            .watch(onInsert: _announceVisit, onChange: _refreshVisits),
      )
      ..add(
        ref.read(notificationsRepositoryProvider).watch(
          ref.read(currentAdminProvider).userId,
          () {
            if (!mounted) return;
            ref
              ..invalidate(unreadNotificationsProvider)
              ..invalidate(notificationsProvider);
          },
        ),
      )
      ..add(
        ref
            .read(bookingsRepositoryProvider)
            .watch(onInsert: _announceBooking, onChange: _refreshBookings),
      );
  }

  @override
  void dispose() {
    for (final stop in _stops) {
      stop();
    }
    super.dispose();
  }

  void _refreshEnquiries() {
    if (!mounted) return;
    ref
      ..invalidate(dashboardSummaryProvider)
      ..invalidate(latestEnquiriesProvider)
      ..invalidate(enquiryPageProvider)
      ..invalidate(propertyEnquiriesProvider);
  }

  void _refreshVisits() {
    if (!mounted) return;
    ref
      ..invalidate(dashboardSummaryProvider)
      ..invalidate(siteVisitPageProvider)
      ..invalidate(siteVisitMonthProvider)
      ..invalidate(propertySiteVisitsProvider);
  }

  void _refreshBookings() {
    if (!mounted) return;
    ref
      ..invalidate(dashboardSummaryProvider)
      ..invalidate(bookingPageProvider)
      ..invalidate(propertyBookingsProvider);
  }

  void _announceBooking(Map<String, dynamic> row) {
    // Bookings the team starts itself need no alert.
    if (row['source'] != 'website') return;
    final reference = row['reference'] as String? ?? 'New booking';
    final name = row['name'] as String? ?? '';
    _announce(
      message: 'Booking request $reference from $name',
      title: 'Booking request $reference',
      body: name,
      tag: reference,
      path: row['id'] == null ? '/bookings' : '/bookings/${row['id']}',
    );
  }

  void _announceEnquiry(Map<String, dynamic> row) {
    final reference = row['reference'] as String? ?? 'New enquiry';
    final name = row['name'] as String? ?? '';
    _announce(
      message: 'New enquiry $reference from $name',
      title: 'New enquiry $reference',
      body: name,
      tag: reference,
      path: row['id'] == null ? '/enquiries' : '/enquiries/${row['id']}',
    );
  }

  void _announceVisit(Map<String, dynamic> row) {
    final reference = row['reference'] as String? ?? 'New site visit';
    final name = row['name'] as String? ?? '';
    final date = row['visit_date'] as String?;
    final slot = row['slot'] as String?;
    final when = date != null && slot != null
        ? '${formatVisitDay(date, year: false)}, ${formatVisitSlot(slot)}'
        : '';
    _announce(
      message: 'Site visit request $reference from $name · $when',
      title: 'Site visit request $reference',
      body: '$name · $when',
      tag: reference,
      path: row['id'] == null ? '/site-visits' : '/site-visits/${row['id']}',
    );
  }

  void _announce({
    required String message,
    required String title,
    required String body,
    required String tag,
    required String path,
  }) {
    if (!mounted) return;
    void open() => GoRouter.of(context).go(path);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 8),
        action: SnackBarAction(label: 'Open', onPressed: open),
      ),
    );
    if (pageHidden) {
      showDesktopNotification(title, body, tag: tag, onClick: open);
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
