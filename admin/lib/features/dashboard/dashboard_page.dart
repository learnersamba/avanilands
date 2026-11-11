import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/formatting.dart';
import '../../core/theme.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/landscape.dart';
import '../activity/activity_repository.dart';
import '../activity/activity_text.dart';
import '../activity/activity_tile.dart';
import '../admins/admins_repository.dart';
import '../analytics/analytics_models.dart';
import '../analytics/analytics_repository.dart';
import '../auth/auth_controller.dart';
import '../enquiries/enquiries_page.dart';
import '../enquiries/enquiry_models.dart';
import '../site_visits/site_visits_repository.dart';
import 'dashboard_charts.dart';
import 'dashboard_repository.dart';

/// Dashboard colours on top of the brand ones: soft card tints and text greys.
abstract final class _Tone {
  static const cream = Color(0xFFF7F5EF);
  static const text = Color(0xFF17211D);
  static const muted = Color(0xFF68736F);
  static const sage = Color(0xFFDCEDE3);
  static const reserved = Color(0xFFD7962B);
  static const sold = Color(0xFF7D8A92);
  static const draft = Color(0xFFE6C77D);
}

BoxDecoration _cardDecoration() => BoxDecoration(
  color: Colors.white,
  borderRadius: BorderRadius.circular(20),
  border: Border.all(color: BrandColors.line.withValues(alpha: 0.8)),
  boxShadow: const [
    BoxShadow(color: Color(0x0A17211D), blurRadius: 18, offset: Offset(0, 4)),
  ],
);

class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  void _refresh(WidgetRef ref) {
    ref
      ..invalidate(dashboardSummaryProvider)
      ..invalidate(latestEnquiriesProvider)
      ..invalidate(siteVisitPageProvider)
      ..invalidate(recentActivityProvider)
      ..invalidate(analyticsReportProvider)
      ..invalidate(adminUsersProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final admin = ref.watch(currentAdminProvider);
    final firstName = admin.fullName.split(' ').first;
    final summary = ref.watch(dashboardSummaryProvider);

    return PageBody(
      maxWidth: 1560,
      children: [
        _Hero(
          greeting: '${_greeting()}, $firstName',
          summary: summary.value,
          onRefresh: () => _refresh(ref),
        ),
        const SizedBox(height: 24),
        AsyncValueView(
          value: summary,
          onRetry: () => ref.invalidate(dashboardSummaryProvider),
          data: (summary) => _Overview(summary: summary),
        ),
        const SizedBox(height: 24),
        LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth < 1100) {
              return const Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _LatestEnquiries(),
                  SizedBox(height: 24),
                  _RecentActivity(),
                ],
              );
            }
            return const IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(flex: 5, child: _LatestEnquiries()),
                  SizedBox(width: 24),
                  Expanded(flex: 7, child: _RecentActivity()),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  static String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }
}

// ---------------------------------------------------------------- Hero

/// Welcome banner over a painted countryside, with what needs doing now.
class _Hero extends StatelessWidget {
  const _Hero({
    required this.greeting,
    required this.summary,
    required this.onRefresh,
  });

