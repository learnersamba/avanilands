import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../enquiries/enquiry_models.dart' show formatIndianMobile;

enum BookingStatus {
  requested('requested', 'Requested'),
  pendingApproval('pending_approval', 'Pending approval'),
  approved('approved', 'Approved'),
  paymentPending('payment_pending', 'Payment pending'),
  reserved('reserved', 'Reserved'),
  completed('completed', 'Completed'),
  cancelled('cancelled', 'Cancelled');

  const BookingStatus(this.value, this.label);
  final String value;
  final String label;

  static BookingStatus parse(String? value) =>
      values.firstWhere((item) => item.value == value, orElse: () => requested);

  static BookingStatus? tryParse(String? value) {
    for (final item in values) {
      if (item.value == value) return item;
    }
    return null;
  }

  /// These steps hold the property (it shows as Reserved).
  bool get holdsProperty =>
      this == approved || this == paymentPending || this == reserved;

  bool get isFinished => this == completed || this == cancelled;

  Color get color => switch (this) {
    requested || pendingApproval => BrandColors.sand,
    approved || paymentPending || reserved => BrandColors.reserved,
    completed => BrandColors.available,
    cancelled => BrandColors.sold,
  };
}

/// The main path, for the progress bar on a booking.
const bookingPath = [
  BookingStatus.requested,
  BookingStatus.pendingApproval,
  BookingStatus.approved,
  BookingStatus.paymentPending,
  BookingStatus.reserved,
  BookingStatus.completed,
];

const paymentMethods = {
  'bank_transfer': 'Bank transfer (NEFT / RTGS / IMPS)',
  'upi': 'UPI',
  'cheque': 'Cheque',
  'demand_draft': 'Demand draft',
  'cash': 'Cash',
  'loan': 'Bank loan disbursement',
  'other': 'Other',
};

/// What the next button does, who may press it, and what it asks for.
class BookingAction {
  const BookingAction(
    this.value,
    this.label, {
    this.superAdminOnly = false,
    this.danger = false,
    this.needsAmount = false,
    this.needsPayment = false,
    this.needsNote = false,
    this.asksAgreedPrice = false,
    this.effect,
  });

  final String value;
  final String label;
  final bool superAdminOnly;
  final bool danger;
  final bool needsAmount;
  final bool needsPayment;
  final bool needsNote;
  final bool asksAgreedPrice;

  /// What happens to the property, said in the confirmation.
  final String? effect;
}

const _sendForApproval = BookingAction(
  'send_for_approval',
  'Send for approval',
);
const _approve = BookingAction(
  'approve',
  'Approve',
  superAdminOnly: true,
  asksAgreedPrice: true,
  effect: 'The property becomes Reserved on the website straight away.',
);
const _requestPayment = BookingAction(
  'request_payment',
  'Ask for booking amount',
  needsAmount: true,
);
const _recordPayment = BookingAction(
  'record_payment',
  'Record payment',
  needsPayment: true,
);
const _complete = BookingAction(
  'complete',
  'Complete sale',
  superAdminOnly: true,
  effect: 'The property becomes Sold on the website.',
);
const _cancel = BookingAction(
  'cancel',
  'Cancel booking',
  danger: true,
  needsNote: true,
);

/// The buttons a booking shows in its current step (role checked later).
List<BookingAction> actionsFor(BookingStatus status) => switch (status) {
  BookingStatus.requested => [_sendForApproval, _approve, _cancel],
  BookingStatus.pendingApproval => [_approve, _cancel],
  BookingStatus.approved => [_requestPayment, _cancel],
  BookingStatus.paymentPending => [_recordPayment, _cancel],
  BookingStatus.reserved => [_complete, _cancel],
  _ => const [],
};

/// Filters kept in the address (e.g. /bookings?status=pending_approval).
class BookingQuery {
  const BookingQuery({
    this.search = '',
    this.status,
    this.open = true,
    this.propertyId,
    this.page = 1,
  });

  factory BookingQuery.fromUri(Uri uri) {
    final p = uri.queryParameters;
    return BookingQuery(
      search: p['q'] ?? '',
      status: BookingStatus.tryParse(p['status']),
      open: p['all'] != '1',
      propertyId: p['property'],
      page: (int.tryParse(p['page'] ?? '') ?? 1).clamp(1, 100000),
    );
  }

  static const pageSize = 25;

  final String search;
  final BookingStatus? status;

  /// Only bookings still in progress (default), or every booking.
  final bool open;
  final String? propertyId;
  final int page;

  bool get hasFilters =>
      search.isNotEmpty || status != null || !open || propertyId != null;

  Map<String, String> toQueryParameters() => {
    if (search.isNotEmpty) 'q': search,
    if (status != null) 'status': status!.value,
    if (!open) 'all': '1',
    'property': ?propertyId,
    if (page > 1) 'page': '$page',
  };

  String get location => Uri(
    path: '/bookings',
    queryParameters: toQueryParameters().isEmpty ? null : toQueryParameters(),
  ).toString();

  BookingQuery copyWith({
    String? search,
    BookingStatus? Function()? status,
    bool? open,
    String? Function()? propertyId,
    int? page,
  }) => BookingQuery(
    search: search ?? this.search,
    status: status != null ? status() : this.status,
    open: open ?? this.open,
    propertyId: propertyId != null ? propertyId() : this.propertyId,
    page: page ?? 1,
  );

  @override
  bool operator ==(Object other) =>
      other is BookingQuery &&
      other.toQueryParameters().toString() == toQueryParameters().toString();

  @override
  int get hashCode => toQueryParameters().toString().hashCode;
}

