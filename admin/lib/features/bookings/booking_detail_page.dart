import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import '../dashboard/dashboard_repository.dart';
import '../enquiries/enquiries_page.dart' show CustomerAccountPill;
import '../properties/properties_repository.dart';
import '../properties/property_actions.dart';
import '../properties/property_enums.dart';
import 'booking_models.dart';
import 'bookings_page.dart';
import 'bookings_repository.dart';

class BookingDetailPage extends ConsumerWidget {
  const BookingDetailPage({super.key, required this.id});

  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AsyncValueView(
      value: ref.watch(bookingProvider(id)),
      onRetry: () => ref.invalidate(bookingProvider(id)),
      data: (booking) => _Detail(booking: booking),
    );
  }
}

/// Reloads everything that shows this booking or its property.
void refreshBooking(WidgetRef ref, Booking booking) {
  ref
    ..invalidate(bookingProvider(booking.id))
    ..invalidate(bookingNotesProvider(booking.id))
    ..invalidate(bookingPageProvider)
    ..invalidate(propertyBookingsProvider)
    ..invalidate(propertyDetailProvider(booking.property.id))
    ..invalidate(propertyPageProvider)
    ..invalidate(dashboardSummaryProvider);
}

class _Detail extends StatelessWidget {
  const _Detail({required this.booking});

  final Booking booking;

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 1000;
    final main = [
      _StepsCard(booking: booking),
      _MoneyCard(booking: booking),
      _CustomerCard(booking: booking),
      _Timeline(booking: booking),
    ];
    final side = [
      _PropertyCard(property: booking.property),
      _NoteCard(booking: booking),
      _AssignCard(booking: booking),
    ];
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
                context.canPop() ? context.pop() : context.go('/bookings'),
            icon: const Icon(Icons.arrow_back, size: 18),
            label: const Text('All bookings'),
          ),
        ),
        const SizedBox(height: 8),
        PageHeader(
          title: '${booking.reference} · ${booking.name}',
          subtitle:
              '${booking.property.code} · started ${formatDateTime(booking.createdAt)} '
              '${booking.source == 'website' ? 'by the customer on the website' : 'by the team'}',
          actions: [
            if (booking.customerId != null) const CustomerAccountPill(),
            BookingStatusPill(status: booking.status),
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
          Column(children: spaced([main[0], ...side, ...main.skip(1)])),
      ],
    );
  }
}

/// Progress through the owner's steps, and the buttons for the next one.
class _StepsCard extends ConsumerWidget {
  const _StepsCard({required this.booking});

  final Booking booking;

