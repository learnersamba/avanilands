import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/formatting.dart';
import '../../core/theme.dart';
import '../../core/widgets/common.dart';
import '../activity/activity_repository.dart';
import '../activity/activity_tile.dart';
import '../admins/admins_repository.dart';
import '../auth/auth_controller.dart';
import '../enquiries/enquiries_page.dart';
import '../enquiries/enquiry_models.dart';
import '../site_visits/site_visits_repository.dart';
import 'dashboard_repository.dart';

class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  void _refresh(WidgetRef ref) {
    ref
      ..invalidate(dashboardSummaryProvider)
      ..invalidate(latestEnquiriesProvider)
      ..invalidate(siteVisitPageProvider)
      ..invalidate(recentActivityProvider)
      ..invalidate(adminUsersProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final admin = ref.watch(currentAdminProvider);
    final firstName = admin.fullName.split(' ').first;
    final wide = MediaQuery.sizeOf(context).width >= 1100;
    final summary = ref.watch(dashboardSummaryProvider);

    final enquiries = _LatestEnquiries(
      onRetry: () => ref.invalidate(latestEnquiriesProvider),
    );
    final activity = _RecentActivity(
      onRetry: () => ref.invalidate(recentActivityProvider),
    );

    return PageBody(
      children: [
        _Hero(
          greeting: '${_greeting()}, $firstName',
          summary: summary.value,
          onRefresh: () => _refresh(ref),
        ),
        const SizedBox(height: 28),
        AsyncValueView(
          value: summary,
          onRetry: () => ref.invalidate(dashboardSummaryProvider),
          data: (summary) => _Stats(summary: summary),
        ),
        const SizedBox(height: 28),
        if (wide)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: enquiries),
              const SizedBox(width: 24),
              Expanded(child: activity),
            ],
          )
        else ...[
          enquiries,
          const SizedBox(height: 24),
          activity,
        ],
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

/// Green welcome banner: greeting, today's date and what needs doing now.
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
    final textTheme = Theme.of(context).textTheme;
    final narrow = MediaQuery.sizeOf(context).width < 600;
    final s = summary;
    final todo = <_Todo>[
      if (s != null && s.newEnquiries > 0)
        _Todo(
          Icons.mail_outline,
          '${s.newEnquiries} new ${s.newEnquiries == 1 ? 'enquiry' : 'enquiries'}',
          '/enquiries?status=new',
        ),
      if (s != null && s.requestedSiteVisits > 0)
        _Todo(
          Icons.event_available_outlined,
          '${s.requestedSiteVisits} ${s.requestedSiteVisits == 1 ? 'visit' : 'visits'} to confirm',
          '/site-visits?status=requested&when=all',
        ),
      if (s != null && s.bookingsToReview > 0)
        _Todo(
          Icons.key_outlined,
          '${s.bookingsToReview} ${s.bookingsToReview == 1 ? 'booking' : 'bookings'} to review',
          '/bookings',
        ),
    ];
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [BrandColors.forest, BrandColors.forestDark],
        ),
        boxShadow: [
          BoxShadow(
            color: BrandColors.forest.withValues(alpha: 0.18),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        children: [
          const Positioned(
            right: -60,
            top: -70,
            child: _Ring(size: 240, alpha: 0.07),
          ),
          const Positioned(
            right: 40,
            bottom: -90,
            child: _Ring(size: 180, alpha: 0.06),
          ),
          Padding(
            padding: EdgeInsets.all(narrow ? 20 : 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            DateFormat('EEEE, d MMMM y')
                                .format(DateTime.now())
                                .toUpperCase(),
                            style: textTheme.labelSmall?.copyWith(
                              color: BrandColors.sand,
                              letterSpacing: 1.6,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            greeting,
                            style: textTheme.headlineMedium?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "Here's how your land inventory looks today.",
                            style: textTheme.bodyMedium?.copyWith(
                              color: Colors.white.withValues(alpha: 0.78),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    OutlinedButton.icon(
                      onPressed: onRefresh,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: BorderSide(
                          color: Colors.white.withValues(alpha: 0.4),
                        ),
                      ),
                      icon: const Icon(Icons.refresh, size: 18),
                      label: const Text('Refresh'),
                    ),
                  ],
                ),
                if (s != null) ...[
                  const SizedBox(height: 20),
                  if (todo.isEmpty)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.check_circle,
                          size: 18,
                          color: BrandColors.sand,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          "You're all caught up. Nothing is waiting.",
                          style: textTheme.bodyMedium?.copyWith(
                            color: Colors.white.withValues(alpha: 0.9),
                          ),
                        ),
                      ],
                    )
                  else
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        for (final item in todo) _TodoChip(item: item),
                      ],
                    ),
                ],
              ],
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
  final String route;
}

