import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/browser.dart';
import '../../core/errors.dart';
import '../../core/formatting.dart';
import '../../core/theme.dart';
import '../../core/widgets/common.dart';
import '../admins/admins_repository.dart';
import 'enquiries_repository.dart';
import 'enquiry_models.dart';

/// All enquiries with search, filters, paging and CSV export.
/// The filters live in the address (e.g. /enquiries?status=new).
class EnquiriesPage extends ConsumerStatefulWidget {
  const EnquiriesPage({super.key, required this.query});

  final EnquiryQuery query;

  @override
  ConsumerState<EnquiriesPage> createState() => _EnquiriesPageState();
}

class _EnquiriesPageState extends ConsumerState<EnquiriesPage> {
  bool _exporting = false;
  String _alerts = notificationPermission();

  void _go(EnquiryQuery next) => context.go(next.location);

  Future<void> _export() async {
    setState(() => _exporting = true);
    try {
      final enquiries = await ref
          .read(enquiriesRepositoryProvider)
          .exportAll(widget.query);
      // Names for the "Assigned to" column.
      await ref.read(adminUsersProvider.future);
      final names = ref.read(adminNamesProvider);
      final date = DateFormat('yyyy-MM-dd').format(DateTime.now());
      downloadText(
        'enquiries-$date.csv',
        toCsv(enquiryCsvRows(enquiries, names)),
      );
      if (mounted) {
        showMessage(
          context,
          'Exported ${enquiries.length} ${enquiries.length == 1 ? 'enquiry' : 'enquiries'}.',
        );
      }
    } catch (error) {
      if (mounted) showMessage(context, friendlyError(error), error: true);
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _turnOnAlerts() async {
    final result = await requestNotificationPermission();
    if (!mounted) return;
    setState(() => _alerts = result);
    if (result == 'denied') {
      showMessage(
        context,
        'Alerts are blocked. Allow notifications for this site in the browser settings.',
        error: true,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final query = widget.query;
    final page = ref.watch(enquiryPageProvider(query));
    final wide = MediaQuery.sizeOf(context).width >= 1000;
    final total = page.value?.total;

    return PageBody(
      maxWidth: 1400,
      children: [
        PageHeader(
          title: 'Enquiries',
          subtitle: total == null
              ? 'Messages from the website.'
              : '$total ${total == 1 ? 'enquiry' : 'enquiries'} match.',
          actions: [
            if (_alerts == 'default')
              OutlinedButton.icon(
                onPressed: _turnOnAlerts,
                icon: const Icon(Icons.notifications_active_outlined, size: 18),
                label: const Text('Turn on desktop alerts'),
              ),
            OutlinedButton.icon(
              onPressed: _exporting || total == 0 ? null : _export,
              icon: _exporting
                  ? const SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.download, size: 18),
              label: const Text('Export CSV'),
            ),
          ],
        ),
        _Filters(
          query: query,
          propertyCode: page.value?.items.firstOrNull?.property?.code,
          onChanged: _go,
        ),
        const SizedBox(height: 16),
        Card(
          clipBehavior: Clip.antiAlias,
          child: AsyncValueView(
            value: page,
            onRetry: () => ref.invalidate(enquiryPageProvider(query)),
            data: (result) {
              if (result.items.isEmpty) {
                return EmptyState(
                  icon: Icons.mail_outline,
                  message: query.hasFilters
                      ? 'No enquiries match these filters.'
                      : 'No enquiries yet. They appear here as soon as a visitor sends one.',
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (wide)
                    _Table(items: result.items)
                  else
                    _Cards(items: result.items),
                  _Pager(
                    query: query,
                    total: result.total,
                    onPage: (p) => _go(query.copyWith(page: p)),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

class _Filters extends StatefulWidget {
  const _Filters({
    required this.query,
    required this.propertyCode,
    required this.onChanged,
  });

  final EnquiryQuery query;
  final String? propertyCode;
  final ValueChanged<EnquiryQuery> onChanged;

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
    Widget box(double width, Widget child) =>
        SizedBox(width: width, child: child);

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        box(
          300,
          TextField(
            controller: _search,
            decoration: InputDecoration(
              labelText: 'Search name, phone, ENQ- or AL- code',
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
        box(
          180,
          DropdownButtonFormField<EnquiryStatus?>(
            key: ValueKey('status-${query.status}'),
            initialValue: query.status,
            decoration: const InputDecoration(labelText: 'Status'),
            items: [
              const DropdownMenuItem(value: null, child: Text('Any status')),
              for (final status in EnquiryStatus.values)
                DropdownMenuItem(value: status, child: Text(status.label)),
            ],
            onChanged: (value) =>
                widget.onChanged(query.copyWith(status: () => value)),
          ),
        ),
        box(
          180,
          DropdownButtonFormField<EnquiryRange>(
            key: ValueKey('range-${query.range}'),
            initialValue: query.range,
            decoration: const InputDecoration(labelText: 'Received'),
            items: [
              for (final range in EnquiryRange.values)
                DropdownMenuItem(value: range, child: Text(range.label)),
            ],
            onChanged: (value) =>
                widget.onChanged(query.copyWith(range: value)),
          ),
        ),
        box(
          190,
          DropdownButtonFormField<EnquiryAssignee>(
            key: ValueKey('assigned-${query.assignee}'),
            initialValue: query.assignee,
            decoration: const InputDecoration(labelText: 'Assigned'),
            items: [
              for (final item in EnquiryAssignee.values)
                DropdownMenuItem(value: item, child: Text(item.label)),
            ],
            onChanged: (value) =>
                widget.onChanged(query.copyWith(assignee: value)),
          ),
        ),
        if (query.propertyId != null)
          InputChip(
            label: Text('Property ${widget.propertyCode ?? ''}'.trim()),
            onDeleted: () =>
                widget.onChanged(query.copyWith(propertyId: () => null)),
          ),
        if (query.hasFilters)
          TextButton(
            onPressed: () => widget.onChanged(const EnquiryQuery()),
            child: const Text('Clear filters'),
          ),
      ],
    );
  }
}

/// Shown when the customer has an account on the website: they can see this
/// request's status in "My account" (in plain words, never staff notes).
class CustomerAccountPill extends StatelessWidget {
  const CustomerAccountPill({super.key});

  @override
  Widget build(BuildContext context) => const Tooltip(
    message: 'This customer has an account on the website and can see this request\'s status there (never your notes).',
    child: Pill(label: 'Has an account', color: BrandColors.forest),
  );
}

class EnquiryStatusPill extends StatelessWidget {
  const EnquiryStatusPill({super.key, required this.status});

  final EnquiryStatus status;

  @override
  Widget build(BuildContext context) =>
      Pill(label: status.label, color: status.color);
}

class _Table extends ConsumerWidget {
  const _Table({required this.items});

  final List<Enquiry> items;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final names = ref.watch(adminNamesProvider);
    final small = Theme.of(context).textTheme.bodySmall;
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: ConstrainedBox(
          constraints: BoxConstraints(minWidth: constraints.maxWidth),
          child: DataTable(
            showCheckboxColumn: false,
            columnSpacing: 24,
            horizontalMargin: 16,
            dataRowMinHeight: 60,
            dataRowMaxHeight: 68,
            columns: const [
              DataColumn(label: Text('Reference')),
              DataColumn(label: Text('Customer')),
              DataColumn(label: Text('Property')),
              DataColumn(label: Text('Status')),
              DataColumn(label: Text('Assigned')),
              DataColumn(label: Text('Received')),
            ],
            rows: [
              for (final item in items)
                DataRow(
                  onSelectChanged: (_) => context.go('/enquiries/${item.id}'),
                  cells: [
                    DataCell(
                      Text(
                        item.reference,
                        style: TextStyle(
                          fontWeight: item.status == EnquiryStatus.newEnquiry
                              ? FontWeight.w700
                              : FontWeight.w500,
                        ),
                      ),
                    ),
                    DataCell(
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(item.name),
                          Text(formatIndianMobile(item.phone), style: small),
                        ],
                      ),
                    ),
                    DataCell(
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 300),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(item.propertyLabel),
                            if (item.property != null)
                              Text(
                                item.property!.title,
                                style: small,
                                overflow: TextOverflow.ellipsis,
                              ),
                          ],
                        ),
                      ),
                    ),
                    DataCell(EnquiryStatusPill(status: item.status)),
                    DataCell(
                      Text(
                        item.assignedTo == null
                            ? '—'
                            : names[item.assignedTo] ?? 'Former admin',
                      ),
                    ),
                    DataCell(
                      Tooltip(
                        message: formatDateTime(item.createdAt),
                        child: Text(formatRelative(item.createdAt)),
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

class _Cards extends StatelessWidget {
  const _Cards({required this.items});

  final List<Enquiry> items;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      children: [
        for (final item in items)
          InkWell(
            onTap: () => context.go('/enquiries/${item.id}'),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: BrandColors.line)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item.name, style: textTheme.titleSmall),
                        Text(
                          '${item.reference} · ${item.propertyLabel}',
                          style: textTheme.bodySmall,
                        ),
                        const SizedBox(height: 4),
                        Text(formatIndianMobile(item.phone)),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      EnquiryStatusPill(status: item.status),
                      const SizedBox(height: 6),
                      Text(
                        formatRelative(item.createdAt),
                        style: textTheme.bodySmall,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _Pager extends StatelessWidget {
  const _Pager({
    required this.query,
    required this.total,
    required this.onPage,
  });

  final EnquiryQuery query;
  final int total;
  final ValueChanged<int> onPage;

  @override
  Widget build(BuildContext context) {
    const size = EnquiryQuery.pageSize;
    final pages = (total / size).ceil().clamp(1, 1 << 30);
    final from = (query.page - 1) * size + 1;
    final to = (query.page * size).clamp(0, total);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Text('$from–$to of $total'),
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
