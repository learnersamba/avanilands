import 'package:flutter/material.dart';

import '../../core/formatting.dart';
import '../../core/theme.dart';

enum EnquiryStatus {
  newEnquiry('new', 'New'),
  contacted('contacted', 'Contacted'),
  followUp('follow_up', 'Follow up'),
  interested('interested', 'Interested'),
  notInterested('not_interested', 'Not interested'),
  converted('converted', 'Converted'),
  closed('closed', 'Closed');

  const EnquiryStatus(this.value, this.label);
  final String value;
  final String label;

  static EnquiryStatus parse(String? value) => values.firstWhere(
    (item) => item.value == value,
    orElse: () => newEnquiry,
  );

  static EnquiryStatus? tryParse(String? value) {
    for (final item in values) {
      if (item.value == value) return item;
    }
    return null;
  }

  Color get color => switch (this) {
    newEnquiry => BrandColors.sand,
    contacted || followUp => BrandColors.reserved,
    interested || converted => BrandColors.available,
    _ => BrandColors.sold,
  };
}

enum EnquiryRange {
  all('all', 'Any time', null),
  today('today', 'Last 24 hours', Duration(days: 1)),
  week('7d', 'Last 7 days', Duration(days: 7)),
  month('30d', 'Last 30 days', Duration(days: 30)),
  quarter('90d', 'Last 90 days', Duration(days: 90));

  const EnquiryRange(this.value, this.label, this.duration);
  final String value;
  final String label;
  final Duration? duration;

  static EnquiryRange parse(String? value) =>
      values.firstWhere((item) => item.value == value, orElse: () => all);
}

enum EnquiryAssignee {
  anyone('', 'Anyone'),
  me('me', 'Assigned to me'),
  nobody('none', 'Unassigned');

  const EnquiryAssignee(this.value, this.label);
  final String value;
  final String label;

  static EnquiryAssignee parse(String? value) =>
      values.firstWhere((item) => item.value == value, orElse: () => anyone);
}

/// List filters. Kept in the page address (e.g. /enquiries?status=new).
class EnquiryQuery {
  const EnquiryQuery({
    this.search = '',
    this.status,
    this.propertyId,
    this.range = EnquiryRange.all,
    this.assignee = EnquiryAssignee.anyone,
    this.page = 1,
  });

  factory EnquiryQuery.fromUri(Uri uri) {
    final p = uri.queryParameters;
    return EnquiryQuery(
      search: p['q'] ?? '',
      status: EnquiryStatus.tryParse(p['status']),
      propertyId: p['property'],
      range: EnquiryRange.parse(p['range']),
      assignee: EnquiryAssignee.parse(p['assigned']),
      page: (int.tryParse(p['page'] ?? '') ?? 1).clamp(1, 100000),
    );
  }

  static const pageSize = 25;

  final String search;
  final EnquiryStatus? status;
  final String? propertyId;
  final EnquiryRange range;
  final EnquiryAssignee assignee;
  final int page;

  bool get hasFilters =>
      search.isNotEmpty ||
      status != null ||
      propertyId != null ||
      range != EnquiryRange.all ||
      assignee != EnquiryAssignee.anyone;

  Map<String, String> toQueryParameters() => {
    if (search.isNotEmpty) 'q': search,
    if (status != null) 'status': status!.value,
    'property': ?propertyId,
    if (range != EnquiryRange.all) 'range': range.value,
    if (assignee != EnquiryAssignee.anyone) 'assigned': assignee.value,
    if (page > 1) 'page': '$page',
  };

  String get location => Uri(
    path: '/enquiries',
    queryParameters: toQueryParameters().isEmpty ? null : toQueryParameters(),
  ).toString();

  /// A changed copy; changing any filter goes back to page 1.
  EnquiryQuery copyWith({
    String? search,
    EnquiryStatus? Function()? status,
    String? Function()? propertyId,
    EnquiryRange? range,
    EnquiryAssignee? assignee,
    int? page,
  }) => EnquiryQuery(
    search: search ?? this.search,
    status: status != null ? status() : this.status,
    propertyId: propertyId != null ? propertyId() : this.propertyId,
    range: range ?? this.range,
    assignee: assignee ?? this.assignee,
    page: page ?? 1,
  );

  @override
  bool operator ==(Object other) =>
      other is EnquiryQuery &&
      other.toQueryParameters().toString() == toQueryParameters().toString();

  @override
  int get hashCode => toQueryParameters().toString().hashCode;
}

/// The digits to look for when someone types a phone number in the search,
/// without the +91 / 0 prefix. Null when it isn't a phone search.
String? phoneSearchDigits(String text) {
  if (RegExp(r'[A-Za-z]').hasMatch(text)) return null;
  var digits = text.replaceAll(RegExp(r'\D'), '');
  if (digits.length < 4) return null;
  if (digits.length == 12 && digits.startsWith('91')) {
    digits = digits.substring(2);
  } else if (digits.length == 11 && digits.startsWith('0')) {
    digits = digits.substring(1);
  }
  return digits;
}

/// How the customer would like to be contacted.
String contactMethodLabel(String value) => switch (value) {
  'whatsapp' => 'WhatsApp',
  'email' => 'Email',
  _ => 'Phone call',
};

/// "9012345678" → "+91 90123 45678".
String formatIndianMobile(String phone) => phone.length == 10
    ? '+91 ${phone.substring(0, 5)} ${phone.substring(5)}'
    : phone;

class EnquiryProperty {
  const EnquiryProperty({
    required this.id,
    required this.code,
    required this.title,
    this.slug,
    required this.publishState,
    required this.availability,
  });