  final String greeting;
  final DashboardSummary? summary;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final narrow = width < 700;
    // Below this the text reaches the painting, so the overlay covers it all.
    final veiled = width < 1200;
    final s = summary;
    String plural(int n, String one, String many) => n == 1 ? one : many;
    final todo = <_Todo>[
      if (s != null && s.newEnquiries > 0)
        _Todo(
          Icons.mail_outline,
          '${s.newEnquiries} new ${plural(s.newEnquiries, 'enquiry', 'enquiries')}',
          '/enquiries?status=new',
        ),
      if (s != null && s.requestedSiteVisits > 0)
        _Todo(
          Icons.calendar_today_outlined,
          '${s.requestedSiteVisits} ${plural(s.requestedSiteVisits, 'visit', 'visits')} to confirm',
          '/site-visits?status=requested&when=all',
        ),
      if (s != null && s.bookingsToReview > 0)
        _Todo(
          Icons.sell_outlined,
          '${s.bookingsToReview} ${plural(s.bookingsToReview, 'booking', 'bookings')} to review',
          '/bookings',
        ),
    ];
    final cream = _Tone.cream;
    return Container(
      constraints: const BoxConstraints(minHeight: 214),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: BrandColors.line.withValues(alpha: 0.8)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F17211D),
            blurRadius: 24,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: [
          const Positioned.fill(
            child: CustomPaint(painter: LandscapePainter()),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: veiled
                      ? [
                          cream.withValues(alpha: 0.95),
                          cream.withValues(alpha: 0.8),
                        ]
                      : [
                          cream.withValues(alpha: 0.97),
                          cream.withValues(alpha: 0.88),
                          cream.withValues(alpha: 0),
                        ],
                  stops: veiled ? null : const [0, 0.38, 0.64],
                ),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              narrow ? 20 : 32,
              narrow ? 20 : 26,
              narrow ? 20 : 32,
              narrow ? 22 : 28,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.calendar_today_outlined,
                      size: 16,
                      color: BrandColors.forest,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      DateFormat('EEEE, d MMMM y').format(DateTime.now()),
                      style: const TextStyle(
                        color: _Tone.text,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.only(right: 48),
                  child: Text(
                    '$greeting 👋',
                    style: TextStyle(
                      color: BrandColors.forestDark,
                      fontSize: narrow ? 26 : 34,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.6,
                      height: 1.15,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  "Here's how your land inventory and enquiries are performing today.",
                  style: TextStyle(
                    color: _Tone.text.withValues(alpha: 0.78),
                    fontSize: 15,
                  ),
                ),
                if (s != null) ...[
                  const SizedBox(height: 20),
                  Wrap(
                    spacing: 12,
                    runSpacing: 10,
                    children: todo.isEmpty
                        ? [
                            const _HeroChip(
                              item: _Todo(
                                Icons.check_circle_outline,
                                "You're all caught up",
                                null,
                              ),
                            ),
                          ]
                        : [for (final item in todo) _HeroChip(item: item)],
                  ),
                ],
              ],
            ),
          ),
          Positioned(
            top: 14,
            right: 14,
            child: Material(
              color: Colors.white.withValues(alpha: 0.85),
              shape: const CircleBorder(),
              child: IconButton(
                tooltip: 'Refresh',
                onPressed: onRefresh,
                icon: const Icon(
                  Icons.refresh,
                  size: 20,
                  color: BrandColors.forest,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Todo {
  const _Todo(this.icon, this.label, this.route);
  final IconData icon;
  final String label;
  final String? route;
}

class _HeroChip extends StatelessWidget {
  const _HeroChip({required this.item});

  final _Todo item;

  @override
  Widget build(BuildContext context) {
    final route = item.route;
    return DecoratedBox(
      decoration: const BoxDecoration(
        borderRadius: BorderRadius.all(Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Color(0x1417211D),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.white,
        shape: const StadiumBorder(),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: route == null ? null : () => context.go(route),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 12, 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(item.icon, size: 17, color: BrandColors.forest),
                const SizedBox(width: 10),
                Text(
                  item.label,
                  style: const TextStyle(
                    color: _Tone.text,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (route != null) ...[
                  const SizedBox(width: 8),
                  const Icon(Icons.chevron_right, size: 18, color: _Tone.text),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- Overview

class _Overview extends StatelessWidget {
  const _Overview({required this.summary});

  final DashboardSummary summary;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 1100;
        final inventory = _InventoryPanel(
          summary: summary,
          height: wide ? 330 : null,
        );
        final visitors = _VisitorsPanel(height: wide ? 330 : null);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _KpiGrid(summary: summary, width: constraints.maxWidth),
            const SizedBox(height: 24),
            if (wide)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 5, child: inventory),
                  const SizedBox(width: 24),
                  Expanded(flex: 7, child: visitors),
                ],
              )
            else ...[
              inventory,
              const SizedBox(height: 24),
              visitors,
            ],
          ],
        );
      },
    );
  }
}

class _KpiTone {
  const _KpiTone(this.background, this.border, this.iconBackground, this.ink);
  final Color background;
  final Color border;
  final Color iconBackground;
  final Color ink;

  static const sage = _KpiTone(
    Color(0xFFEDF6F0),
    Color(0xFFD5E8DC),
    Color(0xFFD3E9DB),
    BrandColors.forest,
  );
  static const beige = _KpiTone(
    Color(0xFFFDF5E6),
    Color(0xFFF1E2C2),
    Color(0xFFF8E5BE),
    Color(0xFFB7791F),
  );
  static const lavender = _KpiTone(
    Color(0xFFF3F0FC),
    Color(0xFFE2DCF5),
    Color(0xFFE3DDF7),
    Color(0xFF6B5CA5),
  );
  static const sky = _KpiTone(
    Color(0xFFEDF5FC),
    Color(0xFFD6E7F5),
    Color(0xFFD6E8F7),
    Color(0xFF3F7CAC),
  );
}

class _KpiGrid extends ConsumerWidget {
  const _KpiGrid({required this.summary, required this.width});

  final DashboardSummary summary;
  final double width;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final week = ref
        .watch(analyticsReportProvider(AnalyticsRange.preset('7d')))
        .value;
    final cards = [
      _KpiCard(
        tone: _KpiTone.sage,
        icon: Icons.mail_outline,
        value: summary.newEnquiries,
        label: 'New enquiries',
        note: '${summary.enquiriesLast7Days} in the last 7 days',
        route: '/enquiries?status=new',
      ),
      _KpiCard(
        tone: _KpiTone.beige,
        icon: Icons.calendar_today_outlined,
        value: summary.requestedSiteVisits,
        label: 'Site visits to confirm',
        note: '${summary.siteVisitsNext7Days} confirmed in the next 7 days',
        route: '/site-visits?status=requested&when=all',
      ),
      _KpiCard(
        tone: _KpiTone.lavender,
        icon: Icons.sell_outlined,
        value: summary.bookingsToReview,
        label: 'Bookings to review',
        note: '${summary.bookingsInProgress} approved, in progress',
        route: '/bookings',
      ),
      _KpiCard(
        tone: _KpiTone.sky,
        icon: Icons.groups_outlined,
        value: summary.visitorsLast7Days,
        label: 'Website visitors',
        note: 'Last 7 days',
        route: '/analytics?range=7d',
        chart: week == null || week.daily.isEmpty
            ? null
            : CustomPaint(
                size: const Size(72, 40),
                painter: MiniBarsPainter([
                  for (final day in week.daily) day.visitors,
                ], _KpiTone.sky.ink),
              ),
      ),
    ];
    final columns = width >= 1000 ? 4 : (width >= 560 ? 2 : 1);
    const gap = 20.0;
    final cardWidth = (width - gap * (columns - 1)) / columns;
    return Wrap(
      spacing: gap,
      runSpacing: gap,
      children: [
        for (final card in cards) SizedBox(width: cardWidth, child: card),
      ],
    );
  }
}

class _KpiCard extends StatefulWidget {
  const _KpiCard({
    required this.tone,
    required this.icon,
    required this.value,
    required this.label,
    required this.note,
    required this.route,
    this.chart,
  });

  final _KpiTone tone;
  final IconData icon;
  final int value;
  final String label;
  final String note;
  final String route;
  final Widget? chart;

  @override
  State<_KpiCard> createState() => _KpiCardState();
}

class _KpiCardState extends State<_KpiCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final tone = widget.tone;
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOut,
        transform: Matrix4.translationValues(0, _hover ? -2 : 0, 0),
        decoration: BoxDecoration(
          color: tone.background,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: _hover ? tone.ink.withValues(alpha: 0.35) : tone.border,
          ),
          boxShadow: [
            BoxShadow(
              color: _Tone.text.withValues(alpha: _hover ? 0.09 : 0.035),
              blurRadius: _hover ? 22 : 12,
              offset: Offset(0, _hover ? 10 : 4),
            ),
          ],
        ),
        child: Material(
          type: MaterialType.transparency,
          borderRadius: BorderRadius.circular(20),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => context.go(widget.route),
            child: Stack(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                  child: Row(
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: tone.iconBackground,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(widget.icon, size: 24, color: tone.ink),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${widget.value}',
                              style: const TextStyle(
                                color: _Tone.text,
                                fontSize: 32,
                                fontWeight: FontWeight.w700,
                                height: 1.1,
                                letterSpacing: -0.5,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              widget.label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: _Tone.text,
                                fontSize: 14.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              widget.note,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: _Tone.muted,
                                fontSize: 12.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (widget.chart != null) ...[
                        const SizedBox(width: 8),
                        Padding(
                          padding: const EdgeInsets.only(top: 24),
                          child: widget.chart,
                        ),
                      ],
                    ],
                  ),
                ),
                if (widget.chart == null)
                  Positioned(
                    top: 16,
                    right: 16,
                    child: Icon(
                      Icons.arrow_outward,
                      size: 18,
                      color: tone.ink.withValues(alpha: _hover ? 1 : 0.7),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- Panels

/// White card with an icon, a title and an optional link on the right.
class _Panel extends StatelessWidget {
  const _Panel({
    required this.icon,
    required this.title,
    required this.child,
    this.trailing,
    this.height,
  });

  final IconData icon;
  final String title;
  final Widget child;
  final Widget? trailing;
  final double? height;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      padding: const EdgeInsets.fromLTRB(24, 18, 24, 22),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 40,
            child: Row(
              children: [
                Icon(icon, size: 22, color: BrandColors.forest),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      color: _Tone.text,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.2,
                    ),
                  ),
                ),
                ?trailing,
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (height != null) Expanded(child: child) else child,
        ],
      ),
    );
  }
}

class _ViewAll extends StatelessWidget {
  const _ViewAll(this.label, this.route);

