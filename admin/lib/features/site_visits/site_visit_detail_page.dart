import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/browser.dart';
import '../../core/errors.dart';
import '../../core/formatting.dart';
import '../../core/theme.dart';
import '../../core/widgets/common.dart';
import '../activity/activity_tile.dart';
import '../admins/admins_repository.dart';
import '../auth/auth_controller.dart';
import '../bookings/booking_detail_page.dart' show startBooking;
import '../dashboard/dashboard_repository.dart';
import '../enquiries/enquiries_page.dart' show CustomerAccountPill;
import '../properties/property_actions.dart';
import '../properties/property_enums.dart';
import 'site_visit_models.dart';
import 'site_visits_page.dart';
import 'site_visits_repository.dart';

/// One site visit: who, where, when, the next step, notes and assignment.
class SiteVisitDetailPage extends ConsumerWidget {
  const SiteVisitDetailPage({super.key, required this.id});

  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AsyncValueView(
      value: ref.watch(siteVisitProvider(id)),
      onRetry: () => ref.invalidate(siteVisitProvider(id)),
      data: (visit) => _Detail(visit: visit),
    );
  }
}

/// Reloads everything that shows this visit.
void refreshSiteVisit(WidgetRef ref, String id) {
  ref
    ..invalidate(siteVisitProvider(id))
    ..invalidate(siteVisitNotesProvider(id))
    ..invalidate(siteVisitPageProvider)
    ..invalidate(siteVisitMonthProvider)
    ..invalidate(propertySiteVisitsProvider)
    ..invalidate(dashboardSummaryProvider);
}

class _Detail extends StatelessWidget {
  const _Detail({required this.visit});

  final SiteVisit visit;

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 1000;
    final main = [
      _VisitCard(visit: visit),
      _CustomerCard(visit: visit),
      _PropertyCard(property: visit.property),
      _Timeline(visit: visit),
    ];
    final side = [_NoteCard(visit: visit), _AssignCard(visit: visit)];
    List<Widget> spaced(List<Widget> items) => [
      for (var i = 0; i < items.length; i++) ...[
        if (i > 0) const SizedBox(height: 16),
        items[i],
      ],
    ];

    return PageBody(
      maxWidth: 1200,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () =>
                context.canPop() ? context.pop() : context.go('/site-visits'),
            icon: const Icon(Icons.arrow_back, size: 18),
            label: const Text('All site visits'),
          ),
        ),
        const SizedBox(height: 8),
        PageHeader(
          title: '${visit.reference} · ${visit.name}',
          subtitle:
              'Requested ${formatDateTime(visit.createdAt)} on the website',
          actions: [
            if (visit.customerId != null) const CustomerAccountPill(),
            SiteVisitStatusPill(status: visit.status),
          ],
        ),
        if (wide)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 3, child: Column(children: spaced(main))),
              const SizedBox(width: 24),
              Expanded(flex: 2, child: Column(children: spaced(side))),
            ],
          )
        else
          Column(
            children: spaced([main[0], main[1], ...side, ...main.skip(2)]),
          ),
      ],
    );
  }
}

/// When the visit is, and the buttons for the next step.
class _VisitCard extends ConsumerWidget {
  const _VisitCard({required this.visit});

  final SiteVisit visit;

