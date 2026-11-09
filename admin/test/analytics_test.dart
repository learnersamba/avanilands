import 'package:avanilands_admin/features/analytics/analytics_models.dart';
import 'package:avanilands_admin/features/analytics/analytics_report_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

final today = DateTime.utc(2026, 11, 9);

Map<String, dynamic> totals({
  int visitors = 0,
  int viewers = 0,
  int enquiries = 0,
  int visits = 0,
  int bookings = 0,
  int sales = 0,
}) => {
  'visitors': visitors,
  'page_views': visitors * 3,
  'property_views': viewers * 2,
  'property_viewers': viewers,
  'searches': 12,
  'enquiries': enquiries,
  'site_visits': visits,
  'saves': 2,
  'bookings': bookings,
  'sales': sales,
  'sales_value': sales * 5400000,
  'whatsapp_taps': 4,
  'call_taps': 1,
};

AnalyticsReport sampleReport(
  AnalyticsRange range,
) => AnalyticsReport.fromJson(range, {
  'totals': totals(
    visitors: 400,
    viewers: 200,
    enquiries: 15,
    visits: 5,
    bookings: 4,
    sales: 1,
  ),
  'previous': totals(visitors: 320, viewers: 200, enquiries: 0, visits: 5),
  'daily': [
    {
      'day': '2026-11-08',
      'visitors': 30,
      'page_views': 90,
      'property_views': 40,
      'enquiries': 1,
      'site_visits': 0,
      'bookings': 0,
    },
    {
      'day': '2026-11-09',
      'visitors': 12,
      'page_views': 20,
      'property_views': 8,
      'enquiries': 0,
      'site_visits': 0,
      'bookings': 0,
    },
  ],
  'properties': [
    for (var i = 1; i <= 12; i++)
      {
        'id':
            '10000000-0000-4000-a000-0000000000${i.toString().padLeft(2, '0')}',
        'code': 'AL-${i.toString().padLeft(4, '0')}',
        'title': 'Plot $i',
        'slug': 'plot-$i',
        'availability': i == 7 ? 'reserved' : 'available',
        'publish_state': 'published',
        'views': 100 - i,
        'viewers': i == 12 ? 0 : 50 - i,
        'enquiries': i == 3 ? 9 : 1,
        'site_visits': i == 3 ? 1 : 0,
        'saves': 0,
        'bookings': i == 7 ? 1 : 0,
        'sales': i == 7 ? 1 : 0,
      },
  ],
  'locations': [
    {
      'name': 'Visakhapatnam',
      'district': 'Visakhapatnam',
      'searches': 30,
      'property_views': 70,
    },
  ],
  'types': <Map<String, dynamic>>[],
  'sources': [
    {'source': 'Search engines', 'visits': 120},
    {'source': 'Direct / unknown', 'visits': 80},
  ],
  'devices': [
    {'device': 'mobile', 'visitors': 300},
    {'device': 'desktop', 'visitors': 100},
  ],
});

