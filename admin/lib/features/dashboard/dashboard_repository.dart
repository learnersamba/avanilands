import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/supabase_client.dart';

class DashboardSummary {
  const DashboardSummary({
    required this.total,
    required this.draft,
    required this.published,
    required this.hidden,
    required this.archived,
    required this.available,
    required this.reserved,
    required this.sold,
    required this.newEnquiries,
    required this.enquiriesLast7Days,
    required this.whatsappTapsLast7Days,
    required this.callTapsLast7Days,
    required this.requestedSiteVisits,
    required this.siteVisitsNext7Days,
    required this.bookingsToReview,
    required this.bookingsInProgress,
    this.visitorsLast7Days = 0,
  });

  factory DashboardSummary.fromJson(Map<String, dynamic> json) {
    int n(String key) => (json[key] as num?)?.toInt() ?? 0;
    return DashboardSummary(
      total: n('total'),
      draft: n('draft'),
      published: n('published'),
      hidden: n('hidden'),
      archived: n('archived'),
      available: n('available'),
      reserved: n('reserved'),
      sold: n('sold'),
      newEnquiries: n('new_enquiries'),
      enquiriesLast7Days: n('enquiries_last_7_days'),
      whatsappTapsLast7Days: n('whatsapp_taps_last_7_days'),
      callTapsLast7Days: n('call_taps_last_7_days'),
      requestedSiteVisits: n('requested_site_visits'),
      siteVisitsNext7Days: n('site_visits_next_7_days'),
      bookingsToReview: n('bookings_to_review'),
      bookingsInProgress: n('bookings_in_progress'),
      visitorsLast7Days: n('visitors_last_7_days'),
    );
  }

  final int total;
  final int draft;
  final int published;
  final int hidden;
  final int archived;
  final int available;
  final int reserved;
  final int sold;
  final int newEnquiries;
  final int enquiriesLast7Days;

  /// Taps on the website's WhatsApp and call buttons (no personal data).
  final int whatsappTapsLast7Days;
  final int callTapsLast7Days;

  /// Waiting for the team to confirm / confirmed in the coming week.
  final int requestedSiteVisits;
  final int siteVisitsNext7Days;

  /// Requests waiting for the team / approved and not yet completed.
  final int bookingsToReview;
  final int bookingsInProgress;

  /// Website visitors, counted once per day (Phase 16).
  final int visitorsLast7Days;
}

class EnquiryPreview {
  const EnquiryPreview({
    required this.id,
    required this.reference,
    required this.name,
    required this.status,
    required this.createdAt,
    this.propertyCode,
    this.propertyTitle,
  });

  factory EnquiryPreview.fromJson(Map<String, dynamic> json) {
    final property = json['property'] as Map<String, dynamic>?;
    return EnquiryPreview(
      id: json['id'] as String,
      reference: json['reference'] as String,
      name: json['name'] as String,
      status: json['status'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      propertyCode: property?['code'] as String?,
      propertyTitle: property?['title'] as String?,
    );
  }

  final String id;
  final String reference;
  final String name;
  final String status;
  final DateTime createdAt;
  final String? propertyCode;
  final String? propertyTitle;
}

class DashboardRepository {
  DashboardRepository(this._client);

  final SupabaseClient _client;

  Future<DashboardSummary> summary() async {
    final json = await _client.rpc<Map<String, dynamic>>('dashboard_summary');
    return DashboardSummary.fromJson(json);
  }

  Future<List<EnquiryPreview>> latestEnquiries({int limit = 5}) async {
    final rows = await _client
        .from('enquiries')
        .select(
          'id, reference, name, status, created_at, property:properties(code, title)',
        )
        .order('created_at', ascending: false)
        .limit(limit);
    return rows.map(EnquiryPreview.fromJson).toList();
  }
}

final dashboardRepositoryProvider = Provider<DashboardRepository>(
  (ref) => DashboardRepository(ref.watch(supabaseProvider)),
);

final dashboardSummaryProvider = FutureProvider.autoDispose<DashboardSummary>(
  (ref) => ref.watch(dashboardRepositoryProvider).summary(),
);

final latestEnquiriesProvider =
    FutureProvider.autoDispose<List<EnquiryPreview>>(
      (ref) => ref.watch(dashboardRepositoryProvider).latestEnquiries(),
    );