  Future<void> _run(
    BuildContext context,
    WidgetRef ref,
    String action,
    String done,
  ) async {
    final result = await showDialog<_ActionInput>(
      context: context,
      builder: (_) => _ActionDialog(visit: visit, action: action),
    );
    if (result == null) return;
    try {
      await ref
          .read(siteVisitsRepositoryProvider)
          .act(
            visit.id,
            action,
            note: result.note,
            date: result.date,
            slot: result.slot,
          );
      refreshSiteVisit(ref, visit.id);
      if (context.mounted) {
        final emailed =
            visit.email != null &&
            const {'confirm', 'reschedule', 'cancel'}.contains(action);
        showMessage(
          context,
          emailed ? '$done The customer has been emailed.' : done,
        );
      }
    } catch (error) {
      if (context.mounted) {
        showMessage(context, friendlyError(error), error: true);
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final today = indiaToday();
    final status = visit.status;
    final buttons = <Widget>[
      if (status == SiteVisitStatus.requested)
        FilledButton.icon(
          onPressed: () => _run(context, ref, 'confirm', 'Visit confirmed.'),
          icon: const Icon(Icons.check, size: 18),
          label: const Text('Confirm'),
        ),
      if (visit.canFinish(today)) ...[
        FilledButton.icon(
          style: FilledButton.styleFrom(backgroundColor: BrandColors.available),
          onPressed: () =>
              _run(context, ref, 'complete', 'Marked as completed.'),
          icon: const Icon(Icons.done_all, size: 18),
          label: const Text('Visit done'),
        ),
        OutlinedButton(
          onPressed: () => _run(context, ref, 'no_show', 'Marked as no-show.'),
          child: const Text('No-show'),
        ),
      ],
      if (status == SiteVisitStatus.completed ||
          status == SiteVisitStatus.confirmed)
        OutlinedButton.icon(
          onPressed: () => startBooking(
            context,
            ref,
            propertyId: visit.property.id,
            propertyCode: visit.property.code,
            name: visit.name,
            phone: visit.phone,
            email: visit.email,
            siteVisitId: visit.id,
          ),
          icon: const Icon(Icons.key_outlined, size: 18),
          label: const Text('Start booking'),
        ),
      if (status.isOpen) ...[
        OutlinedButton.icon(
          onPressed: () => _run(context, ref, 'reschedule', 'Visit moved.'),
          icon: const Icon(Icons.edit_calendar_outlined, size: 18),
          label: const Text('Reschedule'),
        ),
        TextButton(
          style: TextButton.styleFrom(foregroundColor: BrandColors.danger),
          onPressed: () => _run(context, ref, 'cancel', 'Visit cancelled.'),
          child: const Text('Cancel visit'),
        ),
      ],
    ];

    return SectionCard(
      title: 'Visit',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.event, color: BrandColors.forest),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  visit.when,
                  style: textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: BrandColors.ink,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            [
              visit.people,
              if (visit.visitDate == today) 'today',
              if (status == SiteVisitStatus.confirmed &&
                  visit.reminderSentAt != null)
                'reminder sent',
            ].join(' · '),
            style: textTheme.bodySmall,
          ),
          if (status == SiteVisitStatus.requested) ...[
            const SizedBox(height: 12),
            const _Hint(
              'Call the customer to agree the time and meeting point, then '
              'confirm. They get an email (if they gave one) and a reminder the day before.',
            ),
          ],
          if (status == SiteVisitStatus.confirmed && !visit.canFinish(today))
            const Padding(
              padding: EdgeInsets.only(top: 12),
              child: _Hint(
                'After the visit, mark it done (or no-show) with a note on how it went.',
              ),
            ),
          if (buttons.isNotEmpty) ...[
            const SizedBox(height: 16),
            Wrap(spacing: 8, runSpacing: 8, children: buttons),
          ],
        ],
      ),
    );
  }
}

class _Hint extends StatelessWidget {
  const _Hint(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: BrandColors.paper,
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(text, style: Theme.of(context).textTheme.bodySmall),
  );
}

class _ActionInput {
  const _ActionInput({this.note, this.date, this.slot});

  final String? note;
  final String? date;
  final String? slot;
}

class _ActionDialog extends ConsumerStatefulWidget {
  const _ActionDialog({required this.visit, required this.action});

  final SiteVisit visit;
  final String action;

  @override
  ConsumerState<_ActionDialog> createState() => _ActionDialogState();
}

class _ActionDialogState extends ConsumerState<_ActionDialog> {
  final _note = TextEditingController();
  final _otherTime = TextEditingController();
  late String _date = widget.visit.visitDate;
  String? _slot;
  String? _error;

  bool get _reschedule => widget.action == 'reschedule';

