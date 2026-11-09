import 'package:intl/intl.dart';

import '../enquiries/enquiry_models.dart' show toCsv;

/// Today in India (the reports count days in India time).
DateTime indiaToday() {
  final now = DateTime.now().toUtc().add(const Duration(hours: 5, minutes: 30));
  return DateTime.utc(now.year, now.month, now.day);
}

final _iso = DateFormat('yyyy-MM-dd');
final _short = DateFormat('d MMM');
final _long = DateFormat('d MMM y');

/// The dates a report covers. Lives in the address:
/// /analytics?range=30d, ?range=month, or ?from=2026-10-01&to=2026-10-31.
class AnalyticsRange {
  const AnalyticsRange._(this.preset, this.from, this.to);

  static const presets = {
    '7d': 'Last 7 days',
    '30d': 'Last 30 days',
    '90d': 'Last 90 days',
    'month': 'This month',
    'last_month': 'Last month',
  };

  factory AnalyticsRange.preset(String preset, {DateTime? today}) {
    final day = today ?? indiaToday();
    return switch (preset) {
      '7d' => AnalyticsRange._(
        preset,
        day.subtract(const Duration(days: 6)),
        day,
      ),
      '90d' => AnalyticsRange._(
        preset,
        day.subtract(const Duration(days: 89)),
        day,
      ),
      'month' => AnalyticsRange._(
        preset,
        DateTime.utc(day.year, day.month),
        day,
      ),
      'last_month' => AnalyticsRange._(
        preset,
        DateTime.utc(day.year, day.month - 1),
        DateTime.utc(day.year, day.month, 0),
      ),
      _ => AnalyticsRange._('30d', day.subtract(const Duration(days: 29)), day),
    };
  }

  /// A chosen period: at most a year, nothing after today.
  factory AnalyticsRange.custom(DateTime from, DateTime to, {DateTime? today}) {
    final day = today ?? indiaToday();
    var start = DateTime.utc(from.year, from.month, from.day);
    var end = DateTime.utc(to.year, to.month, to.day);
    if (end.isAfter(day)) end = day;
    if (start.isAfter(end)) start = end;
    if (end.difference(start).inDays > 365) {
      start = end.subtract(const Duration(days: 365));
    }
    return AnalyticsRange._('custom', start, end);
  }

  factory AnalyticsRange.fromQuery(
    Map<String, String> query, {
    DateTime? today,
  }) {
    final from = DateTime.tryParse(query['from'] ?? '');
    final to = DateTime.tryParse(query['to'] ?? '');
    if (from != null && to != null) {
      return AnalyticsRange.custom(from, to, today: today);
    }
    return AnalyticsRange.preset(query['range'] ?? '30d', today: today);
  }

  final String preset;
  final DateTime from;
  final DateTime to;

  int get days => to.difference(from).inDays + 1;

  String get fromIso => _iso.format(from);
  String get toIso => _iso.format(to);

  String get location => preset == 'custom'
      ? '/analytics?from=$fromIso&to=$toIso'
      : '/analytics?range=$preset';

  /// "1 Oct – 31 Oct 2026"
  String get dates => from.year == to.year
      ? '${_short.format(from)} – ${_long.format(to)}'
      : '${_long.format(from)} – ${_long.format(to)}';

  String get label => presets[preset] ?? dates;

  /// What the change is compared with.
  String get previousLabel => switch (preset) {
    'month' || 'last_month' => 'the month before',
    _ => 'the previous $days ${days == 1 ? 'day' : 'days'}',
  };

  @override
  bool operator ==(Object other) =>
      other is AnalyticsRange && other.from == from && other.to == to;

  @override
  int get hashCode => Object.hash(from, to);
}

class AnalyticsTotals {
  const AnalyticsTotals(this._values);

  factory AnalyticsTotals.fromJson(Map<String, dynamic> json) =>
      AnalyticsTotals({
        for (final entry in json.entries)
          if (entry.value is num) entry.key: entry.value as num,
      });

  final Map<String, num> _values;

  int operator [](String key) => (_values[key] ?? 0).toInt();

  num get salesValue => _values['sales_value'] ?? 0;

  /// Enquiries and site visit requests: people who got in touch.
  int get contacted => this['enquiries'] + this['site_visits'];
}

class DailyPoint {
  const DailyPoint({
    required this.day,
    required this.visitors,
    required this.pageViews,
    required this.propertyViews,
    required this.enquiries,
    required this.siteVisits,
    required this.bookings,
  });

  factory DailyPoint.fromJson(Map<String, dynamic> json) {
    int n(String key) => (json[key] as num?)?.toInt() ?? 0;
    return DailyPoint(
      day: DateTime.parse('${json['day']}T00:00:00Z'),
      visitors: n('visitors'),
      pageViews: n('page_views'),
      propertyViews: n('property_views'),
      enquiries: n('enquiries'),
      siteVisits: n('site_visits'),
      bookings: n('bookings'),
    );
  }

  final DateTime day;
  final int visitors;
  final int pageViews;
  final int propertyViews;
  final int enquiries;
  final int siteVisits;
  final int bookings;
}

class PropertyStats {
  const PropertyStats({
    required this.id,
    required this.code,
    required this.title,
    required this.availability,
    required this.views,
    required this.viewers,
    required this.enquiries,
    required this.siteVisits,
    required this.saves,
    required this.bookings,
    required this.sales,
  });

  factory PropertyStats.fromJson(Map<String, dynamic> json) {
    int n(String key) => (json[key] as num?)?.toInt() ?? 0;
    return PropertyStats(
      id: json['id'] as String,
      code: json['code'] as String,
      title: json['title'] as String,
      availability: json['availability'] as String,
      views: n('views'),
      viewers: n('viewers'),
      enquiries: n('enquiries'),
      siteVisits: n('site_visits'),
      saves: n('saves'),
      bookings: n('bookings'),
      sales: n('sales'),
    );
  }

