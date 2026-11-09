import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/theme.dart';
import '../enquiries/enquiry_models.dart' show formatIndianMobile;

enum SiteVisitStatus {
  requested('requested', 'Requested'),
  confirmed('confirmed', 'Confirmed'),
  completed('completed', 'Completed'),
  noShow('no_show', 'No-show'),
  cancelled('cancelled', 'Cancelled');

  const SiteVisitStatus(this.value, this.label);
  final String value;
  final String label;

  static SiteVisitStatus parse(String? value) =>
      values.firstWhere((item) => item.value == value, orElse: () => requested);

  static SiteVisitStatus? tryParse(String? value) {
    for (final item in values) {
      if (item.value == value) return item;
    }
    return null;
  }

  bool get isOpen => this == requested || this == confirmed;

  Color get color => switch (this) {
    requested => BrandColors.sand,
    confirmed => BrandColors.reserved,
    completed => BrandColors.available,
    _ => BrandColors.sold,
  };
}

/// What the list shows (by visit date, India time).
enum SiteVisitWhen {
  upcoming('upcoming', 'Today and later'),
  today('today', 'Today'),
  week('week', 'Next 7 days'),
  past('past', 'Past'),
  all('all', 'Any date');

  const SiteVisitWhen(this.value, this.label);
  final String value;
  final String label;

  static SiteVisitWhen parse(String? value) =>
      values.firstWhere((item) => item.value == value, orElse: () => upcoming);
}

/// List filters, kept in the address (e.g. /site-visits?status=requested).
class SiteVisitQuery {
  const SiteVisitQuery({
    this.search = '',
    this.status,
    this.when = SiteVisitWhen.upcoming,
    this.date,
    this.propertyId,
    this.mine = false,
    this.page = 1,
  });

  factory SiteVisitQuery.fromUri(Uri uri) {
    final p = uri.queryParameters;
    return SiteVisitQuery(
      search: p['q'] ?? '',
      status: SiteVisitStatus.tryParse(p['status']),
      when: SiteVisitWhen.parse(p['when']),
      date: DateTime.tryParse(p['date'] ?? '') == null ? null : p['date'],
      propertyId: p['property'],
      mine: p['mine'] == '1',
      page: (int.tryParse(p['page'] ?? '') ?? 1).clamp(1, 100000),
    );
  }

  static const pageSize = 25;

  final String search;
  final SiteVisitStatus? status;
  final SiteVisitWhen when;

  /// One day ("YYYY-MM-DD"), chosen in the calendar. Overrides [when].
  final String? date;
  final String? propertyId;
  final bool mine;
  final int page;

  bool get hasFilters =>
      search.isNotEmpty ||
      status != null ||
      when != SiteVisitWhen.upcoming ||
      date != null ||
      propertyId != null ||
      mine;

  Map<String, String> toQueryParameters() => {
    if (search.isNotEmpty) 'q': search,
    if (status != null) 'status': status!.value,
    if (when != SiteVisitWhen.upcoming) 'when': when.value,
    'date': ?date,
    'property': ?propertyId,
    if (mine) 'mine': '1',
    if (page > 1) 'page': '$page',
  };

  String get location => Uri(
    path: '/site-visits',
    queryParameters: toQueryParameters().isEmpty ? null : toQueryParameters(),
  ).toString();

  /// A changed copy; changing any filter goes back to page 1.
  SiteVisitQuery copyWith({
    String? search,
    SiteVisitStatus? Function()? status,
    SiteVisitWhen? when,
    String? Function()? date,
    String? Function()? propertyId,
    bool? mine,
    int? page,
  }) => SiteVisitQuery(
    search: search ?? this.search,
    status: status != null ? status() : this.status,
    when: when ?? this.when,
    date: date != null ? date() : this.date,
    propertyId: propertyId != null ? propertyId() : this.propertyId,
    mine: mine ?? this.mine,
    page: page ?? 1,
  );

  @override
  bool operator ==(Object other) =>
      other is SiteVisitQuery &&
      other.toQueryParameters().toString() == toQueryParameters().toString();

  @override
  int get hashCode => toQueryParameters().toString().hashCode;
}

/// Today's date in India as "YYYY-MM-DD" (visits are in India time).
String indiaToday([DateTime? now]) => dateKey(
  (now ?? DateTime.now()).toUtc().add(const Duration(hours: 5, minutes: 30)),
);

