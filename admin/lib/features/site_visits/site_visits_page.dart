import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/theme.dart';
import '../../core/widgets/common.dart';
import '../admins/admins_repository.dart';
import 'site_visit_models.dart';
import 'site_visits_repository.dart';

/// Site visits: a list (upcoming first) with filters in the address, and a
/// month calendar; tap a day to list that day's visits.
class SiteVisitsPage extends ConsumerWidget {
  const SiteVisitsPage({super.key, required this.query});

  final SiteVisitQuery query;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    void go(SiteVisitQuery next) => context.go(next.location);
    final page = ref.watch(siteVisitPageProvider(query));
    final total = page.value?.total;
    final wide = MediaQuery.sizeOf(context).width >= 1200;

    final list = Card(
      clipBehavior: Clip.antiAlias,
      child: AsyncValueView(
        value: page,
        onRetry: () => ref.invalidate(siteVisitPageProvider(query)),
        data: (result) {
          if (result.items.isEmpty) {
            return EmptyState(
              icon: Icons.event_available_outlined,
              message: query.hasFilters
                  ? 'No site visits match these filters.'
                  : 'No upcoming site visits. Requests from the website appear here straight away.',
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final visit in result.items) SiteVisitRow(visit: visit),
              _Pager(
                query: query,
                total: result.total,
                onPage: (p) => go(query.copyWith(page: p)),
              ),
            ],
          );
        },
      ),
    );
    final calendar = _MonthCalendar(
      selected: query.date,
      onDay: (day) =>
          go(query.copyWith(date: () => day == query.date ? null : day)),
    );

    return PageBody(
      maxWidth: 1400,
      children: [
        PageHeader(
          title: 'Site visits',
          subtitle: total == null
              ? 'Visits customers asked for on the website.'
              : query.date != null
              ? '$total on ${formatVisitDay(query.date!)}.'
              : '$total ${total == 1 ? 'visit' : 'visits'} match.',
        ),
        _Filters(query: query, onChanged: go),
        const SizedBox(height: 16),
        if (wide)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 3, child: list),
              const SizedBox(width: 24),
              SizedBox(width: 380, child: calendar),
            ],
          )
        else ...[
          calendar,
          const SizedBox(height: 16),
          list,
        ],
      ],
    );
  }
}

class _Filters extends StatefulWidget {
  const _Filters({required this.query, required this.onChanged});

  final SiteVisitQuery query;
  final ValueChanged<SiteVisitQuery> onChanged;

  @override
  State<_Filters> createState() => _FiltersState();
}

class _FiltersState extends State<_Filters> {
  late final _search = TextEditingController(text: widget.query.search);

  @override
  void didUpdateWidget(covariant _Filters oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.query.search != _search.text) _search.text = widget.query.search;
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = widget.query;
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SizedBox(
          width: 300,
          child: TextField(
            controller: _search,
            decoration: InputDecoration(
              labelText: 'Search name, phone, SV- or AL- code',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _search.text.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Clear',
                      icon: const Icon(Icons.close),
                      onPressed: () =>
                          widget.onChanged(query.copyWith(search: '')),
                    ),
            ),
            onSubmitted: (value) =>
                widget.onChanged(query.copyWith(search: value.trim())),
          ),
        ),
        SizedBox(
          width: 180,
          child: DropdownButtonFormField<SiteVisitStatus?>(
            key: ValueKey('status-${query.status}'),
            initialValue: query.status,
            decoration: const InputDecoration(labelText: 'Status'),
            items: [
              const DropdownMenuItem(value: null, child: Text('Any status')),
              for (final status in SiteVisitStatus.values)
                DropdownMenuItem(value: status, child: Text(status.label)),
            ],
            onChanged: (value) =>
                widget.onChanged(query.copyWith(status: () => value)),
          ),
        ),
        if (query.date == null)
          SizedBox(
            width: 190,
            child: DropdownButtonFormField<SiteVisitWhen>(
              key: ValueKey('when-${query.when}'),
              initialValue: query.when,
              decoration: const InputDecoration(labelText: 'When'),
              items: [
                for (final item in SiteVisitWhen.values)
                  DropdownMenuItem(value: item, child: Text(item.label)),
              ],
              onChanged: (value) =>
                  widget.onChanged(query.copyWith(when: value)),
            ),
          )
        else
          InputChip(
            label: Text(formatVisitDay(query.date!)),
            onDeleted: () => widget.onChanged(query.copyWith(date: () => null)),
          ),
        FilterChip(
          label: const Text('Assigned to me'),
          selected: query.mine,
          onSelected: (value) => widget.onChanged(query.copyWith(mine: value)),
        ),
        if (query.propertyId != null)
          InputChip(
            label: const Text('This property'),
            onDeleted: () =>
                widget.onChanged(query.copyWith(propertyId: () => null)),
          ),
        if (query.hasFilters)
          TextButton(
            onPressed: () => widget.onChanged(const SiteVisitQuery()),
            child: const Text('Clear filters'),
          ),
      ],
    );
  }
}

class SiteVisitStatusPill extends StatelessWidget {
  const SiteVisitStatusPill({super.key, required this.status});

  final SiteVisitStatus status;

  @override
  Widget build(BuildContext context) =>
      Pill(label: status.label, color: status.color);
}

/// One visit: date block, customer, property, status.
class SiteVisitRow extends ConsumerWidget {
  const SiteVisitRow({super.key, required this.visit, this.dense = false});