  final String label;
  final String route;

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: () => context.go(route),
      style: TextButton.styleFrom(
        foregroundColor: BrandColors.forest,
        textStyle: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
      ),
      icon: const Icon(Icons.arrow_forward, size: 16),
      iconAlignment: IconAlignment.end,
      label: Text(label),
    );
  }
}

class _InventoryPanel extends StatelessWidget {
  const _InventoryPanel({required this.summary, this.height});

  final DashboardSummary summary;
  final double? height;

  @override
  Widget build(BuildContext context) {
    final parts = [
      (
        'Available',
        summary.available,
        BrandColors.available,
        '/properties?availability=available&state=published',
      ),
      (
        'Reserved',
        summary.reserved,
        _Tone.reserved,
        '/properties?availability=reserved',
      ),
      ('Sold', summary.sold, _Tone.sold, '/properties?availability=sold'),
      ('Drafts', summary.draft, _Tone.draft, '/properties?state=draft'),
    ];
    final sum = parts.fold<int>(0, (total, part) => total + part.$2);
    final donut = SizedBox.square(
      dimension: 184,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: const Size.square(184),
            painter: DonutPainter([
              for (final part in parts) (part.$2, part.$3),
            ]),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${summary.total}',
                style: const TextStyle(
                  color: _Tone.text,
                  fontSize: 36,
                  fontWeight: FontWeight.w700,
                  height: 1.05,
                  letterSpacing: -0.6,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Properties\nin total',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _Tone.muted,
                  fontSize: 12.5,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ],
      ),
    );
    final legend = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < parts.length; i++) ...[
          _LegendRow(
            label: parts[i].$1,
            value: parts[i].$2,
            color: parts[i].$3,
            route: parts[i].$4,
            percent: sum == 0 ? 0 : (parts[i].$2 * 100 / sum).round(),
          ),
          if (i < parts.length - 1)
            Divider(height: 1, color: BrandColors.line.withValues(alpha: 0.7)),
        ],
      ],
    );
    return _Panel(
      icon: Icons.layers_outlined,
      title: 'Land Inventory',
      trailing: const _ViewAll('All properties', '/properties'),
      height: height,
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 440) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 8),
                Center(child: donut),
                const SizedBox(height: 20),
                legend,
              ],
            );
          }
          return Center(
            child: Row(
              children: [
                const SizedBox(width: 4),
                donut,
                const SizedBox(width: 36),
                Expanded(child: legend),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _LegendRow extends StatelessWidget {
  const _LegendRow({
    required this.label,
    required this.value,
    required this.color,
    required this.route,
    required this.percent,
  });

  final String label;
  final int value;
  final Color color;
  final String route;
  final int percent;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => context.go(route),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
        child: Row(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  color: _Tone.text,
                  fontSize: 14.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Text(
              '$percent%',
              style: const TextStyle(color: _Tone.muted, fontSize: 13),
            ),
            SizedBox(
              width: 48,
              child: Text(
                '$value',
                textAlign: TextAlign.end,
                style: const TextStyle(
                  color: _Tone.text,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VisitorsPanel extends ConsumerStatefulWidget {
  const _VisitorsPanel({this.height});

  final double? height;

  @override
  ConsumerState<_VisitorsPanel> createState() => _VisitorsPanelState();
}

class _VisitorsPanelState extends ConsumerState<_VisitorsPanel> {
  String _preset = '7d';

  @override
  Widget build(BuildContext context) {
    final range = AnalyticsRange.preset(_preset);
    final report = ref.watch(analyticsReportProvider(range));
    return _Panel(
      icon: Icons.bar_chart_rounded,
      title: 'Sales & Visitors',
      height: widget.height,
      trailing: Container(
        height: 36,
        padding: const EdgeInsets.only(left: 12, right: 6),
        decoration: BoxDecoration(
          border: Border.all(color: BrandColors.line),
          borderRadius: BorderRadius.circular(10),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: _preset,
            isDense: true,
            borderRadius: BorderRadius.circular(10),
            icon: const Icon(Icons.expand_more, size: 18),
            style: const TextStyle(color: _Tone.text, fontSize: 13),
            items: [
              for (final preset in const ['7d', '30d', '90d'])
                DropdownMenuItem(
                  value: preset,
                  child: Text(AnalyticsRange.presets[preset]!),
                ),
            ],
            onChanged: (value) {
              if (value != null) setState(() => _preset = value);
            },
          ),
        ),
      ),
      child: AsyncValueView(
        value: report,
        onRetry: () => ref.invalidate(analyticsReportProvider(range)),
        data: (report) => LayoutBuilder(
          builder: (context, constraints) {
            final chartHeight = constraints.maxHeight.isFinite
                ? constraints.maxHeight
                : 230.0;
            final chart = SizedBox(
              height: chartHeight,
              child: CustomPaint(
                size: Size.infinite,
                painter: LineChartPainter(
                  days: [for (final day in report.daily) day.day],
                  values: [for (final day in report.daily) day.visitors],
                  labelStyle: const TextStyle(
                    color: _Tone.muted,
                    fontSize: 11.5,
                  ),
                ),
              ),
            );
            final total = _VisitorTotal(report: report);
            if (constraints.maxWidth < 560) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [chart, const SizedBox(height: 16), total],
              );
            }
            return SizedBox(
              height: chartHeight,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: chart),
                  const SizedBox(width: 20),
                  SizedBox(width: 184, child: total),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _VisitorTotal extends StatelessWidget {
  const _VisitorTotal({required this.report});

  final AnalyticsReport report;

  @override
  Widget build(BuildContext context) {
    final now = report.totals['visitors'];
    final before = report.previous['visitors'];
    final change = formatChange(now, before);
    final up = now > before;
    final signed = change.startsWith('+') || change.startsWith('−');
    final color = !signed
        ? _Tone.muted
        : (up ? BrandColors.available : BrandColors.danger);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFF2F8F4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _Tone.sage),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            NumberFormat.decimalPattern('en_IN').format(now),
            style: const TextStyle(
              color: _Tone.text,
              fontSize: 32,
              fontWeight: FontWeight.w700,
              height: 1.1,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Total visitors',
            style: TextStyle(color: _Tone.muted, fontSize: 13.5),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              if (signed) ...[
                Icon(
                  up ? Icons.arrow_upward : Icons.arrow_downward,
                  size: 18,
                  color: color,
                ),
                const SizedBox(width: 4),
              ],
              Flexible(
                child: Text(
                  signed ? change.substring(1) : change,
                  style: TextStyle(
                    color: color,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            'vs ${report.range.previousLabel}',
            style: const TextStyle(color: _Tone.muted, fontSize: 12.5),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- Lists

class _LatestEnquiries extends ConsumerWidget {
  const _LatestEnquiries();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(dashboardSummaryProvider).value;
    return _Panel(
      icon: Icons.mail_outline,
      title: 'Latest Enquiries',
      trailing: const _ViewAll('View all', '/enquiries'),
      child: AsyncValueView(
        value: ref.watch(latestEnquiriesProvider),
        onRetry: () => ref.invalidate(latestEnquiriesProvider),
        data: (enquiries) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (summary != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  'Website taps in the last 7 days · '
                  '${summary.whatsappTapsLast7Days} WhatsApp · '
                  '${summary.callTapsLast7Days} call',
                  style: const TextStyle(color: _Tone.muted, fontSize: 12.5),
                ),
              ),
            if (enquiries.isEmpty)
              const EmptyState(message: 'No enquiries yet.')
            else
              for (final enquiry in enquiries) ...[
                _EnquiryRow(enquiry: enquiry),
                if (enquiry != enquiries.last)
                  Divider(
                    height: 1,
                    color: BrandColors.line.withValues(alpha: 0.7),
                  ),
              ],
          ],
        ),
      ),
    );
  }
}

class _EnquiryRow extends StatelessWidget {
  const _EnquiryRow({required this.enquiry});

  final EnquiryPreview enquiry;

  @override
  Widget build(BuildContext context) {
    final name = enquiry.name.trim();
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () => context.go('/enquiries/${enquiry.id}'),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        child: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: _Tone.sage,
              child: Text(
                name.isEmpty ? '?' : name[0].toUpperCase(),
                style: const TextStyle(
                  color: BrandColors.forest,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    enquiry.name,
                    style: const TextStyle(
                      color: _Tone.text,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    [
                      enquiry.reference,
                      enquiry.propertyCode ?? 'General enquiry',
                      formatRelative(enquiry.createdAt),
                    ].join(' · '),
                    style: const TextStyle(color: _Tone.muted, fontSize: 12.5),
                  ),
                ],
              ),
            ),
            EnquiryStatusPill(status: EnquiryStatus.parse(enquiry.status)),
          ],
        ),
      ),
    );
  }
}

class _RecentActivity extends ConsumerWidget {
  const _RecentActivity();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final names = ref.watch(adminNamesProvider);
    return _Panel(
      icon: Icons.schedule,
      title: 'Recent Activity',
      trailing: const _ViewAll('View all', '/activity'),
      child: AsyncValueView(
        value: ref.watch(recentActivityProvider),
        onRetry: () => ref.invalidate(recentActivityProvider),
        data: (feed) {
          if (feed.entries.isEmpty) {
            return const EmptyState(message: 'Nothing has happened yet.');
          }
          final entries = feed.entries.take(5).toList();
          return Column(
            children: [
              for (var i = 0; i < entries.length; i++)
                _TimelineEntry(
                  entry: entries[i],
                  actorName: actorLabel(entries[i].actorId, names),
                  propertyCode: feed.propertyCodes[entries[i].propertyId],
                  first: i == 0,
                  last: i == entries.length - 1,
                ),
            ],
          );
        },
      ),
    );
  }
}

class _TimelineEntry extends StatelessWidget {
  const _TimelineEntry({
    required this.entry,
    required this.actorName,
    required this.propertyCode,
    required this.first,
    required this.last,
  });

  final AuditEntry entry;
  final String actorName;
  final String? propertyCode;
  final bool first;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final line = BrandColors.line;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 12,
            child: Column(
              children: [
                Container(
                  width: 2,
                  height: 21,
                  color: first ? Colors.transparent : line,
                ),
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: BrandColors.available,
                    shape: BoxShape.circle,
                    border: Border.all(color: _Tone.sage, width: 2),
                  ),
                ),
                Expanded(
                  child: Container(
                    width: 2,
                    color: last ? Colors.transparent : line,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Container(
              width: 36,
              height: 36,
              decoration: const BoxDecoration(
                color: Color(0xFFEFF6F1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                activityIcon(entry.entityType),
                size: 18,
                color: BrandColors.forest,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    describeActivity(entry, propertyCode: propertyCode),
                    style: const TextStyle(
                      color: _Tone.text,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Tooltip(
                    message: formatDateTime(entry.createdAt),
                    child: Text(
                      '$actorName · ${formatRelative(entry.createdAt)}',
                      style: const TextStyle(color: _Tone.muted, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
