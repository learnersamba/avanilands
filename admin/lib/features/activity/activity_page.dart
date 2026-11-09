import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/formatting.dart';
import '../../core/widgets/common.dart';
import '../admins/admins_repository.dart';
import 'activity_repository.dart';
import 'activity_text.dart';
import 'activity_tile.dart';

/// Everything admins (and the website) changed, newest first.
/// Filter by area, admin and dates; loads 50 at a time.
class ActivityPage extends ConsumerStatefulWidget {
  const ActivityPage({super.key});

  @override
  ConsumerState<ActivityPage> createState() => _ActivityPageState();
}

class _ActivityPageState extends ConsumerState<ActivityPage> {
  static const _pageSize = 50;

  ActivityFilter _filter = const ActivityFilter();
  final List<AuditEntry> _entries = [];
  final Map<String, String> _codes = {};
  bool _loading = false;
  bool _hasMore = true;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load(reset: true);
  }

  Future<void> _load({bool reset = false}) async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
      if (reset) {
        _entries.clear();
        _codes.clear();
        _hasMore = true;
      }
    });
    try {
      final feed = await ref
          .read(activityRepositoryProvider)
          .fetch(filter: _filter, offset: _entries.length, limit: _pageSize);
      if (!mounted) return;
      setState(() {
        _entries.addAll(feed.entries);
        _codes.addAll(feed.propertyCodes);
        _hasMore = feed.entries.length == _pageSize;
      });
    } catch (error) {
      if (mounted) setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _setFilter(ActivityFilter filter) {
    _filter = filter;
    _load(reset: true);
  }

  Future<void> _pickDates() async {
    final now = DateTime.now();
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2026),
      lastDate: now,
      initialDateRange: _filter.from == null
          ? null
          : DateTimeRange(start: _filter.from!, end: _filter.to ?? now),
    );
    if (range == null) return;
    _setFilter(
      ActivityFilter(
        entityType: _filter.entityType,
        actorId: _filter.actorId,
        from: range.start,
        to: range.end,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final admins = ref.watch(adminUsersProvider).value ?? const [];
    final names = ref.watch(adminNamesProvider);
    final hasDates = _filter.from != null;

    return PageBody(
      maxWidth: 960,
      children: [
        const PageHeader(
          title: 'Activity log',
          subtitle: 'Every change to properties, media, enquiries, admins and settings. It cannot be edited.',
        ),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
              width: 220,
              child: DropdownButtonFormField<String?>(
                initialValue: _filter.entityType,
                decoration: const InputDecoration(labelText: 'Area'),
                items: [
                  const DropdownMenuItem(
                    value: null,
                    child: Text('Everything'),
                  ),
                  for (final entry in activityEntityTypes.entries)
                    DropdownMenuItem(
                      value: entry.key,
                      child: Text(entry.value),
                    ),
                ],
                onChanged: (value) => _setFilter(
                  ActivityFilter(
                    entityType: value,
                    actorId: _filter.actorId,
                    from: _filter.from,
                    to: _filter.to,
                  ),
                ),
              ),
            ),
            SizedBox(
              width: 220,
              child: DropdownButtonFormField<String?>(
                initialValue: _filter.actorId,
                decoration: const InputDecoration(labelText: 'Admin'),
                items: [
                  const DropdownMenuItem(value: null, child: Text('Anyone')),
                  for (final admin in admins)
                    DropdownMenuItem(
                      value: admin.userId,
                      child: Text(admin.fullName),
                    ),
                ],
                onChanged: (value) => _setFilter(
                  ActivityFilter(
                    entityType: _filter.entityType,
                    actorId: value,
                    from: _filter.from,
                    to: _filter.to,
                  ),
                ),
              ),
            ),
            OutlinedButton.icon(
              onPressed: _pickDates,
              icon: const Icon(Icons.date_range, size: 18),
              label: Text(
                hasDates
                    ? '${formatDate(_filter.from!)} – ${formatDate(_filter.to!)}'
                    : 'Any date',
              ),
            ),
            if (hasDates ||
                _filter.entityType != null ||
                _filter.actorId != null)
              TextButton(
                onPressed: () => _setFilter(const ActivityFilter()),
                child: const Text('Clear filters'),
              ),
          ],
        ),
        const SizedBox(height: 20),
        Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_entries.isEmpty && !_loading && _error == null)
                  const EmptyState(
                    message: 'No activity matches these filters.',
                  ),
                for (final entry in _entries) ...[
                  ActivityTile(
                    entry: entry,
                    actorName: actorLabel(entry.actorId, names),
                    propertyCode: _codes[entry.propertyId],
                  ),
                  if (entry != _entries.last) const Divider(height: 1),
                ],
                if (_error != null) ErrorView(error: _error!, onRetry: _load),
                if (_loading) const LoadingView(),
                if (!_loading &&
                    _error == null &&
                    _hasMore &&
                    _entries.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Center(
                      child: OutlinedButton(
                        onPressed: _load,
                        child: const Text('Load more'),
                      ),
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
