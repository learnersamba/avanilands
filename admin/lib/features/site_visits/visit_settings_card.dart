import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors.dart';
import '../../core/widgets/common.dart';
import 'site_visit_models.dart';
import 'site_visits_repository.dart';

/// Settings → Site visits: which days and times customers can pick on the
/// website, holidays, and how far ahead. Saved on its own.
class VisitSettingsCard extends ConsumerWidget {
  const VisitSettingsCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AsyncValueView(
      value: ref.watch(visitSettingsProvider),
      onRetry: () => ref.invalidate(visitSettingsProvider),
      data: (settings) => _Form(key: ValueKey(settings), settings: settings),
    );
  }
}

class _Form extends ConsumerStatefulWidget {
  const _Form({super.key, required this.settings});

  final VisitSettings settings;

  @override
  ConsumerState<_Form> createState() => _FormState();
}

class _FormState extends ConsumerState<_Form> {
  late Set<int> _days = {...widget.settings.days};
  late List<String> _slots = [...widget.settings.slots]..sort();
  late List<String> _closed = [
    ...widget.settings.closedDates.where((d) => d.compareTo(indiaToday()) >= 0),
  ]..sort();
  late double _ahead = widget.settings.daysAhead.toDouble();
  final _newSlot = TextEditingController();
  String? _slotError;
  bool _saving = false;

  @override
  void dispose() {
    _newSlot.dispose();
    super.dispose();
  }

  void _addSlot() {
    final slot = normalizeSlot(_newSlot.text);
    setState(() {
      if (slot == null) {
        _slotError = 'Type a time like 10:00 or 15:30.';
      } else if (_slots.contains(slot)) {
        _slotError = 'Already there.';
      } else if (_slots.length >= 12) {
        _slotError = 'At most 12 times.';
      } else {
        _slots = [..._slots, slot]..sort();
        _slotError = null;
        _newSlot.clear();
      }
    });
  }

  Future<void> _addHoliday() async {
    final today = DateTime.parse(indiaToday());
    final picked = await showDatePicker(
      context: context,
      initialDate: today.add(const Duration(days: 1)),
      firstDate: today,
      lastDate: today.add(const Duration(days: 365)),
      helpText: 'No visits on',
    );
    if (picked == null) return;
    final key = dateKey(picked);
    if (!_closed.contains(key)) {
      setState(() => _closed = [..._closed, key]..sort());
    }
  }

  Future<void> _save() async {
    if (_days.isEmpty || _slots.isEmpty) {
      showMessage(
        context,
        'Keep at least one day and one time, or customers can\'t book.',
        error: true,
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await ref
          .read(siteVisitsRepositoryProvider)
          .saveSettings(
            VisitSettings(
              days: _days,
              slots: _slots,
              closedDates: _closed,
              daysAhead: _ahead.round(),
            ),
          );
      ref.invalidate(visitSettingsProvider);
      if (mounted) {
        showMessage(
          context,
          'Site visit settings saved. The website shows them now.',
        );
      }
    } catch (error) {
      if (mounted) showMessage(context, friendlyError(error), error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return SectionCard(
      title: 'Site visits',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Days customers can book', style: textTheme.titleSmall),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final entry in weekdayNames.entries)
                FilterChip(
                  label: Text(entry.value),
                  selected: _days.contains(entry.key),
                  onSelected: (on) => setState(
                    () => _days = on
                        ? ({..._days, entry.key})
                        : (_days.difference({entry.key})),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 20),
          Text('Start times', style: textTheme.titleSmall),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              for (final slot in _slots)
                InputChip(
                  label: Text(formatVisitSlot(slot)),
                  onDeleted: () => setState(
                    () => _slots = _slots.where((s) => s != slot).toList(),
                  ),
                ),
              SizedBox(
                width: 150,
                child: TextField(
                  controller: _newSlot,
                  decoration: InputDecoration(
                    labelText: 'Add time',
                    hintText: '16:30',
                    errorText: _slotError,
                    errorMaxLines: 2,
                  ),
                  onSubmitted: (_) => _addSlot(),
                ),
              ),
              IconButton(
                tooltip: 'Add time',
                onPressed: _addSlot,
                icon: const Icon(Icons.add),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text('Holidays (no visits)', style: textTheme.titleSmall),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final date in _closed)
                InputChip(
                  label: Text(formatVisitDay(date)),
                  onDeleted: () => setState(
                    () => _closed = _closed.where((d) => d != date).toList(),
                  ),
                ),
              ActionChip(
                avatar: const Icon(Icons.add, size: 18),
                label: const Text('Add holiday'),
                onPressed: _addHoliday,
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            'Book up to ${_ahead.round()} days ahead (from tomorrow)',
            style: textTheme.titleSmall,
          ),
          Slider(
            value: _ahead,
            min: 7,
            max: 90,
            divisions: 83,
            label: '${_ahead.round()} days',
            onChanged: (value) => setState(() => _ahead = value),
          ),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: Text(_saving ? 'Saving…' : 'Save site visit settings'),
          ),
        ],
      ),
    );
  }
}