class _TodoChip extends StatelessWidget {
  const _TodoChip({required this.item});

  final _Todo item;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.12),
      shape: StadiumBorder(
        side: BorderSide(color: Colors.white.withValues(alpha: 0.22)),
      ),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: () => context.go(item.route),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(item.icon, size: 16, color: BrandColors.sand),
              const SizedBox(width: 8),
              Text(
                item.label,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 6),
              Icon(
                Icons.arrow_forward,
                size: 14,
                color: Colors.white.withValues(alpha: 0.7),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Ring extends StatelessWidget {
  const _Ring({required this.size, required this.alpha});

  final double size;
  final double alpha;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: Colors.white.withValues(alpha: alpha * 2),
          width: 1.5,
        ),
        color: Colors.white.withValues(alpha: alpha),
      ),
    );
  }
}

class _Stats extends StatelessWidget {
  const _Stats({required this.summary});

  final DashboardSummary summary;

  @override
  Widget build(BuildContext context) {
    final inventory = [
      _StatCard(
        label: 'Total properties',
        value: summary.total,
        note: '${summary.published} live · ${summary.hidden} hidden',
        icon: Icons.landscape_outlined,
        color: BrandColors.forest,
        onTap: () => context.go('/properties'),
      ),
      _StatCard(
        label: 'Available',
        value: summary.available,
        note: 'Live on the website',
        icon: Icons.check_circle_outline,
        color: BrandColors.available,
        onTap: () =>
            context.go('/properties?availability=available&state=published'),
      ),
      _StatCard(
        label: 'Reserved',
        value: summary.reserved,
        note: 'Booking in progress',
        icon: Icons.bookmark_border,
        color: BrandColors.reserved,
        onTap: () => context.go('/properties?availability=reserved'),
      ),
      _StatCard(
        label: 'Sold',
        value: summary.sold,
        note: 'Not counting archived',
        icon: Icons.verified_outlined,
        color: BrandColors.sold,
        onTap: () => context.go('/properties?availability=sold'),
      ),
      _StatCard(
        label: 'Drafts',
        value: summary.draft,
        note: 'Not yet published',
        icon: Icons.edit_note,
        color: BrandColors.sand,
        onTap: () => context.go('/properties?state=draft'),
      ),
    ];
    final activity = [
      _StatCard(
        label: 'New enquiries',
        value: summary.newEnquiries,
        note: '${summary.enquiriesLast7Days} in the last 7 days',
        icon: Icons.mail_outline,
        color: BrandColors.forest,
        onTap: () => context.go('/enquiries?status=new'),
      ),
      _StatCard(
        label: 'Site visits to confirm',
        value: summary.requestedSiteVisits,
        note: '${summary.siteVisitsNext7Days} confirmed in the next 7 days',
        icon: Icons.event_available_outlined,
        color: BrandColors.reserved,
        onTap: () => context.go('/site-visits?status=requested&when=all'),
      ),
      _StatCard(
        label: 'Bookings to review',
        value: summary.bookingsToReview,
        note: '${summary.bookingsInProgress} approved, in progress',
        icon: Icons.key_outlined,
        color: BrandColors.reserved,
        onTap: () => context.go('/bookings'),
      ),
      _StatCard(
        label: 'Website visitors',
        value: summary.visitorsLast7Days,
        note: 'Last 7 days · see Analytics',
        icon: Icons.insights_outlined,
        color: BrandColors.forest,
        onTap: () => context.go('/analytics?range=7d'),
      ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _GroupLabel('Land inventory'),
        _CardGrid(maxColumns: 5, cards: inventory),
        const SizedBox(height: 28),
        const _GroupLabel('Sales and visitors'),
        _CardGrid(maxColumns: 4, cards: activity),
      ],
    );
  }
}