  final SiteVisit visit;
  final bool dense;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final names = ref.watch(adminNamesProvider);
    final date = DateTime.parse(visit.visitDate);
    final today = indiaToday();
    final isToday = visit.visitDate == today;
    return InkWell(
      onTap: () => context.go('/site-visits/${visit.id}'),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: dense ? 0 : 16, vertical: 12),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: BrandColors.line)),
        ),
        child: Row(
          children: [
            Container(
              width: 64,
              padding: const EdgeInsets.symmetric(vertical: 6),
              decoration: BoxDecoration(
                color: isToday ? BrandColors.forest : BrandColors.paper,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                children: [
                  Text(
                    DateFormat('MMM').format(date).toUpperCase(),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isToday ? BrandColors.sand : BrandColors.sold,
                    ),
                  ),
                  Text(
                    '${date.day}',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: isToday ? Colors.white : BrandColors.ink,
                    ),
                  ),
                  Text(
                    formatVisitSlot(visit.slot),
                    style: TextStyle(
                      fontSize: 11,
                      color: isToday ? Colors.white : BrandColors.sold,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${visit.name} · ${visit.people}',
                    style: textTheme.titleSmall,
                  ),
                  Text(
                    '${visit.reference} · ${visit.phoneLabel}',
                    style: textTheme.bodySmall,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${visit.property.code} · ${visit.property.title}',
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                SiteVisitStatusPill(status: visit.status),
                if (visit.assignedTo != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    names[visit.assignedTo] ?? 'Former admin',
                    style: textTheme.bodySmall,
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MonthCalendar extends ConsumerStatefulWidget {
  const _MonthCalendar({required this.selected, required this.onDay});

  final String? selected;
  final ValueChanged<String> onDay;

  @override
  ConsumerState<_MonthCalendar> createState() => _MonthCalendarState();
}

class _MonthCalendarState extends ConsumerState<_MonthCalendar> {
  late (int, int) _month = _monthOf(widget.selected ?? indiaToday());

  static (int, int) _monthOf(String date) =>
      (int.parse(date.substring(0, 4)), int.parse(date.substring(5, 7)));

  void _shift(int months) {
    final next = DateTime.utc(_month.$1, _month.$2 + months);
    setState(() => _month = (next.year, next.month));
  }

  @override
  Widget build(BuildContext context) {
    final counts = ref.watch(siteVisitMonthProvider(_month)).value ?? const {};
    final today = indiaToday();
    final textTheme = Theme.of(context).textTheme;
    return SectionCard(
      title: DateFormat('MMMM y').format(DateTime(_month.$1, _month.$2)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: 'Previous month',
            onPressed: () => _shift(-1),
            icon: const Icon(Icons.chevron_left),
          ),
          IconButton(
            tooltip: 'Next month',
            onPressed: () => _shift(1),
            icon: const Icon(Icons.chevron_right),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              for (final name in weekdayNames.values)
                Expanded(
                  child: Center(child: Text(name, style: textTheme.bodySmall)),
                ),
            ],
          ),
          const SizedBox(height: 6),
          for (final week in monthGrid(_month.$1, _month.$2))
            Row(
              children: [
                for (final day in week)
                  Expanded(
                    child: day == null
                        ? const SizedBox(height: 48)
                        : _DayCell(
                            day: day,
                            counts: counts[day] ?? const {},
                            today: day == today,
                            selected: day == widget.selected,
                            onTap: () => widget.onDay(day),
                          ),
                  ),
              ],
            ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            children: [
              for (final status in [
                SiteVisitStatus.requested,
                SiteVisitStatus.confirmed,
                SiteVisitStatus.completed,
              ])
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: status.color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(status.label, style: textTheme.bodySmall),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.counts,
    required this.today,
    required this.selected,
    required this.onTap,
  });

  final String day;
  final Map<SiteVisitStatus, int> counts;
  final bool today;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final total = counts.values.fold(0, (sum, n) => sum + n);
    return Tooltip(
      message: total == 0
          ? formatVisitDay(day)
          : '${formatVisitDay(day)}: ${counts.entries.map((e) => '${e.value} ${e.key.label.toLowerCase()}').join(', ')}',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          height: 48,
          margin: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            color: selected ? BrandColors.forest : null,
            border: today && !selected
                ? Border.all(color: BrandColors.forest)
                : null,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '${int.parse(day.substring(8))}',
                style: TextStyle(
                  fontWeight: total > 0 ? FontWeight.w700 : FontWeight.w400,
                  color: selected ? Colors.white : BrandColors.ink,
                ),
              ),
              const SizedBox(height: 3),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (final status in SiteVisitStatus.values)
                    for (var i = 0; i < (counts[status] ?? 0).clamp(0, 3); i++)
                      Container(
                        width: 6,
                        height: 6,
                        margin: const EdgeInsets.symmetric(horizontal: 1),
                        decoration: BoxDecoration(
                          color: selected ? Colors.white : status.color,
                          shape: BoxShape.circle,
                        ),
                      ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Pager extends StatelessWidget {
  const _Pager({
    required this.query,
    required this.total,
    required this.onPage,
  });

  final SiteVisitQuery query;
  final int total;
  final ValueChanged<int> onPage;

  @override
  Widget build(BuildContext context) {
    const size = SiteVisitQuery.pageSize;
    final pages = (total / size).ceil().clamp(1, 1 << 30);
    if (pages == 1) return const SizedBox(height: 8);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Text('$total visits'),
          const Spacer(),
          IconButton(
            tooltip: 'Previous page',
            onPressed: query.page > 1 ? () => onPage(query.page - 1) : null,
            icon: const Icon(Icons.chevron_left),
          ),
          Text('Page ${query.page} of $pages'),
          IconButton(
            tooltip: 'Next page',
            onPressed: query.page < pages ? () => onPage(query.page + 1) : null,
            icon: const Icon(Icons.chevron_right),
          ),
        ],
      ),
    );
  }
}
