import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/formatting.dart';
import '../../core/theme.dart';
import '../../core/widgets/common.dart';
import '../admins/admins_repository.dart';
import 'booking_models.dart';
import 'bookings_repository.dart';

/// Bookings in progress (or all), newest first.
class BookingsPage extends ConsumerWidget {
  const BookingsPage({super.key, required this.query});

  final BookingQuery query;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    void go(BookingQuery next) => context.go(next.location);
    final page = ref.watch(bookingPageProvider(query));
    final total = page.value?.total;
    return PageBody(
      maxWidth: 1200,
      children: [
        PageHeader(
          title: 'Bookings',
          subtitle: total == null
              ? 'From request to registration.'
              : '$total ${total == 1 ? 'booking' : 'bookings'}${query.open && query.status == null ? ' in progress' : ''}.',
        ),
        _Filters(query: query, onChanged: go),
        const SizedBox(height: 16),
        Card(
          clipBehavior: Clip.antiAlias,
          child: AsyncValueView(
            value: page,
            onRetry: () => ref.invalidate(bookingPageProvider(query)),
            data: (result) => result.items.isEmpty
                ? EmptyState(
                    icon: Icons.key_outlined,
                    message: query.hasFilters
                        ? 'No bookings match these filters.'
                        : 'No bookings in progress. Customers request them on the website, or start one from a site visit.',
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final booking in result.items)
                        BookingRow(booking: booking),
                      if (result.total > BookingQuery.pageSize)
                        Padding(
                          padding: const EdgeInsets.all(8),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              IconButton(
                                tooltip: 'Previous page',
                                onPressed: query.page > 1
                                    ? () => go(
                                        query.copyWith(page: query.page - 1),
                                      )
                                    : null,
                                icon: const Icon(Icons.chevron_left),
                              ),
                              Text('Page ${query.page}'),
                              IconButton(
                                tooltip: 'Next page',
                                onPressed:
                                    query.page * BookingQuery.pageSize <
                                        result.total
                                    ? () => go(
                                        query.copyWith(page: query.page + 1),
                                      )
                                    : null,
                                icon: const Icon(Icons.chevron_right),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
          ),
        ),
      ],
    );
  }
}

class _Filters extends StatefulWidget {
  const _Filters({required this.query, required this.onChanged});

  final BookingQuery query;
  final ValueChanged<BookingQuery> onChanged;

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
            decoration: const InputDecoration(
              labelText: 'Search name, phone, BKG- or AL- code',
              prefixIcon: Icon(Icons.search),
            ),
            onSubmitted: (value) =>
                widget.onChanged(query.copyWith(search: value.trim())),
          ),
        ),
        SizedBox(
          width: 200,
          child: DropdownButtonFormField<BookingStatus?>(
            key: ValueKey('status-${query.status}'),
            initialValue: query.status,
            decoration: const InputDecoration(labelText: 'Step'),
            items: [
              const DropdownMenuItem(value: null, child: Text('Any step')),
              for (final status in BookingStatus.values)
                DropdownMenuItem(value: status, child: Text(status.label)),
            ],
            onChanged: (value) =>
                widget.onChanged(query.copyWith(status: () => value)),
          ),
        ),
        FilterChip(
          label: const Text('Include finished'),
          selected: !query.open,
          onSelected: (value) => widget.onChanged(query.copyWith(open: !value)),
        ),
        if (query.propertyId != null)
          InputChip(
            label: const Text('This property'),
            onDeleted: () =>
                widget.onChanged(query.copyWith(propertyId: () => null)),
          ),
        if (query.hasFilters)
          TextButton(
            onPressed: () => widget.onChanged(const BookingQuery()),
            child: const Text('Clear filters'),
          ),
      ],
    );
  }
}

class BookingStatusPill extends StatelessWidget {
  const BookingStatusPill({super.key, required this.status});

  final BookingStatus status;

  @override
  Widget build(BuildContext context) =>
      Pill(label: status.label, color: status.color);
}

class BookingRow extends ConsumerWidget {
  const BookingRow({super.key, required this.booking, this.dense = false});

  final Booking booking;
  final bool dense;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final names = ref.watch(adminNamesProvider);
    final money = [
      if (booking.agreedPrice != null)
        'Agreed ${formatRupees(booking.agreedPrice!)}',
      if (booking.amountReceived != null)
        'Received ${formatRupees(booking.amountReceived!)}'
      else if (booking.bookingAmount != null)
        'Booking amount ${formatRupees(booking.bookingAmount!)} due',
    ].join(' · ');
    return InkWell(
      onTap: () => context.go('/bookings/${booking.id}'),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: dense ? 0 : 16, vertical: 12),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: BrandColors.line)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${booking.reference} · ${booking.name}',
                    style: textTheme.titleSmall,
                  ),
                  Text(
                    '${booking.property.code} · ${booking.property.title}',
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    [
                      booking.phoneLabel,
                      if (money.isNotEmpty) money,
                      formatRelative(booking.createdAt),
                    ].join(' · '),
                    style: textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                BookingStatusPill(status: booking.status),
                if (booking.assignedTo != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    names[booking.assignedTo] ?? 'Former admin',
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