  Future<void> _run(
    BuildContext context,
    WidgetRef ref,
    BookingAction action,
  ) async {
    final input = await showDialog<_ActionInput>(
      context: context,
      builder: (_) => _ActionDialog(booking: booking, action: action),
    );
    if (input == null) return;
    try {
      await ref
          .read(bookingsRepositoryProvider)
          .act(
            booking.id,
            action.value,
            note: input.note,
            amount: input.amount,
            receivedOn: input.receivedOn,
            paymentMethod: input.paymentMethod,
            paymentReference: input.paymentReference,
            agreedPrice: input.agreedPrice,
          );
      refreshBooking(ref, booking);
      if (context.mounted) {
        showMessage(
          context,
          '${action.label}: done.${booking.email != null && action.value != 'send_for_approval' ? ' The customer has been emailed.' : ''}',
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
    final isSuper = ref.watch(currentAdminProvider).isSuperAdmin;
    final status = booking.status;
    final current = bookingPath.indexOf(status);
    final actions = actionsFor(status);
    final textTheme = Theme.of(context).textTheme;

    return SectionCard(
      title: 'Progress',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (status == BookingStatus.cancelled)
            Text(
              'Cancelled${booking.cancelledReason == null ? '' : ': ${booking.cancelledReason}'}',
              style: const TextStyle(
                color: BrandColors.danger,
                fontWeight: FontWeight.w600,
              ),
            )
          else
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (var i = 0; i < bookingPath.length; i++)
                  Chip(
                    visualDensity: VisualDensity.compact,
                    avatar: Icon(
                      i < current
                          ? Icons.check_circle
                          : i == current
                          ? Icons.radio_button_checked
                          : Icons.radio_button_unchecked,
                      size: 18,
                      color: i <= current
                          ? BrandColors.forest
                          : BrandColors.line,
                    ),
                    label: Text(bookingPath[i].label),
                    backgroundColor: i == current
                        ? BrandColors.forest.withValues(alpha: 0.1)
                        : null,
                  ),
              ],
            ),
          if (status.holdsProperty) ...[
            const SizedBox(height: 12),
            Text(
              'This booking holds ${booking.property.code}: it shows as Reserved and nobody else can book it.',
              style: textTheme.bodySmall,
            ),
          ],
          if (actions.isNotEmpty) ...[
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                for (final action in actions)
                  if (action.superAdminOnly && !isSuper)
                    Tooltip(
                      message:
                          'Only a super admin can ${action.label.toLowerCase()}.',
                      child: FilledButton(
                        onPressed: null,
                        child: Text(action.label),
                      ),
                    )
                  else if (action.danger)
                    TextButton(
                      style: TextButton.styleFrom(
                        foregroundColor: BrandColors.danger,
                      ),
                      onPressed: () => _run(context, ref, action),
                      child: Text(action.label),
                    )
                  else
                    FilledButton(
                      onPressed: () => _run(context, ref, action),
                      child: Text(action.label),
                    ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _ActionInput {
  const _ActionInput({
    this.note,
    this.amount,
    this.receivedOn,
    this.paymentMethod,
    this.paymentReference,
    this.agreedPrice,
  });

  final String? note;
  final double? amount;
  final String? receivedOn;
  final String? paymentMethod;
  final String? paymentReference;
  final double? agreedPrice;
}

double? _parseRupees(String text) {
  final digits = text.replaceAll(RegExp(r'[^0-9.]'), '');
  final value = double.tryParse(digits);
  return value == null || value <= 0 ? null : value;
}

class _ActionDialog extends StatefulWidget {
  const _ActionDialog({required this.booking, required this.action});

  final Booking booking;
  final BookingAction action;

  @override
  State<_ActionDialog> createState() => _ActionDialogState();
}

class _ActionDialogState extends State<_ActionDialog> {
  final _note = TextEditingController();
  late final _amount = TextEditingController(
    text: widget.action.needsPayment && widget.booking.bookingAmount != null
        ? widget.booking.bookingAmount!.toStringAsFixed(0)
        : '',
  );
  late final _agreed = TextEditingController(
    text:
        (widget.booking.agreedPrice ?? widget.booking.property.price)
            ?.toStringAsFixed(0) ??
        '',
  );
  final _reference = TextEditingController();
  DateTime _receivedOn = DateTime.now();
  String? _method;
  String? _error;

  @override
  void dispose() {
    for (final c in [_note, _amount, _agreed, _reference]) {
      c.dispose();
    }
    super.dispose();
  }

  void _submit() {
    final action = widget.action;
    final amount = _parseRupees(_amount.text);
    if ((action.needsAmount || action.needsPayment) && amount == null) {
      return setState(() => _error = 'Enter the amount in rupees.');
    }
    if (action.needsPayment && _method == null) {
      return setState(() => _error = 'Choose how it was paid.');
    }
    if (action.needsNote && _note.text.trim().isEmpty) {
      return setState(() => _error = 'Say why (the customer is told).');
    }
    Navigator.pop(
      context,
      _ActionInput(
        note: _note.text,
        amount: (action.needsAmount || action.needsPayment) ? amount : null,
        receivedOn: action.needsPayment
            ? '${_receivedOn.year}-${_receivedOn.month.toString().padLeft(2, '0')}-${_receivedOn.day.toString().padLeft(2, '0')}'
            : null,
        paymentMethod: action.needsPayment ? _method : null,
        paymentReference: action.needsPayment ? _reference.text.trim() : null,
        agreedPrice: action.asksAgreedPrice ? _parseRupees(_agreed.text) : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final action = widget.action;
    final booking = widget.booking;
    final money = [FilteringTextInputFormatter.allow(RegExp(r'[0-9]'))];
    return AlertDialog(
      title: Text('${action.label} · ${booking.reference}'),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '${booking.name} · ${booking.property.code} ${booking.property.title}',
              ),
              if (action.effect != null) ...[
                const SizedBox(height: 8),
                Text(
                  action.effect!,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: BrandColors.forest,
                  ),
                ),
              ],
              if (action.asksAgreedPrice) ...[
                const SizedBox(height: 12),
                TextField(
                  controller: _agreed,
                  keyboardType: TextInputType.number,
                  inputFormatters: money,
                  decoration: const InputDecoration(
                    labelText: 'Agreed price (₹, optional)',
                    prefixText: '₹ ',
                  ),
                ),
              ],
              if (action.needsAmount || action.needsPayment) ...[
                const SizedBox(height: 12),
                TextField(
                  controller: _amount,
                  keyboardType: TextInputType.number,
                  inputFormatters: money,
                  decoration: InputDecoration(
                    labelText: action.needsPayment
                        ? 'Amount received (₹)'
                        : 'Booking amount (₹)',
                    prefixText: '₹ ',
                  ),
                ),
              ],
              if (action.needsPayment) ...[
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _receivedOn,
                      firstDate: DateTime.now().subtract(
                        const Duration(days: 365),
                      ),
                      lastDate: DateTime.now(),
                      helpText: 'Received on',
                    );
                    if (picked != null) setState(() => _receivedOn = picked);
                  },
                  icon: const Icon(Icons.calendar_month, size: 18),
                  label: Text('Received on ${formatDate(_receivedOn)}'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _method,
                  decoration: const InputDecoration(labelText: 'Paid by'),
                  items: [
                    for (final entry in paymentMethods.entries)
                      DropdownMenuItem(
                        value: entry.key,
                        child: Text(entry.value),
                      ),
                  ],
                  onChanged: (value) => setState(() => _method = value),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _reference,
                  maxLength: 120,
                  decoration: const InputDecoration(
                    labelText: 'Reference (UTR / cheque no., optional)',
                    helperText:
                        'Never enter card or full bank account numbers.',
                  ),
                ),
              ],
              const SizedBox(height: 12),
              TextField(
                controller: _note,
                minLines: 2,
                maxLines: 4,
                maxLength: 1000,
                decoration: InputDecoration(
                  labelText: action.needsNote
                      ? 'Reason (sent to the customer)'
                      : 'Note (optional)',
                  alignLabelWithHint: true,
                ),
              ),
              if (booking.email != null && action.value != 'send_for_approval')
                Text(
                  'The customer will be emailed at ${booking.email} (never with payment details).',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(
                  _error!,
                  style: const TextStyle(color: BrandColors.danger),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Back'),
        ),
        FilledButton(
          style: action.danger
              ? FilledButton.styleFrom(backgroundColor: BrandColors.danger)
              : null,
          onPressed: _submit,
          child: Text(action.label),
        ),
      ],
    );
  }
}

class _MoneyCard extends StatelessWidget {
  const _MoneyCard({required this.booking});

  final Booking booking;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    Widget row(String label, String value) => Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(width: 170, child: Text(label, style: textTheme.bodySmall)),
          Expanded(child: SelectableText(value)),
        ],
      ),
    );
    return SectionCard(
      title: 'Price and payment',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          row(
            'Listed price',
            booking.property.price == null
                ? 'On request'
                : formatRupees(booking.property.price!),
          ),
          row(
            'Agreed price',
            booking.agreedPrice == null
                ? '—'
                : formatRupees(booking.agreedPrice!),
          ),
          row(
            'Booking amount',
            booking.bookingAmount == null
                ? '—'
                : formatRupees(booking.bookingAmount!),
          ),
          row(
            'Received',
            booking.amountReceived == null
                ? '—'
                : '${formatRupees(booking.amountReceived!)} on ${booking.receivedOn == null ? '?' : formatDate(DateTime.parse(booking.receivedOn!))}'
                      '${booking.paymentMethod != null ? ' · ${paymentMethods[booking.paymentMethod] ?? booking.paymentMethod}' : ''}'
                      '${booking.paymentReference != null ? ' · ref ${booking.paymentReference}' : ''}',
          ),
          Text(
            'Payments are made through the company\'s usual process; this is the record. '
            'Payment details are given to customers by phone from official numbers only.',
            style: textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _CustomerCard extends StatelessWidget {
  const _CustomerCard({required this.booking});

  final Booking booking;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: 'Customer',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SelectableText(
            '${booking.name} · ${booking.phoneLabel}${booking.email == null ? '' : ' · ${booking.email}'}',
          ),
          if (booking.message?.trim().isNotEmpty == true) ...[
            const SizedBox(height: 8),
            SelectableText('“${booking.message}”'),
          ],
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                onPressed: () => openLink(booking.telLink),
                icon: const Icon(Icons.call, size: 18),
                label: const Text('Call'),
              ),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: BrandColors.available,
                ),
                onPressed: () => openLink(booking.whatsappLink),
                icon: const Icon(Icons.chat, size: 18),
                label: const Text('WhatsApp'),
              ),
              if (booking.siteVisitId != null)
                TextButton(
                  onPressed: () =>
                      context.go('/site-visits/${booking.siteVisitId}'),
                  child: const Text('Their site visit'),
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

  final BookingProperty property;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: 'Property',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(property.title, style: Theme.of(context).textTheme.titleSmall),
          Text(property.code, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 8),
          PropertyStatusPills(
            state: PublishState.parse(property.publishState),
            availability: Availability.parse(property.availability),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: [
              OutlinedButton(
                onPressed: () => context.go('/properties/${property.id}'),
                child: const Text('Open property'),
              ),
              TextButton(
                onPressed: () => context.go(
                  BookingQuery(propertyId: property.id, open: false).location,
                ),
                child: const Text('All its bookings'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _NoteCard extends ConsumerStatefulWidget {
  const _NoteCard({required this.booking});

  final Booking booking;

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

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: 'Add a note',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _note,
            minLines: 2,
            maxLines: 5,
            maxLength: 2000,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              labelText: 'Note',
              hintText: 'e.g. Documents received, loan sanction pending',
            ),
          ),
          FilledButton(
            onPressed: _saving || _note.text.trim().isEmpty
                ? null
                : () async {
                    setState(() => _saving = true);
                    try {
                      await ref
                          .read(bookingsRepositoryProvider)
                          .addNote(widget.booking.id, _note.text.trim());
                      _note.clear();
                      refreshBooking(ref, widget.booking);
                    } catch (error) {
                      if (context.mounted) {
                        showMessage(context, friendlyError(error), error: true);
                      }
                    } finally {
                      if (mounted) setState(() => _saving = false);
                    }
                  },
            child: Text(_saving ? 'Saving…' : 'Add note'),
          ),
        ],
      ),
    );
  }
}

class _AssignCard extends ConsumerWidget {
  const _AssignCard({required this.booking});