String dateKey(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

String addDaysKey(String date, int days) {
  final value = DateTime.utc(
    int.parse(date.substring(0, 4)),
    int.parse(date.substring(5, 7)),
    int.parse(date.substring(8, 10)),
  ).add(Duration(days: days));
  return dateKey(value);
}

/// "2026-11-14" → "Sat, 14 Nov 2026"
String formatVisitDay(String date, {bool year = true}) =>
    DateFormat(year ? 'EEE, d MMM y' : 'EEE, d MMM')
        .format(DateTime.parse(date));

/// "15:00" → "3:00 pm"
String formatVisitSlot(String slot) {
  final parts = slot.split(':');
  final hours = int.parse(parts[0]);
  final suffix = hours >= 12 ? 'pm' : 'am';
  final hour12 = hours % 12 == 0 ? 12 : hours % 12;
  return '$hour12:${parts[1]} $suffix';
}

class SiteVisitProperty {
  const SiteVisitProperty({
    required this.id,
    required this.code,
    required this.title,
    this.slug,
    required this.publishState,
    required this.availability,
    this.locality,
    this.city,
  });

  factory SiteVisitProperty.fromJson(Map<String, dynamic> json) {
    final location = json['location'] as Map<String, dynamic>?;
    return SiteVisitProperty(
      id: json['id'] as String,
      code: json['code'] as String,
      title: json['title'] as String,
      slug: json['slug'] as String?,
      publishState: json['publish_state'] as String,
      availability: json['availability'] as String,
      locality: json['locality'] as String?,
      city: location?['city'] as String?,
    );
  }

  final String id;
  final String code;
  final String title;
  final String? slug;
  final String publishState;
  final String availability;
  final String? locality;
  final String? city;

  String get place => [
    locality,
    city,
  ].whereType<String>().where((s) => s.isNotEmpty).join(', ');
}

class SiteVisit {
  const SiteVisit({
    required this.id,
    required this.reference,
    required this.name,
    required this.phone,
    this.email,
    required this.visitors,
    required this.visitDate,
    required this.slot,
    this.message,
    required this.status,
    this.assignedTo,
    required this.createdAt,
    this.reminderSentAt,
    required this.property,
    this.customerId,
  });

  factory SiteVisit.fromJson(Map<String, dynamic> json) => SiteVisit(
    id: json['id'] as String,
    reference: json['reference'] as String,
    name: json['name'] as String,
    phone: json['phone'] as String,
    email: json['email'] as String?,
    visitors: (json['visitors'] as num).toInt(),
    visitDate: json['visit_date'] as String,
    slot: json['slot'] as String,
    message: json['message'] as String?,
    status: SiteVisitStatus.parse(json['status'] as String?),
    assignedTo: json['assigned_to'] as String?,
    createdAt: DateTime.parse(json['created_at'] as String),
    reminderSentAt: json['reminder_sent_at'] == null
        ? null
        : DateTime.parse(json['reminder_sent_at'] as String),
    property: SiteVisitProperty.fromJson(
      json['property'] as Map<String, dynamic>,
    ),
    customerId: json['customer_id'] as String?,
  );

  static const select =
      'id, reference, name, phone, email, visitors, visit_date, slot, message, '
      'status, assigned_to, created_at, reminder_sent_at, customer_id, '
      'property:properties(id, code, title, slug, publish_state, availability, '
      'locality, location:locations(city))';

  final String id;
  final String reference;
  final String name;
  final String phone;
  final String? email;
  final int visitors;
  final String visitDate;
  final String slot;
  final String? message;
  final SiteVisitStatus status;
  final String? assignedTo;
  final DateTime createdAt;
  final DateTime? reminderSentAt;
  final SiteVisitProperty property;

  /// Set when the customer has an account on the website (Phase 11).
  final String? customerId;

  String get when => '${formatVisitDay(visitDate)}, ${formatVisitSlot(slot)}';

  String get people => '$visitors ${visitors == 1 ? 'person' : 'people'}';

  /// Still to happen (or today).
  bool isUpcoming(String today) => visitDate.compareTo(today) >= 0;

  /// Confirmed and the day has come: can be marked completed / no-show.
  bool canFinish(String today) =>
      status == SiteVisitStatus.confirmed && visitDate.compareTo(today) <= 0;

  String get telLink => 'tel:+91$phone';

  String get whatsappLink {
    final text =
        'Hello ${name.split(' ').first}, this is Avanilands about your site '
        'visit to ${property.code} on ${formatVisitDay(visitDate, year: false)} '
        'at ${formatVisitSlot(slot)} ($reference).';
    return 'https://wa.me/91$phone?text=${Uri.encodeComponent(text)}';
  }

  String? get mailLink => email == null
      ? null
      : Uri(
          scheme: 'mailto',
          path: email,
          query: 'subject=${Uri.encodeComponent('Your site visit $reference')}',
        ).toString();

  String get phoneLabel => formatIndianMobile(phone);
}

class SiteVisitNote {
  const SiteVisitNote({
    required this.id,
    this.adminId,
    this.note,
    this.statusFrom,
    this.statusTo,
    this.movedFrom,
    this.movedTo,
    required this.createdAt,
  });

  factory SiteVisitNote.fromJson(Map<String, dynamic> json) => SiteVisitNote(
    id: json['id'] as String,
    adminId: json['admin_id'] as String?,
    note: json['note'] as String?,
    statusFrom: SiteVisitStatus.tryParse(json['status_from'] as String?),
    statusTo: SiteVisitStatus.tryParse(json['status_to'] as String?),
    movedFrom: json['moved_from'] as String?,
    movedTo: json['moved_to'] as String?,
    createdAt: DateTime.parse(json['created_at'] as String),
  );

  final String id;
  final String? adminId;
  final String? note;
  final SiteVisitStatus? statusFrom;
  final SiteVisitStatus? statusTo;
  final String? movedFrom;
  final String? movedTo;
  final DateTime createdAt;

  String get headline {
    if (movedTo != null) {
      return 'Moved from ${_moment(movedFrom)} to ${_moment(movedTo)}';
    }
    if (statusTo != null) {
      return switch (statusTo!) {
        SiteVisitStatus.confirmed => 'Confirmed the visit',
        SiteVisitStatus.completed => 'Marked the visit completed',
        SiteVisitStatus.noShow => 'Marked as no-show',
        SiteVisitStatus.cancelled => 'Cancelled the visit',
        SiteVisitStatus.requested => 'Reopened the visit',
      };
    }
    return 'Added a note';
  }

  /// "2026-11-14 10:00" → "Sat, 14 Nov, 10:00 am"
  static String _moment(String? value) {
    if (value == null || value.length < 16) return '?';
    return '${formatVisitDay(value.substring(0, 10), year: false)}, ${formatVisitSlot(value.substring(11, 16))}';
  }
}

/// Visit booking settings (part of site_settings).
class VisitSettings {
  const VisitSettings({
    required this.days,
    required this.slots,
    required this.closedDates,
    required this.daysAhead,
  });

  factory VisitSettings.fromJson(Map<String, dynamic> json) => VisitSettings(
    days: ((json['visit_days'] as List?) ?? const [1, 2, 3, 4, 5, 6])
        .map((d) => (d as num).toInt())
        .toSet(),
    slots: ((json['visit_slots'] as List?) ?? const ['10:00'])
        .cast<String>()
        .toList(),
    closedDates: ((json['visit_closed_dates'] as List?) ?? const [])
        .cast<String>()
        .toList(),
    daysAhead: (json['visit_days_ahead'] as num?)?.toInt() ?? 30,
  );

  static const columns =
      'visit_days, visit_slots, visit_closed_dates, visit_days_ahead';

  /// ISO weekdays: 1 = Monday … 7 = Sunday.
  final Set<int> days;
  final List<String> slots;
  final List<String> closedDates;
  final int daysAhead;

  Map<String, dynamic> toJson() => {
    'visit_days': (days.toList()..sort()),
    'visit_slots': (slots.toList()..sort()),
    'visit_closed_dates': (closedDates.toList()..sort()),
    'visit_days_ahead': daysAhead,
  };
}

const weekdayNames = {
  1: 'Mon',
  2: 'Tue',
  3: 'Wed',
  4: 'Thu',
  5: 'Fri',
  6: 'Sat',
  7: 'Sun',
};

/// "9:30", "09:30", "9.30" → "09:30"; null if not a time.
String? normalizeSlot(String input) {
  final match = RegExp(r'^\s*(\d{1,2})[:.](\d{2})\s*$').firstMatch(input);
  if (match == null) return null;
  final hours = int.parse(match.group(1)!);
  final minutes = int.parse(match.group(2)!);
  if (hours > 23 || minutes > 59) return null;
  return '${hours.toString().padLeft(2, '0')}:${match.group(2)}';
}

/// The month grid for the calendar: weeks starting Monday, days outside the
/// month are null.
List<List<String?>> monthGrid(int year, int month) {
  final first = DateTime.utc(year, month);
  final days = DateTime.utc(year, month + 1, 0).day;
  final lead = first.weekday - 1;
  final cells = <String?>[
    for (var i = 0; i < lead; i++) null,
    for (var day = 1; day <= days; day++)
      dateKey(DateTime.utc(year, month, day)),
  ];
  while (cells.length % 7 != 0) {
    cells.add(null);
  }
  return [for (var i = 0; i < cells.length; i += 7) cells.sublist(i, i + 7)];
}