class _GroupLabel extends StatelessWidget {
  const _GroupLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 16,
            decoration: BoxDecoration(
              color: BrandColors.sand,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            text.toUpperCase(),
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: BrandColors.sold,
              letterSpacing: 1.4,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _CardGrid extends StatelessWidget {
  const _CardGrid({required this.maxColumns, required this.cards});

  final int maxColumns;
  final List<Widget> cards;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final columns = width >= 1000
            ? maxColumns
            : (width >= 640 ? (maxColumns > 4 ? 3 : 2) : 2);
        const gap = 16.0;
        final cardWidth = (width - gap * (columns - 1)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final card in cards) SizedBox(width: cardWidth, child: card),
          ],
        );
      },
    );
  }
}

class _StatCard extends StatefulWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.note,
    required this.icon,
    required this.color,
    this.onTap,
  });

  final String label;
  final int value;
  final String note;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  @override
  State<_StatCard> createState() => _StatCardState();
}

class _StatCardState extends State<_StatCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final tappable = widget.onTap != null;
    final lifted = _hover && tappable;
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      cursor: tappable ? SystemMouseCursors.click : MouseCursor.defer,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOut,
        transform: Matrix4.translationValues(0, lifted ? -3 : 0, 0),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: lifted
                ? widget.color.withValues(alpha: 0.45)
                : BrandColors.line,
          ),
          boxShadow: [
            BoxShadow(
              color: BrandColors.ink.withValues(alpha: lifted ? 0.10 : 0.03),
              blurRadius: lifted ? 20 : 8,
              offset: Offset(0, lifted ? 10 : 2),
            ),
          ],
        ),
        child: Material(
          type: MaterialType.transparency,
          borderRadius: BorderRadius.circular(16),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: widget.onTap,
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: widget.color.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(11),
                        ),
                        child: Icon(widget.icon, size: 20, color: widget.color),
                      ),
                      const Spacer(),
                      if (tappable)
                        Icon(
                          Icons.arrow_outward,
                          size: 16,
                          color: lifted ? widget.color : BrandColors.line,
                        ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text(
                    '${widget.value}',
                    style: textTheme.headlineLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: BrandColors.ink,
                      height: 1.05,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    widget.label,
                    style: textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: BrandColors.ink,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    widget.note,
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
      ),
    );
  }
}

class _LatestEnquiries extends ConsumerWidget {
  const _LatestEnquiries({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SectionCard(
      title: 'Latest enquiries',
      trailing: TextButton(
        onPressed: () => context.go('/enquiries'),
        child: const Text('View all'),
      ),
      child: AsyncValueView(
        value: ref.watch(latestEnquiriesProvider),
        onRetry: onRetry,
        data: (enquiries) {
          if (enquiries.isEmpty) {
            return const EmptyState(message: 'No enquiries yet.');
          }
          final summary = ref.watch(dashboardSummaryProvider).value;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (summary != null)
                Text(
                  'Website taps in the last 7 days: '
                  '${summary.whatsappTapsLast7Days} WhatsApp · '
                  '${summary.callTapsLast7Days} call',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              for (final enquiry in enquiries) ...[
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  onTap: () => context.go('/enquiries/${enquiry.id}'),
                  title: Text(enquiry.name),
                  subtitle: Text(
                    [
                      enquiry.reference,
                      enquiry.propertyCode ?? 'General enquiry',
                      formatRelative(enquiry.createdAt),
                    ].join(' · '),
                  ),
                  trailing: EnquiryStatusPill(
                    status: EnquiryStatus.parse(enquiry.status),
                  ),
                ),
                if (enquiry != enquiries.last) const Divider(height: 1),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _RecentActivity extends ConsumerWidget {
  const _RecentActivity({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final names = ref.watch(adminNamesProvider);
    return SectionCard(
      title: 'Recent activity',
      trailing: TextButton(
        onPressed: () => context.go('/activity'),
        child: const Text('View all'),
      ),
      child: AsyncValueView(
        value: ref.watch(recentActivityProvider),
        onRetry: onRetry,
        data: (feed) {
          if (feed.entries.isEmpty) {
            return const EmptyState(message: 'Nothing has happened yet.');
          }
          return Column(
            children: [
              for (final entry in feed.entries)
                ActivityTile(
                  entry: entry,
                  actorName: actorLabel(entry.actorId, names),
                  propertyCode: feed.propertyCodes[entry.propertyId],
                ),
            ],
          );
        },
      ),
    );
  }
}
