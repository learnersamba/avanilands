import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/browser.dart';
import '../../core/widgets/common.dart';
import 'analytics_models.dart';
import 'analytics_report_view.dart';
import 'analytics_repository.dart';

/// Website visits and what came of them, for a chosen period.
class AnalyticsPage extends ConsumerWidget {
  const AnalyticsPage({super.key, required this.range});

  final AnalyticsRange range;

  Future<void> _pickDates(BuildContext context) async {
    final today = indiaToday();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime.utc(today.year - 2),
      lastDate: today,
      initialDateRange: DateTimeRange(start: range.from, end: range.to),
      helpText: 'Choose dates (up to a year)',
    );
    if (picked == null || !context.mounted) return;
    context.go(AnalyticsRange.custom(picked.start, picked.end).location);
  }

  void _export(BuildContext context, AnalyticsReport report, String kind) {
    final name = 'analytics-$kind-${range.fromIso}-to-${range.toIso}.csv';
    downloadText(
      name,
      kind == 'properties' ? propertiesCsv(report) : dailyCsv(report),
    );
    showMessage(context, 'Downloaded $name');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final report = ref.watch(analyticsReportProvider(range));
    return PageBody(
      children: [
        PageHeader(
          title: 'Analytics',
          subtitle:
              'Website visits and what came of them · ${range.dates} (India time)',
          actions: [
            OutlinedButton.icon(
              onPressed: () => ref.invalidate(analyticsReportProvider(range)),
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Refresh'),
            ),
            MenuAnchor(
              menuChildren: [
                MenuItemButton(
                  leadingIcon: const Icon(Icons.landscape_outlined),
                  onPressed: report.value == null
                      ? null
                      : () => _export(context, report.value!, 'properties'),
                  child: const Text('Per property'),
                ),
                MenuItemButton(
                  leadingIcon: const Icon(Icons.calendar_view_day_outlined),
                  onPressed: report.value == null
                      ? null
                      : () => _export(context, report.value!, 'daily'),
                  child: const Text('Per day'),
                ),
              ],
              builder: (context, controller, _) => FilledButton.icon(
                onPressed: () =>
                    controller.isOpen ? controller.close() : controller.open(),
                icon: const Icon(Icons.download, size: 18),
                label: const Text('Export CSV'),
              ),
            ),
          ],
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final preset in AnalyticsRange.presets.entries)
              ChoiceChip(
                label: Text(preset.value),
                selected: range.preset == preset.key,
                onSelected: (_) => context.go('/analytics?range=${preset.key}'),
              ),
            ChoiceChip(
              avatar: const Icon(Icons.date_range, size: 18),
              label: Text(
                range.preset == 'custom' ? range.dates : 'Choose dates…',
              ),
              selected: range.preset == 'custom',
              onSelected: (_) => _pickDates(context),
            ),
          ],
        ),
        const SizedBox(height: 20),
        AsyncValueView(
          value: report,
          onRetry: () => ref.invalidate(analyticsReportProvider(range)),
          data: (report) => AnalyticsReportView(report: report),
        ),
      ],
    );
  }
}
