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
import '../properties/property_actions.dart';
import '../properties/property_enums.dart';
import 'enquiries_page.dart';
import 'enquiries_repository.dart';
import 'enquiry_models.dart';

/// One enquiry: how to reach the customer, the property, the follow-up
/// timeline, and status / note / assignment changes.
class EnquiryDetailPage extends ConsumerWidget {
  const EnquiryDetailPage({super.key, required this.id});

  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AsyncValueView(
      value: ref.watch(enquiryProvider(id)),
      onRetry: () => ref.invalidate(enquiryProvider(id)),
      data: (enquiry) => _Detail(enquiry: enquiry),
    );
  }
}

class _Detail extends ConsumerWidget {
  const _Detail({required this.enquiry});

  final Enquiry enquiry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wide = MediaQuery.sizeOf(context).width >= 1000;
    final main = [
      _CustomerCard(enquiry: enquiry),
      if (enquiry.property != null) _PropertyCard(property: enquiry.property!),
      _Timeline(enquiry: enquiry),
    ];
    final side = [_UpdateCard(enquiry: enquiry), _AssignCard(enquiry: enquiry)];
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
                context.canPop() ? context.pop() : context.go('/enquiries'),
            icon: const Icon(Icons.arrow_back, size: 18),
            label: const Text('All enquiries'),
          ),
        ),
        const SizedBox(height: 8),
        PageHeader(
          title: '${enquiry.reference} · ${enquiry.name}',
          subtitle:
              'Received ${formatDateTime(enquiry.createdAt)} from the '
              '${humanize(enquiry.source).toLowerCase()}',
          actions: [
            if (enquiry.customerId != null) const CustomerAccountPill(),
            EnquiryStatusPill(status: enquiry.status),
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
          Column(children: spaced([main.first, ...side, ...main.skip(1)])),
      ],
    );
  }
}

class _CustomerCard extends ConsumerWidget {
  const _CustomerCard({required this.enquiry});

  final Enquiry enquiry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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

    Future<void> markContacted() async {
      try {
        await ref
            .read(enquiriesRepositoryProvider)
            .updateStatus(enquiry.id, EnquiryStatus.contacted, null);
        refreshEnquiry(ref, enquiry.id);
        if (context.mounted) showMessage(context, 'Marked as contacted.');
      } catch (error) {
        if (context.mounted) {
          showMessage(context, friendlyError(error), error: true);
        }
      }
    }