  factory EnquiryProperty.fromJson(Map<String, dynamic> json) =>
      EnquiryProperty(
        id: json['id'] as String,
        code: json['code'] as String,
        title: json['title'] as String,
        slug: json['slug'] as String?,
        publishState: json['publish_state'] as String,
        availability: json['availability'] as String,
      );

  final String id;
  final String code;
  final String title;
  final String? slug;
  final String publishState;
  final String availability;
}

class Enquiry {
  const Enquiry({
    required this.id,
    required this.reference,
    required this.name,
    required this.phone,
    this.email,
    required this.preferredContact,
    this.message,
    required this.status,
    required this.source,
    this.assignedTo,
    required this.createdAt,
    this.lastContactedAt,
    this.property,
    this.customerId,
  });

  factory Enquiry.fromJson(Map<String, dynamic> json) {
    final property = json['property'] as Map<String, dynamic>?;
    return Enquiry(
      id: json['id'] as String,
      reference: json['reference'] as String,
      name: json['name'] as String,
      phone: json['phone'] as String,
      email: json['email'] as String?,
      preferredContact: json['preferred_contact'] as String,
      message: json['message'] as String?,
      status: EnquiryStatus.parse(json['status'] as String?),
      source: json['source'] as String,
      assignedTo: json['assigned_to'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      lastContactedAt: json['last_contacted_at'] == null
          ? null
          : DateTime.parse(json['last_contacted_at'] as String),
      property: property == null ? null : EnquiryProperty.fromJson(property),
      customerId: json['customer_id'] as String?,
    );
  }

  static const select =
      'id, reference, name, phone, email, preferred_contact, message, status, '
      'source, assigned_to, created_at, last_contacted_at, customer_id, '
      'property:properties(id, code, title, slug, publish_state, availability)';

  final String id;
  final String reference;
  final String name;
  final String phone;
  final String? email;
  final String preferredContact;
  final String? message;
  final EnquiryStatus status;
  final String source;
  final String? assignedTo;
  final DateTime createdAt;
  final DateTime? lastContactedAt;
  final EnquiryProperty? property;

  /// Set when the customer has an account on the website (Phase 11).
  final String? customerId;

  String get propertyLabel => property?.code ?? 'General enquiry';

  String get telLink => 'tel:+91$phone';

  /// WhatsApp chat with a friendly first line already typed.
  String get whatsappLink {
    final about = property == null
        ? 'your enquiry ($reference)'
        : 'your enquiry about ${property!.code} ($reference)';
    final text =
        'Hello ${name.split(' ').first}, this is Avanilands about $about.';
    return 'https://wa.me/91$phone?text=${Uri.encodeComponent(text)}';
  }

  String? get mailLink => email == null
      ? null
      : Uri(
          scheme: 'mailto',
          path: email,
          query: 'subject=${Uri.encodeComponent('Your enquiry $reference')}',
        ).toString();
}

class EnquiryNote {
  const EnquiryNote({
    required this.id,
    this.adminId,
    this.note,
    this.statusFrom,
    this.statusTo,
    required this.createdAt,
  });

  factory EnquiryNote.fromJson(Map<String, dynamic> json) => EnquiryNote(
    id: json['id'] as String,
    adminId: json['admin_id'] as String?,
    note: json['note'] as String?,
    statusFrom: EnquiryStatus.tryParse(json['status_from'] as String?),
    statusTo: EnquiryStatus.tryParse(json['status_to'] as String?),
    createdAt: DateTime.parse(json['created_at'] as String),
  );

  final String id;
  final String? adminId;
  final String? note;
  final EnquiryStatus? statusFrom;
  final EnquiryStatus? statusTo;
  final DateTime createdAt;

  /// "Changed status from New to Contacted" or "Added a note".
  String get headline => statusTo != null
      ? 'Changed status from ${statusFrom?.label ?? '?'} to ${statusTo!.label}'
      : 'Added a note';
}

/// CSV for spreadsheets. Cells that start like a formula are prefixed with
/// an apostrophe so Excel shows them as text instead of running them.
String toCsv(List<List<Object?>> rows) {
  String cell(Object? value) {
    var text = value?.toString() ?? '';
    if (RegExp(r'^[=+\-@\t\r]').hasMatch(text)) text = "'$text";
    if (RegExp(r'[",\r\n]').hasMatch(text)) {
      text = '"${text.replaceAll('"', '""')}"';
    }
    return text;
  }

  return rows.map((row) => row.map(cell).join(',')).join('\r\n');
}

/// One spreadsheet row per enquiry, with a header row first.
List<List<Object?>> enquiryCsvRows(
  List<Enquiry> enquiries,
  Map<String, String> adminNames,
) => [
  [
    'Reference',
    'Received',
    'Name',
    'Phone',
    'Email',
    'Preferred contact',
    'Property code',
    'Property',
    'Status',
    'Assigned to',
    'Last contacted',
    'Source',
    'Message',
  ],
  for (final e in enquiries)
    [
      e.reference,
      formatDateTime(e.createdAt),
      e.name,
      formatIndianMobile(e.phone),
      e.email,
      contactMethodLabel(e.preferredContact),
      e.property?.code,
      e.property?.title,
      e.status.label,
      e.assignedTo == null ? '' : (adminNames[e.assignedTo] ?? 'Former admin'),
      e.lastContactedAt == null ? '' : formatDateTime(e.lastContactedAt!),
      humanize(e.source),
      e.message,
    ],
];