void main() {
  group('date ranges', () {
    test('presets count back from today in India', () {
      final week = AnalyticsRange.fromQuery({'range': '7d'}, today: today);
      expect(
        [week.fromIso, week.toIso, week.days],
        ['2026-11-03', '2026-11-09', 7],
      );
      final month = AnalyticsRange.preset('month', today: today);
      expect([month.fromIso, month.toIso], ['2026-11-01', '2026-11-09']);
      final last = AnalyticsRange.preset('last_month', today: today);
      expect(
        [last.fromIso, last.toIso, last.previousLabel],
        ['2026-10-01', '2026-10-31', 'the month before'],
      );
      final january = AnalyticsRange.preset(
        'last_month',
        today: DateTime.utc(2027, 1, 15),
      );
      expect([january.fromIso, january.toIso], ['2026-12-01', '2026-12-31']);
    });

    test('anything unknown means the last 30 days', () {
      final range = AnalyticsRange.fromQuery({'range': 'junk'}, today: today);
      expect(
        [range.preset, range.days, range.location],
        ['30d', 30, '/analytics?range=30d'],
      );
      expect(range.previousLabel, 'the previous 30 days');
    });

    test('chosen dates stay within a year and not after today', () {
      final range = AnalyticsRange.fromQuery({
        'from': '2026-10-05',
        'to': '2026-10-20',
      }, today: today);
      expect(
        [range.preset, range.days, range.location],
        ['custom', 16, '/analytics?from=2026-10-05&to=2026-10-20'],
      );
      expect(range.dates, '5 Oct – 20 Oct 2026');
      final future = AnalyticsRange.custom(
        DateTime.utc(2026, 11, 1),
        DateTime.utc(2027, 1, 1),
        today: today,
      );
      expect(future.toIso, '2026-11-09');
      final long = AnalyticsRange.custom(
        DateTime.utc(2023, 1, 1),
        today,
        today: today,
      );
      expect(long.days, 366);
      final backwards = AnalyticsRange.custom(
        DateTime.utc(2026, 11, 5),
        DateTime.utc(2026, 11, 1),
        today: today,
      );
      expect(backwards.days, 1);
    });
  });

  test('changes and percentages read naturally', () {
    expect(formatChange(120, 100), '+20%');
    expect(formatChange(80, 100), '−20%');
    expect(formatChange(5, 0), 'new');
    expect(formatChange(0, 0), 'no change');
    expect(formatChange(1001, 1000), '+<1%');
    expect(formatPercent(null), '–');
    expect(formatPercent(0.4), '0.4%');
    expect(formatPercent(12.6), '13%');
  });

  test('the funnel compares each step with the one before', () {
    final report = sampleReport(AnalyticsRange.preset('30d', today: today));
    final funnel = report.funnel;
    expect(funnel.map((s) => s.value), [400, 200, 20, 4, 1]);
    expect(funnel.map((s) => formatPercent(s.fromPrevious)), [
      '–',
      '50%',
      '10%',
      '20%',
      '25%',
    ]);
    expect(
      report.properties.firstWhere((p) => p.code == 'AL-0003').interestRate,
      closeTo(21.3, 0.1),
    );
    expect(report.properties.last.interestRate, isNull);
    expect(report.devices.map((d) => d.name), ['Phones', 'Computers']);
  });

  test('CSV exports have a row per property and per day', () {
    final report = sampleReport(AnalyticsRange.preset('30d', today: today));
    final properties = propertiesCsv(report).split('\r\n');
    expect(properties.length, 13);
    expect(
      properties.first,
      startsWith('Code,Property,Availability,Views,Unique viewers,Enquiries'),
    );
    expect(properties[3], 'AL-0003,Plot 3,available,97,47,9,1,0,0,0,21.3');
    final daily = dailyCsv(report).split('\r\n');
    expect(daily, [
      'Date,Visitors,Page views,Property views,Enquiries,Site visit requests,Booking requests',
      '2026-11-08,30,90,40,1,0,0',
      '2026-11-09,12,20,8,0,0,0',
    ]);
  });

  testWidgets('the page shows the numbers, funnel and top properties', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final range = AnalyticsRange.preset('30d', today: today);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: AnalyticsReportView(report: sampleReport(range)),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.bySemanticsLabel(
        RegExp(r'^Visitors: 400, \+25% compared with the previous 30 days'),
      ),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel(RegExp(r'^Enquiries: 15, new')),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel(
        RegExp(r'^Visitors who got in touch: 5%, \+3\.4 points'),
      ),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel('Bought: 1, 25% of the step before'),
      findsOneWidget,
    );
    expect(find.text('Show all 12'), findsOneWidget);
    expect(find.text('AL-0011 · Available'), findsNothing);

    // Sorting by enquiries puts AL-0003 first.
    await tester.tap(find.text('Enquiries').last);
    await tester.pumpAndSettle();
    final first = tester.getTopLeft(find.text('AL-0003 · Available')).dy;
    final second = tester.getTopLeft(find.text('AL-0001 · Available')).dy;
    expect(first, lessThan(second));

    await tester.tap(find.text('Show all 12'));
    await tester.pumpAndSettle();
    expect(find.text('AL-0011 · Available'), findsOneWidget);
  });
}