    return SectionCard(
      title: 'Customer',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          row('Name', enquiry.name),
          row('Mobile', formatIndianMobile(enquiry.phone)),
          if (enquiry.email != null) row('Email', enquiry.email!),
          row('Prefers', contactMethodLabel(enquiry.preferredContact)),
          const SizedBox(height: 4),
          Text('Message', style: textTheme.bodySmall),
          const SizedBox(height: 4),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: BrandColors.paper,
              borderRadius: BorderRadius.circular(8),
            ),
            child: SelectableText(
              enquiry.message?.trim().isNotEmpty == true
                  ? enquiry.message!
                  : 'No message.',
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                onPressed: () => openLink(enquiry.telLink),
                icon: const Icon(Icons.call, size: 18),
                label: const Text('Call'),
              ),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: BrandColors.available,
                ),
                onPressed: () => openLink(enquiry.whatsappLink),
                icon: const Icon(Icons.chat, size: 18),
                label: const Text('WhatsApp'),
              ),
              if (enquiry.mailLink != null)
                OutlinedButton.icon(
                  onPressed: () => openLink(enquiry.mailLink!),
                  icon: const Icon(Icons.mail_outline, size: 18),
                  label: const Text('Email'),
                ),
              if (enquiry.property != null &&
                  enquiry.property!.availability == 'available')
                OutlinedButton.icon(
                  onPressed: () => startBooking(
                    context,
                    ref,
                    propertyId: enquiry.property!.id,
                    propertyCode: enquiry.property!.code,
                    name: enquiry.name,
                    phone: enquiry.phone,
                    email: enquiry.email,
                  ),
                  icon: const Icon(Icons.key_outlined, size: 18),
                  label: const Text('Start booking'),
                ),
              if (enquiry.status == EnquiryStatus.newEnquiry)
                OutlinedButton.icon(
                  onPressed: markContacted,
                  icon: const Icon(Icons.check, size: 18),
                  label: const Text('Mark contacted'),
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

  final EnquiryProperty property;

  @override
  Widget build(BuildContext context) {
    final state = PublishState.parse(property.publishState);
    return SectionCard(
      title: 'Property',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(property.title, style: Theme.of(context).textTheme.titleSmall),
          Text(property.code, style: Theme.of(context).textTheme.bodySmall),
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
                onPressed: () =>
                    context.go(EnquiryQuery(propertyId: property.id).location),
                child: const Text('All enquiries for this property'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Reloads everything that shows this enquiry.
void refreshEnquiry(WidgetRef ref, String id) {
  ref
    ..invalidate(enquiryProvider(id))
    ..invalidate(enquiryNotesProvider(id))
    ..invalidate(enquiryPageProvider)
    ..invalidate(dashboardSummaryProvider)
    ..invalidate(latestEnquiriesProvider);
}

class _UpdateCard extends ConsumerStatefulWidget {
  const _UpdateCard({required this.enquiry});

  final Enquiry enquiry;

  @override
  ConsumerState<_UpdateCard> createState() => _UpdateCardState();
}

class _UpdateCardState extends ConsumerState<_UpdateCard> {
  late EnquiryStatus _status = widget.enquiry.status;
  final _note = TextEditingController();
  bool _saving = false;

  @override
  void didUpdateWidget(covariant _UpdateCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.enquiry.status != widget.enquiry.status) {
      _status = widget.enquiry.status;
    }
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  bool get _changed =>
      _status != widget.enquiry.status || _note.text.trim().isNotEmpty;

  Future<void> _save() async {
    final note = _note.text.trim();
    final repository = ref.read(enquiriesRepositoryProvider);
    setState(() => _saving = true);
    try {
      if (_status != widget.enquiry.status) {
        await repository.updateStatus(
          widget.enquiry.id,
          _status,
          note.isEmpty ? null : note,
        );
      } else {
        await repository.addNote(widget.enquiry.id, note);
      }
      _note.clear();
      refreshEnquiry(ref, widget.enquiry.id);
      if (mounted) showMessage(context, 'Saved.');
    } catch (error) {
      if (mounted) showMessage(context, friendlyError(error), error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: 'Update',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DropdownButtonFormField<EnquiryStatus>(
            key: ValueKey('status-${widget.enquiry.status}'),
            initialValue: _status,
            decoration: const InputDecoration(labelText: 'Status'),
            items: [
              for (final status in EnquiryStatus.values)
                DropdownMenuItem(value: status, child: Text(status.label)),
            ],
            onChanged: (value) => setState(() => _status = value ?? _status),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _note,
            minLines: 3,
            maxLines: 6,
            maxLength: 2000,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              labelText: 'Note (optional with a status change)',
              hintText: 'e.g. Called, site visit on Saturday 10 am',
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: _saving || !_changed ? null : _save,
            child: Text(
              _saving
                  ? 'Saving…'
                  : _status != widget.enquiry.status
                  ? 'Save status'
                  : 'Add note',
            ),
          ),
        ],
      ),
    );
  }
}

class _AssignCard extends ConsumerWidget {
  const _AssignCard({required this.enquiry});

  final Enquiry enquiry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(currentAdminProvider);
    final admins = ref.watch(adminUsersProvider).value ?? const [];
    final choices = [
      for (final admin in admins)
        if (admin.isActive || admin.userId == enquiry.assignedTo) admin,
    ];

    Future<void> assign(String? adminId) async {
      try {
        await ref.read(enquiriesRepositoryProvider).assign(enquiry.id, adminId);
        refreshEnquiry(ref, enquiry.id);
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
      title: 'Assigned to',
      trailing: enquiry.assignedTo == me.userId
          ? null
          : TextButton(
              onPressed: () => assign(me.userId),
              child: const Text('Assign to me'),
            ),
      child: DropdownButtonFormField<String?>(
        key: ValueKey('assignee-${enquiry.assignedTo}-${choices.length}'),
        initialValue: choices.any((a) => a.userId == enquiry.assignedTo)
            ? enquiry.assignedTo
            : null,
        decoration: const InputDecoration(labelText: 'Team member'),
        isExpanded: true,
        items: [
          const DropdownMenuItem(value: null, child: Text('Nobody yet')),
          for (final admin in choices)
            DropdownMenuItem(value: admin.userId, child: Text(admin.fullName)),
        ],
        onChanged: (value) {
          if (value != enquiry.assignedTo) assign(value);
        },
      ),
    );
  }
}

class _Timeline extends ConsumerWidget {
  const _Timeline({required this.enquiry});

  final Enquiry enquiry;

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
        value: ref.watch(enquiryNotesProvider(enquiry.id)),
        onRetry: () => ref.invalidate(enquiryNotesProvider(enquiry.id)),
        data: (notes) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            entry(
              icon: Icons.mail_outline,
              title: 'Enquiry received',
              meta: formatDateTime(enquiry.createdAt),
            ),
            for (final note in notes)
              entry(
                icon: note.statusTo != null ? Icons.flag_outlined : Icons.notes,
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