  final String id;
  final String code;
  final String title;
  final String availability;
  final int views;
  final int viewers;
  final int enquiries;
  final int siteVisits;
  final int saves;
  final int bookings;
  final int sales;

  /// Enquiries and site visit requests per 100 people who looked at it.
  double? get interestRate =>
      viewers == 0 ? null : (enquiries + siteVisits) * 100 / viewers;
}

/// A row in the small lists: a place, land type, source or device.
class NamedCount {
  const NamedCount(this.name, this.count, [this.extra = 0]);

  final String name;
  final int count;

  /// Locations and land types: property views (count = searches).
  final int extra;

  int get total => count + extra;
}

class FunnelStep {
  const FunnelStep(this.label, this.value, {this.fromPrevious});

  final String label;
  final int value;

  /// Percent of the step before (null for the first step).
  final double? fromPrevious;
}

class AnalyticsReport {
  const AnalyticsReport({
    required this.range,
    required this.totals,
    required this.previous,
    required this.daily,
    required this.properties,
    required this.locations,
    required this.types,
    required this.sources,
    required this.devices,
  });

  factory AnalyticsReport.fromJson(
    AnalyticsRange range,
    Map<String, dynamic> json,
  ) {
    List<Map<String, dynamic>> list(String key) =>
        ((json[key] as List?) ?? const []).cast<Map<String, dynamic>>();
    int n(Object? value) => (value as num?)?.toInt() ?? 0;
    return AnalyticsReport(
      range: range,
      totals: AnalyticsTotals.fromJson(json['totals'] as Map<String, dynamic>),
      previous: AnalyticsTotals.fromJson(
        json['previous'] as Map<String, dynamic>,
      ),
      daily: list('daily').map(DailyPoint.fromJson).toList(),
      properties: list('properties').map(PropertyStats.fromJson).toList(),
      locations: [
        for (final row in list('locations'))
          NamedCount(
            row['name'] as String,
            n(row['searches']),
            n(row['property_views']),
          ),
      ],
      types: [
        for (final row in list('types'))
          NamedCount(
            row['name'] as String,
            n(row['searches']),
            n(row['property_views']),
          ),
      ],
      sources: [
        for (final row in list('sources'))
          NamedCount(row['source'] as String, n(row['visits'])),
      ],
      devices: [
        for (final row in list('devices'))
          NamedCount(
            humanizeDevice(row['device'] as String),
            n(row['visitors']),
          ),
      ],
    );
  }

  final AnalyticsRange range;
  final AnalyticsTotals totals;
  final AnalyticsTotals previous;
  final List<DailyPoint> daily;
  final List<PropertyStats> properties;
  final List<NamedCount> locations;
  final List<NamedCount> types;
  final List<NamedCount> sources;
  final List<NamedCount> devices;

  /// Totals, not people: nobody is followed from one step to the next.
  List<FunnelStep> get funnel {
    final values = [
      ('Visitors', totals['visitors']),
      ('Looked at a property', totals['property_viewers']),
      ('Enquired or asked for a visit', totals.contacted),
      ('Asked to book', totals['bookings']),
      ('Bought', totals['sales']),
    ];
    return [
      for (var i = 0; i < values.length; i++)
        FunnelStep(
          values[i].$1,
          values[i].$2,
          fromPrevious: i == 0
              ? null
              : percentOf(values[i].$2, values[i - 1].$2),
        ),
    ];
  }
}

String humanizeDevice(String device) => switch (device) {
  'mobile' => 'Phones',
  'tablet' => 'Tablets',
  'desktop' => 'Computers',
  _ => 'Unknown',
};

double? percentOf(int part, int whole) =>
    whole == 0 ? null : part * 100 / whole;

/// "12%", "0.8%", "–" when there is nothing to divide by.
String formatPercent(double? value) {
  if (value == null) return '–';
  if (value > 0 && value < 1) return '${value.toStringAsFixed(1)}%';
  return '${value.round()}%';
}

/// The change against the period before: "+12%", "−5%", "new", "no change".
String formatChange(int current, int previous) {
  if (current == previous) return 'no change';
  if (previous == 0) return 'new';
  final change = (current - previous) * 100 / previous;
  final rounded = change.round();
  if (rounded == 0) return change > 0 ? '+<1%' : '−<1%';
  return rounded > 0 ? '+$rounded%' : '−${-rounded}%';
}

/// One row per property (with activity or on the website) for spreadsheets.
String propertiesCsv(AnalyticsReport report) => toCsv([
  [
    'Code',
    'Property',
    'Availability',
    'Views',
    'Unique viewers',
    'Enquiries',
    'Site visit requests',
    'Saves',
    'Booking requests',
    'Sales',
    'Interest per 100 viewers',
  ],
  for (final p in report.properties)
    [
      p.code,
      p.title,
      p.availability,
      p.views,
      p.viewers,
      p.enquiries,
      p.siteVisits,
      p.saves,
      p.bookings,
      p.sales,
      p.interestRate?.toStringAsFixed(1) ?? '',
    ],
]);

/// One row per day for spreadsheets.
String dailyCsv(AnalyticsReport report) => toCsv([
  [
    'Date',
    'Visitors',
    'Page views',
    'Property views',
    'Enquiries',
    'Site visit requests',
    'Booking requests',
  ],
  for (final d in report.daily)
    [
      _iso.format(d.day),
      d.visitors,
      d.pageViews,
      d.propertyViews,
      d.enquiries,
      d.siteVisits,
      d.bookings,
    ],
]);
