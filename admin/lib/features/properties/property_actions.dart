import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors.dart';
import '../../core/formatting.dart';
import '../../core/number_input.dart';
import '../../core/widgets/common.dart';
import 'properties_repository.dart';
import 'property_enums.dart';

/// "25 cents (10,890 sq ft)".
String formatArea(double? value, AreaUnit unit) {
  if (value == null) return '—';
  final amount = formatInputNumber(value);
  if (unit == AreaUnit.sqFt) return '$amount sq ft';
  return '$amount ${unit.label} (${formatInputNumber(unit.toSqft(value).roundToDouble(), rupees: true)} sq ft)';
}

String formatPrice(PriceType type, double? price) {
  if (type == PriceType.onRequest) return 'On request';
  if (price == null) return '—';
  return shortRupees(price);
}

/// Status changes the admin can make from a given state.
List<PublishState> publishTargets(PublishState current) => switch (current) {
  PublishState.draft => [
    PublishState.published,
    PublishState.hidden,
    PublishState.archived,
  ],
  PublishState.published => [PublishState.hidden, PublishState.archived],
  PublishState.hidden => [PublishState.published, PublishState.archived],
  PublishState.archived => [PublishState.hidden, PublishState.published],
};

String publishActionLabel(PublishState current, PublishState target) =>
    switch (target) {
      PublishState.published =>
        current == PublishState.archived ? 'Restore and publish' : 'Publish',
      PublishState.hidden =>
        current == PublishState.published
            ? 'Unpublish (hide)'
            : current == PublishState.archived
            ? 'Restore as hidden'
            : 'Hide',
      PublishState.archived => 'Archive',
      PublishState.draft => 'Draft',
    };

/// Changes the publish state after confirming; returns true on success.
/// Database rules (cover photo, no going back to draft) still apply.
Future<bool> changePublishState(
  BuildContext context,
  WidgetRef ref, {
  required String id,
  required String code,
  required PublishState from,
  required PublishState to,
}) async {
  final message = switch (to) {
    PublishState.published => '$code will be visible on the website.',
    PublishState.hidden =>
      '$code will be hidden from the website. Its link stops working until you publish it again.',
    PublishState.archived =>
      '$code will be removed from the website and from your active list. Its enquiries and history are kept.',
    PublishState.draft => '',
  };
  final ok = await confirmAction(
    context,
    title: '${publishActionLabel(from, to)} $code?',
    message: message,
    confirmLabel: publishActionLabel(from, to),
    destructive: to == PublishState.archived,
  );
  if (!ok || !context.mounted) return false;
  try {
    await ref.read(propertiesRepositoryProvider).setPublishState(id, to);
    if (context.mounted) {
      showMessage(context, '$code is now ${to.label.toLowerCase()}.');
    }
    return true;
  } catch (error) {
    if (context.mounted) {
      showMessage(context, friendlyError(error), error: true);
    }
    return false;
  }
}

/// Marks a property available / reserved / sold after confirming.
Future<bool> changeAvailability(
  BuildContext context,
  WidgetRef ref, {
  required String id,
  required String code,
  required Availability from,
  required Availability to,
}) async {
  final message = switch (to) {
    Availability.reserved =>
      'Customers will see "Reserved". Enquiries are still accepted.',
    Availability.sold => 'Customers will see "Sold" and can no longer enquire. Only a super admin can undo this.',
    Availability.available =>
      from == Availability.sold
          ? 'This undoes a sale. Make sure the deal was really cancelled.'
          : 'Customers will see "Available" again.',
  };
  final ok = await confirmAction(
    context,
    title: 'Mark $code as ${to.label.toLowerCase()}?',
    message: message,
    confirmLabel: 'Mark ${to.label.toLowerCase()}',
    destructive: from == Availability.sold,
  );
  if (!ok || !context.mounted) return false;
  try {
    await ref.read(propertiesRepositoryProvider).setAvailability(id, to);
    if (context.mounted) {
      showMessage(context, '$code marked ${to.label.toLowerCase()}.');
    }
    return true;
  } catch (error) {
    if (context.mounted) {
      showMessage(context, friendlyError(error), error: true);
    }
    return false;
  }
}

Future<bool> deleteDraft(
  BuildContext context,
  WidgetRef ref, {
  required String id,
  required String code,
}) async {
  final ok = await confirmAction(
    context,
    title: 'Delete draft $code?',
    message:
        'The draft and its files are removed for good. This cannot be undone.',
    confirmLabel: 'Delete',
    destructive: true,
  );
  if (!ok || !context.mounted) return false;
  try {
    await ref.read(propertiesRepositoryProvider).deleteDraft(id);
    if (context.mounted) showMessage(context, 'Draft $code deleted.');
    return true;
  } catch (error) {
    if (context.mounted) {
      showMessage(context, friendlyError(error), error: true);
    }
    return false;
  }
}

/// Publish state + availability as two small labels.
class PropertyStatusPills extends StatelessWidget {
  const PropertyStatusPills({
    super.key,
    required this.state,
    required this.availability,
  });

  final PublishState state;
  final Availability availability;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: [
        Pill(label: state.label, color: state.color),
        if (state != PublishState.archived &&
            availability != Availability.available)
          Pill(label: availability.label, color: availability.color),
      ],
    );
  }
}

String updatedLabel(DateTime value) => formatRelative(value);