  @override
  void dispose() {
    _note.dispose();
    _otherTime.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final today = DateTime.parse(indiaToday());
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.parse(_date).isBefore(today)
          ? today
          : DateTime.parse(_date),
      firstDate: today,
      lastDate: today.add(const Duration(days: 180)),
    );
    if (picked != null) setState(() => _date = dateKey(picked));
  }

  void _submit() {
    String? slot;
    if (_reschedule) {
      slot = _slot == 'other' ? normalizeSlot(_otherTime.text) : _slot;
      if (slot == null) {
        setState(
          () => _error = _slot == 'other'
              ? 'Type the time like 16:30.'
              : 'Choose a time.',
        );
        return;
      }
      if (_date == widget.visit.visitDate && slot == widget.visit.slot) {
        setState(() => _error = 'That is the current time of the visit.');
        return;
      }
    }
    Navigator.pop(
      context,
      _ActionInput(
        note: _note.text,
        date: _reschedule ? _date : null,
        slot: slot,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final visit = widget.visit;
    final slots = ref.watch(visitSettingsProvider).value?.slots ?? const [];
    final (title, confirmLabel, noteHint) = switch (widget.action) {
      'confirm' => (
        'Confirm ${visit.reference}?',
        'Confirm visit',
        'e.g. Meet at the main gate; Ravi will show the plot',
      ),
      'reschedule' => (
        'Move ${visit.reference}',
        'Move visit',
        'e.g. Customer asked for the afternoon',
      ),
      'complete' => (
        'Visit done',
        'Mark done',
        'How did it go? e.g. Liked it, wants a price discussion',
      ),
      'no_show' => (
        'Customer didn\'t come',
        'Mark no-show',
        'e.g. Not reachable on phone',
      ),
      _ => (
        'Cancel ${visit.reference}?',
        'Cancel visit',
        'Why? e.g. Customer bought elsewhere',
      ),
    };
    final emails = const {
      'confirm',
      'reschedule',
      'cancel',
    }.contains(widget.action);

    return AlertDialog(
      title: Text(title),
      content: SizedBox(
        width: 440,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!_reschedule)
              Text('${visit.when} · ${visit.name} · ${visit.property.code}'),
            if (_reschedule) ...[
              OutlinedButton.icon(
                onPressed: _pickDate,
                icon: const Icon(Icons.calendar_month, size: 18),
                label: Text(formatVisitDay(_date)),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _slot,
                decoration: const InputDecoration(labelText: 'Time'),
                items: [
                  for (final slot in {...slots, visit.slot}.toList()..sort())
                    DropdownMenuItem(
                      value: slot,
                      child: Text(formatVisitSlot(slot)),
                    ),
                  const DropdownMenuItem(
                    value: 'other',
                    child: Text('Another time…'),
                  ),
                ],
                onChanged: (value) => setState(() {
                  _slot = value;
                  _error = null;
                }),
              ),
              if (_slot == 'other') ...[
                const SizedBox(height: 12),
                TextField(
                  controller: _otherTime,
                  decoration: const InputDecoration(
                    labelText: 'Time (24-hour)',
                    hintText: '16:30',
                  ),
                ),
              ],
            ],
            const SizedBox(height: 12),
            TextField(
              controller: _note,
              minLines: 2,
              maxLines: 4,
              maxLength: 2000,
              decoration: InputDecoration(
                labelText: 'Note (optional)',
                hintText: noteHint,
                alignLabelWithHint: true,
              ),
            ),
            if (emails)
              Text(
                visit.email == null
                    ? 'No email on this request: tell the customer by phone or WhatsApp.'
                    : 'The customer will be emailed at ${visit.email}.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: const TextStyle(color: BrandColors.danger)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Back'),
        ),
        FilledButton(
          style: widget.action == 'cancel'
              ? FilledButton.styleFrom(backgroundColor: BrandColors.danger)
              : null,
          onPressed: _submit,
          child: Text(confirmLabel),
        ),
      ],
    );
  }
}

class _CustomerCard extends StatelessWidget {
  const _CustomerCard({required this.visit});

