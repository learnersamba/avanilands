import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/supabase_client.dart';
import 'analytics_models.dart';

class AnalyticsRepository {
  AnalyticsRepository(this._client);

  final SupabaseClient _client;

  Future<AnalyticsReport> report(AnalyticsRange range) async {
    final json = await _client.rpc<Map<String, dynamic>>(
      'analytics_report',
      params: {'p_from': range.fromIso, 'p_to': range.toIso},
    );
    return AnalyticsReport.fromJson(range, json);
  }
}

final analyticsRepositoryProvider = Provider<AnalyticsRepository>(
  (ref) => AnalyticsRepository(ref.watch(supabaseProvider)),
);

final analyticsReportProvider = FutureProvider.autoDispose
    .family<AnalyticsReport, AnalyticsRange>(
      (ref, range) => ref.watch(analyticsRepositoryProvider).report(range),
    );
