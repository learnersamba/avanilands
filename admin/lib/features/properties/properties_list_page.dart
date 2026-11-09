import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/browser.dart';
import '../../core/storage_urls.dart';
import '../../core/theme.dart';
import '../../core/widgets/common.dart';
import '../lookups/lookups_repository.dart';
import 'properties_repository.dart';
import 'property_actions.dart';
import 'property_enums.dart';
import 'property_models.dart';

/// All properties with search, filters, sorting and paging.
/// The filters live in the address (e.g. /properties?state=draft&page=2).
class PropertiesListPage extends ConsumerWidget {
  const PropertiesListPage({super.key, required this.query});

  final PropertyQuery query;

  void _go(BuildContext context, PropertyQuery next) => context.go(
    Uri(
      path: '/properties',
      queryParameters: next.toQueryParameters().isEmpty
          ? null
          : next.toQueryParameters(),
    ).toString(),
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final page = ref.watch(propertyPageProvider(query));
    final wide = MediaQuery.sizeOf(context).width >= 1000;
    final total = page.value?.total;

    return PageBody(
      maxWidth: 1400,
      children: [
        PageHeader(
          title: 'Properties',
          subtitle: total == null
              ? 'Your land inventory.'
              : '$total ${total == 1 ? 'property' : 'properties'} match.',
          actions: [
            FilledButton.icon(
              onPressed: () => context.go('/properties/new'),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add property'),
            ),
          ],
        ),
        _Filters(query: query, onChanged: (next) => _go(context, next)),
        const SizedBox(height: 16),
        Card(
          clipBehavior: Clip.antiAlias,
          child: AsyncValueView(
            value: page,
            onRetry: () => ref.invalidate(propertyPageProvider(query)),
            data: (result) {
              if (result.items.isEmpty) {
                return EmptyState(
                  icon: Icons.landscape_outlined,
                  message: query.hasFilters
                      ? 'No properties match these filters.'
                      : 'No properties yet. Use "Add property" to create the first one.',
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (wide)
                    _Table(items: result.items, query: query)
                  else
                    _Cards(items: result.items, query: query),
                  _Pager(
                    query: query,
                    total: result.total,
                    onPage: (p) => _go(context, query.copyWith(page: p)),
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

class _Filters extends ConsumerStatefulWidget {
  const _Filters({required this.query, required this.onChanged});

  final PropertyQuery query;
  final ValueChanged<PropertyQuery> onChanged;

  @override
  ConsumerState<_Filters> createState() => _FiltersState();
}

class _FiltersState extends ConsumerState<_Filters> {
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
    final types = ref.watch(propertyTypesProvider).value ?? const [];
    final locations = ref.watch(locationsProvider).value ?? const [];

    Widget box(double width, Widget child) =>
        SizedBox(width: width, child: child);

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        box(
          280,
          TextField(
            controller: _search,
            decoration: InputDecoration(
              labelText: 'Search code, title or locality',
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
          170,
          DropdownButtonFormField<PublishState?>(
            key: ValueKey('state-${query.state}'),
            initialValue: query.state,
            decoration: const InputDecoration(labelText: 'Status'),
            items: [
              const DropdownMenuItem(value: null, child: Text('Any status')),
              for (final state in PublishState.values)
                DropdownMenuItem(value: state, child: Text(state.label)),
            ],
            onChanged: (value) =>
                widget.onChanged(query.copyWith(state: () => value)),
          ),
        ),
        box(
          170,
          DropdownButtonFormField<Availability?>(
            key: ValueKey('availability-${query.availability}'),
            initialValue: query.availability,
            decoration: const InputDecoration(labelText: 'Availability'),
            items: [
              const DropdownMenuItem(value: null, child: Text('Any')),
              for (final item in Availability.values)
                DropdownMenuItem(value: item, child: Text(item.label)),
            ],
            onChanged: (value) =>
                widget.onChanged(query.copyWith(availability: () => value)),
          ),
        ),
        box(
          200,
          DropdownButtonFormField<int?>(
            key: ValueKey('type-${query.typeId}-${types.length}'),
            initialValue: types.any((t) => t.id == query.typeId)
                ? query.typeId
                : null,
            decoration: const InputDecoration(labelText: 'Type'),
            isExpanded: true,
            items: [
              const DropdownMenuItem(value: null, child: Text('Any type')),
              for (final type in types)
                DropdownMenuItem(value: type.id, child: Text(type.name)),
            ],
            onChanged: (value) =>
                widget.onChanged(query.copyWith(typeId: () => value)),
          ),
        ),
        box(
          200,
          DropdownButtonFormField<String?>(
            key: ValueKey('location-${query.locationId}-${locations.length}'),
            initialValue: locations.any((l) => l.id == query.locationId)
                ? query.locationId
                : null,
            decoration: const InputDecoration(labelText: 'Location'),
            isExpanded: true,
            items: [
              const DropdownMenuItem(value: null, child: Text('Anywhere')),
              for (final location in locations)
                DropdownMenuItem(
                  value: location.id,
                  child: Text(location.city),
                ),
            ],
            onChanged: (value) =>
                widget.onChanged(query.copyWith(locationId: () => value)),
          ),
        ),
        box(
          200,
          DropdownButtonFormField<PropertySort>(
            key: ValueKey('sort-${query.sort}'),
            initialValue: query.sort,
            decoration: const InputDecoration(labelText: 'Sort'),
            items: [
              for (final sort in PropertySort.values)
                DropdownMenuItem(value: sort, child: Text(sort.label)),
            ],
            onChanged: (value) => widget.onChanged(query.copyWith(sort: value)),
          ),
        ),
        if (query.hasFilters)
          TextButton(
            onPressed: () => widget.onChanged(const PropertyQuery()),
            child: const Text('Clear filters'),
          ),
      ],
    );
  }
}

/// Row menu shared by the table and the phone cards.
class _RowMenu extends ConsumerWidget {
  const _RowMenu({required this.item, required this.query});

  final PropertyListItem item;
  final PropertyQuery query;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    void refresh() => ref.invalidate(propertyPageProvider(query));
    return PopupMenuButton<String>(
      tooltip: 'Actions',
      onSelected: (action) async {
        if (action == 'edit') {
          context.go('/properties/${item.id}');
        } else if (action == 'view') {
          openOnWebsite(item.slug!);
        } else if (action == 'delete') {
          if (await deleteDraft(context, ref, id: item.id, code: item.code)) {
            refresh();
          }
        } else if (action.startsWith('state:')) {
          final to = PublishState.parse(action.substring(6));
          if (await changePublishState(
            context,
            ref,
            id: item.id,
            code: item.code,
            from: item.publishState,
            to: to,
          )) {
            refresh();
          }
        } else if (action.startsWith('availability:')) {
          final to = Availability.parse(action.substring(13));
          if (await changeAvailability(
            context,
            ref,
            id: item.id,
            code: item.code,
            from: item.availability,
            to: to,
          )) {
            refresh();
          }
        }
      },
      itemBuilder: (_) => [
        const PopupMenuItem(value: 'edit', child: Text('Edit')),
        if (item.publishState == PublishState.published && item.slug != null)
          const PopupMenuItem(value: 'view', child: Text('View on website')),
        const PopupMenuDivider(),
        for (final target in publishTargets(item.publishState))
          PopupMenuItem(
            value: 'state:${target.value}',
            child: Text(publishActionLabel(item.publishState, target)),
          ),
        if (item.publishState != PublishState.archived) ...[
          const PopupMenuDivider(),
          for (final target in Availability.values)
            if (target != item.availability)
              PopupMenuItem(
                value: 'availability:${target.value}',
                child: Text('Mark ${target.label.toLowerCase()}'),
              ),
        ],
        if (item.publishState == PublishState.draft) ...[
          const PopupMenuDivider(),
          const PopupMenuItem(value: 'delete', child: Text('Delete draft')),
        ],
      ],
    );
  }
}

class _Table extends StatelessWidget {
  const _Table({required this.items, required this.query});

  final List<PropertyListItem> items;
  final PropertyQuery query;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: ConstrainedBox(
          constraints: BoxConstraints(minWidth: constraints.maxWidth),
          child: DataTable(
            showCheckboxColumn: false,
            columnSpacing: 24,
            horizontalMargin: 16,
            dataRowMinHeight: 64,
            dataRowMaxHeight: 72,
            columns: const [
              DataColumn(label: Text('')),
              DataColumn(label: Text('Property')),
              DataColumn(label: Text('Location')),
              DataColumn(label: Text('Area')),
              DataColumn(label: Text('Price')),
              DataColumn(label: Text('Status')),
              DataColumn(label: Text('Updated')),
              DataColumn(label: Text('')),
            ],
            rows: [
              for (final item in items)
                DataRow(
                  onSelectChanged: (_) => context.go('/properties/${item.id}'),
                  cells: [
                    DataCell(Thumbnail(path: item.coverThumb)),
                    DataCell(
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 360),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Flexible(
                                  child: Text(
                                    item.title,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                if (item.isFeatured) ...[
                                  const SizedBox(width: 6),
                                  const Tooltip(
                                    message: 'Featured',
                                    child: Icon(
                                      Icons.star,
                                      size: 16,
                                      color: BrandColors.sand,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            Text(
                              '${item.code} · ${item.typeName}',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    ),
                    DataCell(
                      Text(
                        [item.locality, item.city]
                            .whereType<String>()
                            .where((s) => s.isNotEmpty)
                            .join(', '),
                      ),
                    ),
                    DataCell(Text(formatArea(item.areaValue, item.areaUnit))),
                    DataCell(Text(formatPrice(item.priceType, item.price))),
                    DataCell(
                      PropertyStatusPills(
                        state: item.publishState,
                        availability: item.availability,
                      ),
                    ),
                    DataCell(Text(updatedLabel(item.updatedAt))),
                    DataCell(_RowMenu(item: item, query: query)),
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
  const _Cards({required this.items, required this.query});

  final List<PropertyListItem> items;
  final PropertyQuery query;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      children: [
        for (final item in items)
          InkWell(
            onTap: () => context.go('/properties/${item.id}'),
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 4, 12),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: BrandColors.line)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Thumbnail(path: item.coverThumb, size: 64),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item.title, style: textTheme.titleSmall),
                        Text(
                          '${item.code} · ${item.city}',
                          style: textTheme.bodySmall,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${formatArea(item.areaValue, item.areaUnit)} · ${formatPrice(item.priceType, item.price)}',
                        ),
                        const SizedBox(height: 6),
                        PropertyStatusPills(
                          state: item.publishState,
                          availability: item.availability,
                        ),
                      ],
                    ),
                  ),
                  _RowMenu(item: item, query: query),
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

  final PropertyQuery query;
  final int total;
  final ValueChanged<int> onPage;

  @override
  Widget build(BuildContext context) {
    const size = PropertyQuery.pageSize;
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
