import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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

    final enquiries = _LatestEnquiries(
      onRetry: () => ref.invalidate(latestEnquiriesProvider),
    );
    final activity = _RecentActivity(
      onRetry: () => ref.invalidate(recentActivityProvider),
    );

    return PageBody(
      children: [
        PageHeader(
          title: '${_greeting()}, $firstName',
          subtitle: "Here's how the land inventory looks today.",
          actions: [
            OutlinedButton.icon(
              onPressed: () => _refresh(ref),
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Refresh'),
            ),
          ],
        ),
        AsyncValueView(
          value: ref.watch(dashboardSummaryProvider),
          onRetry: () => ref.invalidate(dashboardSummaryProvider),
          data: (summary) => _StatGrid(summary: summary),
        ),
        const SizedBox(height: 24),
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

class _StatGrid extends StatelessWidget {
  const _StatGrid({required this.summary});

  final DashboardSummary summary;

  @override
  Widget build(BuildContext context) {
    final cards = [
      _StatCard(
        label: 'Total properties',
        value: summary.total,
        note: '${summary.published} live · ${summary.hidden} hidden',
        icon: Icons.landscape_outlined,
        color: BrandColors.forest,
      ),
      _StatCard(
        label: 'Available',
        value: summary.available,
        note: 'Live on the website',
        icon: Icons.check_circle_outline,
        color: BrandColors.available,
      ),
      _StatCard(
        label: 'Reserved',
        value: summary.reserved,
        note: 'Booking in progress',
        icon: Icons.bookmark_border,
        color: BrandColors.reserved,
      ),
      _StatCard(
        label: 'Sold',
        value: summary.sold,
        note: 'Not counting archived',
        icon: Icons.verified_outlined,
        color: BrandColors.sold,
      ),
      _StatCard(
        label: 'Drafts',
        value: summary.draft,
        note: 'Not yet published',
        icon: Icons.edit_note,
        color: BrandColors.sand,
      ),
      _StatCard(
        label: 'New enquiries',
        value: summary.newEnquiries,
        note: '${summary.enquiriesLast7Days} in the last 7 days',
        icon: Icons.mail_outline,
        color: BrandColors.forest,
        onTap: () => context.go('/enquiries'),
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
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 1100
            ? 4
            : (constraints.maxWidth >= 640 ? 4 : 2);
        const gap = 16.0;
        final cardWidth =
            (constraints.maxWidth - gap * (columns - 1)) / columns;
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

class _StatCard extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: color, width: 3)),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: Text(label, style: textTheme.bodyMedium)),
                  Icon(icon, size: 18, color: color),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '$value',
                style: textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: BrandColors.ink,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                note,
                style: textTheme.bodySmall?.copyWith(color: BrandColors.sold),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
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
