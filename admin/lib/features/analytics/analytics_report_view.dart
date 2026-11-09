import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/formatting.dart';
import '../../core/theme.dart';
import '../../core/widgets/common.dart';
import 'analytics_models.dart';

final _number = NumberFormat.decimalPattern('en_IN');
final _dayLabel = DateFormat('EEE d MMM');

/// Everything below the date choice: numbers, chart, funnel, tables.
class AnalyticsReportView extends StatelessWidget {
  const AnalyticsReportView({super.key, required this.report});

  final AnalyticsReport report;

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 1100;
    final chart = _DailyChart(points: report.daily);
    final funnel = _Funnel(steps: report.funnel);
    final lists = [
      _RankedList(
        title: 'Places',
        hint: 'Searches · property views',
        rows: report.locations,
        valueText: (row) =>
            '${_number.format(row.count)} · ${_number.format(row.extra)}',
      ),
      _RankedList(
        title: 'Land types',
        hint: 'Searches · property views',
        rows: report.types,
        valueText: (row) =>
            '${_number.format(row.count)} · ${_number.format(row.extra)}',
      ),
      _RankedList(
        title: 'Where visits came from',
        hint: 'Visits',
        rows: report.sources,
        valueText: (row) => _number.format(row.count),
      ),
      _RankedList(
        title: 'Devices',
        hint: 'Visitors',
        rows: report.devices,
        valueText: (row) {
          final all = report.devices.fold<int>(0, (sum, d) => sum + d.count);
          return '${_number.format(row.count)} (${formatPercent(percentOf(row.count, all))})';
        },
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Numbers(report: report),
        const SizedBox(height: 24),
        if (wide)
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(flex: 3, child: chart),
                const SizedBox(width: 24),
                Expanded(flex: 2, child: funnel),
              ],
            ),
          )
        else ...[
          chart,
          const SizedBox(height: 24),
          funnel,
        ],
        const SizedBox(height: 24),
        _PropertyTable(properties: report.properties),
        const SizedBox(height: 24),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 1100
                ? 4
                : (constraints.maxWidth >= 640 ? 2 : 1);
            const gap = 24.0;
            final width =
                (constraints.maxWidth - gap * (columns - 1)) / columns;
            return Wrap(
              spacing: gap,
              runSpacing: gap,
              children: [
                for (final list in lists) SizedBox(width: width, child: list),
              ],
            );
          },
        ),
        const SizedBox(height: 16),
        Text(
          'Visitors are counted once per day without cookies, so someone who comes back on another day counts again. '
          'Bots and browsers that ask not to be tracked are not counted.',
          style: Theme.of(context).textTheme.bodySmall
              ?.copyWith(color: BrandColors.sold),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Number tiles with the change against the period before
// ---------------------------------------------------------------------------
class _Numbers extends StatelessWidget {
  const _Numbers({required this.report});

  final AnalyticsReport report;

  @override
  Widget build(BuildContext context) {
    final now = report.totals;
    final before = report.previous;
    final compare = report.range.previousLabel;
    final tiles = [
      _Tile(
        'Visitors',
        now['visitors'],
        before['visitors'],
        Icons.people_outline,
        note: '${_number.format(now['page_views'])} pages viewed',
      ),
      _Tile(
        'Property views',
        now['property_views'],
        before['property_views'],
        Icons.landscape_outlined,
        note: '${_number.format(now['searches'])} searches',
      ),
      _Tile(
        'Enquiries',
        now['enquiries'],
        before['enquiries'],
        Icons.mail_outline,
        note:
            '${_number.format(now['whatsapp_taps'])} WhatsApp · ${_number.format(now['call_taps'])} call taps',
      ),
      _Tile(
        'Site visit requests',
        now['site_visits'],
        before['site_visits'],
        Icons.event_available_outlined,
        note: 'Asked for on the website',
      ),
      _Tile(
        'Saves',
        now['saves'],
        before['saves'],
        Icons.favorite_border,
        note: 'Land saved by customers',
      ),
      _Tile(
        'Booking requests',
        now['bookings'],
        before['bookings'],
        Icons.key_outlined,
        note: 'From the website and the team',
      ),
      _Tile(
        'Sales',
        now['sales'],
        before['sales'],
        Icons.verified_outlined,
        note: now['sales'] == 0
            ? 'Bookings completed'
            : formatRupees(now.salesValue),
      ),
      _Tile(
        'Visitors who got in touch',
        null,
        null,
        Icons.percent,
        rate: percentOf(now.contacted, now['visitors']),
        previousRate: percentOf(before.contacted, before['visitors']),
        note: 'Enquiries + visit requests per visitor',
      ),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 640 ? 4 : 2;
        const gap = 16.0;
        final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final tile in tiles)
              SizedBox(
                width: width,
                child: _TileCard(tile: tile, compare: compare),
              ),
          ],
        );
      },
    );
  }
}

class _Tile {
  const _Tile(
    this.label,
    this.value,
    this.previous,
    this.icon, {
    this.note,
    this.rate,
    this.previousRate,
  });

  final String label;
  final int? value;
  final int? previous;
  final IconData icon;
  final String? note;
  final double? rate;
  final double? previousRate;
}