  final Booking booking;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(currentAdminProvider);
    final admins = ref.watch(adminUsersProvider).value ?? const [];
    final choices = [
      for (final admin in admins)
        if (admin.isActive || admin.userId == booking.assignedTo) admin,
    ];
    Future<void> assign(String? adminId) async {
      try {
        await ref.read(bookingsRepositoryProvider).assign(booking.id, adminId);
        refreshBooking(ref, booking);
      } catch (error) {
        if (context.mounted) {
          showMessage(context, friendlyError(error), error: true);
        }
      }
    }

    return SectionCard(
      title: 'Handled by',
      trailing: booking.assignedTo == me.userId
          ? null
          : TextButton(
              onPressed: () => assign(me.userId),
              child: const Text('Assign to me'),
            ),
      child: DropdownButtonFormField<String?>(
        key: ValueKey('assignee-${booking.assignedTo}-${choices.length}'),
        initialValue: choices.any((a) => a.userId == booking.assignedTo)
            ? booking.assignedTo
            : null,
        decoration: const InputDecoration(labelText: 'Team member'),
        isExpanded: true,
        items: [
          const DropdownMenuItem(value: null, child: Text('Nobody yet')),
          for (final admin in choices)
            DropdownMenuItem(value: admin.userId, child: Text(admin.fullName)),
        ],
        onChanged: (value) {
          if (value != booking.assignedTo) assign(value);
        },
      ),
    );
  }
}