  final SiteVisit visit;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    Widget row(String label, String value) => Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 140, child: Text(label, style: textTheme.bodySmall)),
          Expanded(child: SelectableText(value)),
        ],
      ),
    );
    return SectionCard(
      title: 'Customer',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          row('Name', visit.name),
          row('Mobile', visit.phoneLabel),
          if (visit.email != null) row('Email', visit.email!),
          if (visit.message?.trim().isNotEmpty == true)
            row('Message', visit.message!),
          const SizedBox(height: 4),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                onPressed: () => openLink(visit.telLink),
                icon: const Icon(Icons.call, size: 18),
                label: const Text('Call'),
              ),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: BrandColors.available,
                ),
                onPressed: () => openLink(visit.whatsappLink),
                icon: const Icon(Icons.chat, size: 18),
                label: const Text('WhatsApp'),
              ),
              if (visit.mailLink != null)
                OutlinedButton.icon(
                  onPressed: () => openLink(visit.mailLink!),
                  icon: const Icon(Icons.mail_outline, size: 18),
                  label: const Text('Email'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PropertyCard extends StatelessWidget {
  const _PropertyCard({required this.property});

  final SiteVisitProperty property;

  @override
  Widget build(BuildContext context) {
    final state = PublishState.parse(property.publishState);
    return SectionCard(
      title: 'Property',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(property.title, style: Theme.of(context).textTheme.titleSmall),
          Text(
            [
              property.code,
              property.place,
            ].where((s) => s.isNotEmpty).join(' · '),
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
          PropertyStatusPills(
            state: state,
            availability: Availability.parse(property.availability),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton(
                onPressed: () => context.go('/properties/${property.id}'),
                child: const Text('Open property'),
              ),
              if (state == PublishState.published && property.slug != null)
                TextButton.icon(
                  onPressed: () => openOnWebsite(property.slug!),
                  icon: const Icon(Icons.open_in_new, size: 16),
                  label: const Text('View on website'),
                ),
              TextButton(
                onPressed: () => context.go(
                  SiteVisitQuery(
                    propertyId: property.id,
                    when: SiteVisitWhen.all,
                  ).location,
                ),
                child: const Text('All visits to this property'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _NoteCard extends ConsumerStatefulWidget {
  const _NoteCard({required this.visit});

  final SiteVisit visit;

  @override
  ConsumerState<_NoteCard> createState() => _NoteCardState();
}

class _NoteCardState extends ConsumerState<_NoteCard> {
  final _note = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await ref
          .read(siteVisitsRepositoryProvider)
          .addNote(widget.visit.id, _note.text.trim());
      _note.clear();
      refreshSiteVisit(ref, widget.visit.id);
      if (mounted) showMessage(context, 'Note added.');
    } catch (error) {
      if (mounted) showMessage(context, friendlyError(error), error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: 'Add a note',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _note,
            minLines: 3,
            maxLines: 6,
            maxLength: 2000,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              labelText: 'Note',
              hintText: 'e.g. Called, coming with brother',
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: _saving || _note.text.trim().isEmpty ? null : _save,
            child: Text(_saving ? 'Saving…' : 'Add note'),
          ),
        ],
      ),
    );
  }
}

class _AssignCard extends ConsumerWidget {
  const _AssignCard({required this.visit});

  final SiteVisit visit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(currentAdminProvider);
    final admins = ref.watch(adminUsersProvider).value ?? const [];
    final choices = [
      for (final admin in admins)
        if (admin.isActive || admin.userId == visit.assignedTo) admin,
    ];

    Future<void> assign(String? adminId) async {
      try {
        await ref.read(siteVisitsRepositoryProvider).assign(visit.id, adminId);
        refreshSiteVisit(ref, visit.id);
        if (context.mounted) {
          showMessage(context, adminId == null ? 'Unassigned.' : 'Assigned.');
        }
      } catch (error) {
        if (context.mounted) {
          showMessage(context, friendlyError(error), error: true);
        }
      }
    }

    return SectionCard(
      title: 'Who goes with the customer',
      trailing: visit.assignedTo == me.userId
          ? null
          : TextButton(
              onPressed: () => assign(me.userId),
              child: const Text('Assign to me'),
            ),
      child: DropdownButtonFormField<String?>(
        key: ValueKey('assignee-${visit.assignedTo}-${choices.length}'),
        initialValue: choices.any((a) => a.userId == visit.assignedTo)
            ? visit.assignedTo
            : null,
        decoration: const InputDecoration(labelText: 'Team member'),
        isExpanded: true,
        items: [
          const DropdownMenuItem(value: null, child: Text('Nobody yet')),
          for (final admin in choices)
            DropdownMenuItem(value: admin.userId, child: Text(admin.fullName)),
        ],
        onChanged: (value) {
          if (value != visit.assignedTo) assign(value);
        },
      ),
    );
  }
}

class _Timeline extends ConsumerWidget {
  const _Timeline({required this.visit});

  final SiteVisit visit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final names = ref.watch(adminNamesProvider);
    final textTheme = Theme.of(context).textTheme;

    Widget entry({
      required IconData icon,
      required String title,
      required String meta,
      String? body,
    }) => Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: BrandColors.paper,
            child: Icon(icon, size: 16, color: BrandColors.forest),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                Text(meta, style: textTheme.bodySmall),
                if (body != null) ...[
                  const SizedBox(height: 6),
                  SelectableText(body),
                ],
              ],
            ),
          ),
        ],
      ),
    );

    return SectionCard(
      title: 'Timeline',
      child: AsyncValueView(
        value: ref.watch(siteVisitNotesProvider(visit.id)),
        onRetry: () => ref.invalidate(siteVisitNotesProvider(visit.id)),
        data: (notes) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            entry(
              icon: Icons.event_note,
              title: 'Visit requested on the website',
              meta: formatDateTime(visit.createdAt),
            ),
            for (final note in notes)
              entry(
                icon: note.movedTo != null
                    ? Icons.edit_calendar_outlined
                    : note.statusTo != null
                    ? Icons.flag_outlined
                    : Icons.notes,
                title: note.headline,
                meta:
                    '${actorLabel(note.adminId, names)} · ${formatDateTime(note.createdAt)}',
                body: note.note,
              ),
          ],
        ),
      ),
    );
  }
}