class _TileCard extends StatelessWidget {
  const _TileCard({required this.tile, required this.compare});

  final _Tile tile;
  final String compare;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final String value;
    final String change;
    final int direction;
    if (tile.value != null) {
      value = _number.format(tile.value);
      change = formatChange(tile.value!, tile.previous!);
      direction = tile.value!.compareTo(tile.previous!);
    } else {
      value = formatPercent(tile.rate);
      final now = tile.rate ?? 0;
      final before = tile.previousRate ?? 0;
      final points = now - before;
      change = points.abs() < 0.05
          ? 'no change'
          : '${points > 0 ? '+' : '−'}${points.abs().toStringAsFixed(1)} points';
      direction = points.abs() < 0.05 ? 0 : points.sign.toInt();
    }
    final changeColor = direction > 0
        ? BrandColors.available
        : (direction < 0 ? BrandColors.danger : BrandColors.sold);
    return Semantics(
      container: true,
      label: '${tile.label}: $value, $change compared with $compare',
      child: ExcludeSemantics(
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(tile.label, style: textTheme.bodyMedium),
                    ),
                    Icon(tile.icon, size: 18, color: BrandColors.forest),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  value,
                  style: textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: BrandColors.ink,
                  ),
                ),
                const SizedBox(height: 4),
                Tooltip(
                  message: 'Compared with $compare',
                  child: Text(
                    '$change vs before',
                    style: textTheme.bodySmall?.copyWith(
                      color: changeColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (tile.note != null)
                  Text(
                    tile.note!,
                    style: textTheme.bodySmall?.copyWith(
                      color: BrandColors.sold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Visitors per day
// ---------------------------------------------------------------------------
class _DailyChart extends StatelessWidget {
  const _DailyChart({required this.points});

  final List<DailyPoint> points;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final top = points.fold<int>(1, (max, p) => math.max(max, p.visitors));
    final small = textTheme.bodySmall?.copyWith(color: BrandColors.sold);
    return SectionCard(
      title: 'Visitors per day',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 180,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (final p in points)
                  Expanded(
                    child: Tooltip(
                      message:
                          '${_dayLabel.format(p.day)}\n'
                          '${p.visitors} visitors · ${p.pageViews} pages · ${p.propertyViews} property views\n'
                          '${p.enquiries} enquiries · ${p.siteVisits} visit requests · ${p.bookings} booking requests',
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: points.length > 60 ? 0.5 : 2,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Container(
                              height: 4,
                              margin: const EdgeInsets.only(bottom: 2),
                              decoration: BoxDecoration(
                                color: p.enquiries + p.siteVisits > 0
                                    ? BrandColors.sand
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                            Container(
                              height: math.max(2, 160 * p.visitors / top),
                              decoration: BoxDecoration(
                                color: BrandColors.forest.withValues(
                                  alpha: p.visitors == 0 ? 0.15 : 0.85,
                                ),
                                borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(3),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const Divider(height: 1),
          const SizedBox(height: 6),
          Wrap(
            spacing: 12,
            runSpacing: 4,
            children: [
              _legend(BrandColors.forest, 'Visitors'),
              _legend(BrandColors.sand, 'Day with enquiries or visit requests'),
            ],
          ),
          const SizedBox(height: 6),
          if (points.isNotEmpty)
            Row(
              children: [
                Text(_dayLabel.format(points.first.day), style: small),
                const Spacer(),
                Text('Most in a day: $top', style: small),
                const Spacer(),
                Text(_dayLabel.format(points.last.day), style: small),
              ],
            ),
        ],
      ),
    );
  }

  Widget _legend(Color color, String label) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
      const SizedBox(width: 4),
      Text(
        label,
        style: const TextStyle(fontSize: 12, color: BrandColors.sold),
      ),
    ],
  );
}

// ---------------------------------------------------------------------------
// Funnel
// ---------------------------------------------------------------------------
class _Funnel extends StatelessWidget {
  const _Funnel({required this.steps});

  final List<FunnelStep> steps;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final top = math.max(1, steps.first.value);
    return SectionCard(
      title: 'From visit to sale',
      trailing: const Tooltip(
        message: 'Totals for the period, not individual people: nobody is followed from one step to the next.',
        child: Icon(Icons.info_outline, size: 18, color: BrandColors.sold),
      ),
      child: Column(
        children: [
          for (final step in steps)
            Semantics(
              container: true,
              label:
                  '${step.label}: ${step.value}'
                  '${step.fromPrevious == null ? '' : ', ${formatPercent(step.fromPrevious)} of the step before'}',
              child: ExcludeSemantics(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              step.label,
                              style: textTheme.bodyMedium,
                            ),
                          ),
                          Text(
                            _number.format(step.value),
                            style: textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          SizedBox(
                            width: 64,
                            child: Text(
                              step.fromPrevious == null
                                  ? ''
                                  : formatPercent(step.fromPrevious),
                              textAlign: TextAlign.right,
                              style: textTheme.bodySmall?.copyWith(
                                color: BrandColors.sold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: step.value / top,
                          minHeight: 8,
                          color: BrandColors.forest,
                          backgroundColor: BrandColors.line,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          Text(
            'Percentages compare each step with the one above.',
            style: textTheme.bodySmall?.copyWith(color: BrandColors.sold),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Per property
// ---------------------------------------------------------------------------
enum _Sort { views, enquiries, siteVisits, saves, bookings, interest }

class _PropertyTable extends StatefulWidget {
  const _PropertyTable({required this.properties});

  final List<PropertyStats> properties;

  @override
  State<_PropertyTable> createState() => _PropertyTableState();
}

class _PropertyTableState extends State<_PropertyTable> {
  _Sort _sort = _Sort.views;
  bool _all = false;

  num _key(PropertyStats p) => switch (_sort) {
    _Sort.views => p.views,
    _Sort.enquiries => p.enquiries,
    _Sort.siteVisits => p.siteVisits,
    _Sort.saves => p.saves,
    _Sort.bookings => p.bookings,
    _Sort.interest => p.interestRate ?? -1,
  };

  @override
  Widget build(BuildContext context) {
    final sorted = [...widget.properties]
      ..sort((a, b) {
        final byKey = _key(b).compareTo(_key(a));
        return byKey != 0 ? byKey : b.views.compareTo(a.views);
      });
    final shown = _all ? sorted : sorted.take(10).toList();

    DataColumn column(String label, _Sort sort, {String? tooltip}) =>
        DataColumn(
          label: Text(label),
          numeric: true,
          tooltip: tooltip,
          onSort: (_, _) => setState(() => _sort = sort),
        );

    return SectionCard(
      title: 'Properties',
      trailing: sorted.length > 10
          ? TextButton(
              onPressed: () => setState(() => _all = !_all),
              child: Text(_all ? 'Show top 10' : 'Show all ${sorted.length}'),
            )
          : null,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
      child: sorted.isEmpty
          ? const EmptyState(message: 'No property activity in this period.')
          : LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: ConstrainedBox(
                  constraints: BoxConstraints(minWidth: constraints.maxWidth),
                  child: DataTable(
                    sortColumnIndex: _sort.index + 1,
                    sortAscending: false,
                    columnSpacing: 28,
                    showCheckboxColumn: false,
                    columns: [
                      const DataColumn(label: Text('Property')),
                      column(
                        'Views',
                        _Sort.views,
                        tooltip: 'Page views (unique viewers below)',
                      ),
                      column('Enquiries', _Sort.enquiries),
                      column('Visit requests', _Sort.siteVisits),
                      column('Saves', _Sort.saves),
                      column(
                        'Bookings',
                        _Sort.bookings,
                        tooltip: 'Booking requests (sales below)',
                      ),
                      column(
                        'Interest',
                        _Sort.interest,
                        tooltip: 'Enquiries + visit requests per 100 people who looked at it',
                      ),
                    ],
                    rows: [
                      for (final p in shown)
                        DataRow(
                          onSelectChanged: (_) =>
                              context.go('/properties/${p.id}'),
                          cells: [
                            DataCell(
                              ConstrainedBox(
                                constraints: const BoxConstraints(
                                  maxWidth: 280,
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${p.code} · ${humanize(p.availability)}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    Text(
                                      p.title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            DataCell(_twoLine(p.views, '${p.viewers} people')),
                            DataCell(Text('${p.enquiries}')),
                            DataCell(Text('${p.siteVisits}')),
                            DataCell(Text('${p.saves}')),
                            DataCell(
                              _twoLine(
                                p.bookings,
                                p.sales == 0 ? '' : '${p.sales} sold',
                              ),
                            ),
                            DataCell(Text(formatPercent(p.interestRate))),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  Widget _twoLine(int value, String note) => Column(
    mainAxisAlignment: MainAxisAlignment.center,
    crossAxisAlignment: CrossAxisAlignment.end,
    children: [
      Text(_number.format(value)),
      if (note.isNotEmpty)
        Text(
          note,
          style: const TextStyle(fontSize: 12, color: BrandColors.sold),
        ),
    ],
  );
}

// ---------------------------------------------------------------------------
// Places, land types, sources, devices
// ---------------------------------------------------------------------------
class _RankedList extends StatelessWidget {
  const _RankedList({
    required this.title,
    required this.hint,
    required this.rows,
    required this.valueText,
  });

  final String title;
  final String hint;
  final List<NamedCount> rows;
  final String Function(NamedCount row) valueText;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final top = rows.fold<int>(1, (max, row) => math.max(max, row.total));
    return SectionCard(
      title: title,
      child: rows.isEmpty
          ? const EmptyState(message: 'Nothing yet.')
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Text(
                    hint,
                    style: textTheme.bodySmall?.copyWith(
                      color: BrandColors.sold,
                    ),
                  ),
                ),
                for (final row in rows.take(8))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                row.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Text(valueText(row), style: textTheme.bodySmall),
                          ],
                        ),
                        const SizedBox(height: 4),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(3),
                          child: LinearProgressIndicator(
                            value: row.total / top,
                            minHeight: 5,
                            color: BrandColors.sand,
                            backgroundColor: BrandColors.line,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }
}