class BookingProperty {
  const BookingProperty({
    required this.id,
    required this.code,
    required this.title,
    this.slug,
    required this.publishState,
    required this.availability,
    this.price,
  });

  factory BookingProperty.fromJson(Map<String, dynamic> json) =>
      BookingProperty(
        id: json['id'] as String,
        code: json['code'] as String,
        title: json['title'] as String,
        slug: json['slug'] as String?,
        publishState: json['publish_state'] as String,
        availability: json['availability'] as String,
        price: (json['price'] as num?)?.toDouble(),
      );

  final String id;
  final String code;
  final String title;
  final String? slug;
  final String publishState;
  final String availability;
  final double? price;
}

double? _money(Object? value) => (value as num?)?.toDouble();

class Booking {
  const Booking({
    required this.id,
    required this.reference,
    required this.source,
    required this.name,
    required this.phone,
    this.email,
    this.message,
    required this.status,
    this.agreedPrice,
    this.bookingAmount,
    this.amountReceived,
    this.receivedOn,
    this.paymentMethod,
    this.paymentReference,
    this.assignedTo,
    this.customerId,
    this.siteVisitId,
    this.approvedBy,
    this.approvedAt,
    this.cancelledReason,
    required this.createdAt,
    required this.property,
  });

  factory Booking.fromJson(Map<String, dynamic> json) => Booking(
    id: json['id'] as String,
    reference: json['reference'] as String,
    source: json['source'] as String,
    name: json['name'] as String,
    phone: json['phone'] as String,
    email: json['email'] as String?,
    message: json['message'] as String?,
    status: BookingStatus.parse(json['status'] as String?),
    agreedPrice: _money(json['agreed_price']),
    bookingAmount: _money(json['booking_amount']),
    amountReceived: _money(json['amount_received']),
    receivedOn: json['received_on'] as String?,
    paymentMethod: json['payment_method'] as String?,
    paymentReference: json['payment_reference'] as String?,
    assignedTo: json['assigned_to'] as String?,
    customerId: json['customer_id'] as String?,
    siteVisitId: json['site_visit_id'] as String?,
    approvedBy: json['approved_by'] as String?,
    approvedAt: json['approved_at'] == null
        ? null
        : DateTime.parse(json['approved_at'] as String),
    cancelledReason: json['cancelled_reason'] as String?,
    createdAt: DateTime.parse(json['created_at'] as String),
    property: BookingProperty.fromJson(
      json['property'] as Map<String, dynamic>,
    ),
  );

  static const select =
      'id, reference, source, name, phone, email, message, status, agreed_price, '
      'booking_amount, amount_received, received_on, payment_method, '
      'payment_reference, assigned_to, customer_id, site_visit_id, approved_by, '
      'approved_at, cancelled_reason, created_at, '
      'property:properties(id, code, title, slug, publish_state, availability, price)';

  final String id;
  final String reference;
  final String source;
  final String name;
  final String phone;
  final String? email;
  final String? message;
  final BookingStatus status;
  final double? agreedPrice;
  final double? bookingAmount;
  final double? amountReceived;
  final String? receivedOn;
  final String? paymentMethod;
  final String? paymentReference;
  final String? assignedTo;
  final String? customerId;
  final String? siteVisitId;
  final String? approvedBy;
  final DateTime? approvedAt;
  final String? cancelledReason;
  final DateTime createdAt;
  final BookingProperty property;

  String get phoneLabel => formatIndianMobile(phone);
  String get telLink => 'tel:+91$phone';
  String get whatsappLink {
    final text =
        'Hello ${name.split(' ').first}, this is Avanilands about your booking '
        '$reference for ${property.code}.';
    return 'https://wa.me/91$phone?text=${Uri.encodeComponent(text)}';
  }
}

class BookingNote {
  const BookingNote({
    required this.id,
    this.adminId,
    this.note,
    this.statusFrom,
    this.statusTo,
    this.details = const {},
    required this.createdAt,
  });

  factory BookingNote.fromJson(Map<String, dynamic> json) => BookingNote(
    id: json['id'] as String,
    adminId: json['admin_id'] as String?,
    note: json['note'] as String?,
    statusFrom: BookingStatus.tryParse(json['status_from'] as String?),
    statusTo: BookingStatus.tryParse(json['status_to'] as String?),
    details: (json['details'] as Map?)?.cast<String, dynamic>() ?? const {},
    createdAt: DateTime.parse(json['created_at'] as String),
  );

  final String id;
  final String? adminId;
  final String? note;
  final BookingStatus? statusFrom;
  final BookingStatus? statusTo;
  final Map<String, dynamic> details;
  final DateTime createdAt;

  String headline(String Function(num) rupees) {
    if (statusTo == null) return 'Added a note';
    return switch (statusTo!) {
      BookingStatus.pendingApproval => 'Sent for approval',
      BookingStatus.approved => 'Approved — property reserved',
      BookingStatus.paymentPending =>
        'Asked for booking amount ${details['booking_amount'] is num ? rupees(details['booking_amount'] as num) : ''}'
            .trim(),
      BookingStatus.reserved =>
        'Payment recorded ${details['amount_received'] is num ? rupees(details['amount_received'] as num) : ''}'
            '${details['payment_method'] != null ? ' by ${paymentMethods[details['payment_method']] ?? details['payment_method']}' : ''}'
            '${details['payment_reference'] != null ? ' (ref ${details['payment_reference']})' : ''}',
      BookingStatus.completed => 'Sale completed — property sold',
      BookingStatus.cancelled =>
        statusFrom == null
            ? 'Cancelled'
            : 'Cancelled (was ${statusFrom!.label})',
      BookingStatus.requested => 'Reopened',
    };
  }
}