class _Timeline extends ConsumerWidget {
  const _Timeline({required this.booking});

  final Booking booking;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final names = ref.watch(adminNamesProvider);
    final textTheme = Theme.of(context).textTheme;
    return SectionCard(
      title: 'Timeline',
      child: AsyncValueView(
        value: ref.watch(bookingNotesProvider(booking.id)),
        onRetry: () => ref.invalidate(bookingNotesProvider(booking.id)),
        data: (notes) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _entry(
              textTheme,
              booking.source == 'website'
                  ? 'Requested on the website'
                  : 'Booking started',
              formatDateTime(booking.createdAt),
              booking.message,
            ),
            for (final note in notes)
              _entry(
                textTheme,
                note.headline(formatRupees),
                '${actorLabel(note.adminId, names)} · ${formatDateTime(note.createdAt)}',
                note.note,
              ),
          ],
        ),
      ),
    );
  }

  Widget _entry(TextTheme textTheme, String title, String meta, String? body) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
            Text(meta, style: textTheme.bodySmall),
            if (body != null && body.trim().isNotEmpty) ...[
              const SizedBox(height: 4),
              SelectableText(body),
            ],
          ],
        ),
      );
}

/// "Start booking" from a site visit or an enquiry. Opens the new booking.
Future<void> startBooking(
  BuildContext context,
  WidgetRef ref, {
  required String propertyId,
  required String propertyCode,
  required String name,
  required String phone,
  String? email,
  String? siteVisitId,
}) async {
  final note = TextEditingController();
  final ok = await confirmAction(
    context,
    title: 'Start a booking for $propertyCode?',
    message:
        '$name will be added as a booking request. A super admin approves it; then the property is reserved.',
    confirmLabel: 'Start booking',
  );
  note.dispose();
  if (!ok || !context.mounted) return;
  try {
    final id = await ref
        .read(bookingsRepositoryProvider)
        .create(
          propertyId: propertyId,
          name: name,
          phone: phone,
          email: email,
          siteVisitId: siteVisitId,
        );
    ref
      ..invalidate(bookingPageProvider)
      ..invalidate(dashboardSummaryProvider);
    if (context.mounted) context.go('/bookings/$id');
  } catch (error) {
    if (context.mounted) {
      showMessage(context, friendlyError(error), error: true);
    }
  }
}
