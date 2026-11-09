import 'dart:ui';

import '../../core/theme.dart';

/// Dart mirrors of the database enums (supabase/migrations/…_schema.sql).
/// `value` is the database text; `label` is what admins see.

enum PublishState {
  draft('draft', 'Draft'),
  published('published', 'Published'),
  hidden('hidden', 'Hidden'),
  archived('archived', 'Archived');

  const PublishState(this.value, this.label);
  final String value;
  final String label;

  static PublishState parse(String value) =>
      values.firstWhere((item) => item.value == value);

  Color get color => switch (this) {
    draft => BrandColors.sand,
    published => BrandColors.available,
    hidden => BrandColors.reserved,
    archived => BrandColors.sold,
  };
}

enum Availability {
  available('available', 'Available'),
  reserved('reserved', 'Reserved'),
  sold('sold', 'Sold');

  const Availability(this.value, this.label);
  final String value;
  final String label;

  static Availability parse(String value) =>
      values.firstWhere((item) => item.value == value);

  Color get color => switch (this) {
    available => BrandColors.available,
    reserved => BrandColors.reserved,
    sold => BrandColors.sold,
  };
}

enum AreaUnit {
  sqFt('sq_ft', 'sq ft', 1),
  sqYd('sq_yd', 'sq yd', 9),
  sqM('sq_m', 'sq m', 10.7639),
  cent('cent', 'cents', 435.6),
  gunta('gunta', 'guntas', 1089),
  acre('acre', 'acres', 43560);

  const AreaUnit(this.value, this.label, this.sqftFactor);
  final String value;
  final String label;

  /// Square feet in one unit (same table as the database's area_to_sqft).
  final double sqftFactor;

  static AreaUnit parse(String value) =>
      values.firstWhere((item) => item.value == value);

  double toSqft(double amount) => amount * sqftFactor;
}

enum PriceType {
  total('total', 'Fixed price'),
  onRequest('on_request', 'Price on request');

  const PriceType(this.value, this.label);
  final String value;
  final String label;

  static PriceType parse(String value) =>
      values.firstWhere((item) => item.value == value);
}

enum Facing {
  north('north', 'North'),
  south('south', 'South'),
  east('east', 'East'),
  west('west', 'West'),
  northEast('north_east', 'North-east'),
  northWest('north_west', 'North-west'),
  southEast('south_east', 'South-east'),
  southWest('south_west', 'South-west');

  const Facing(this.value, this.label);
  final String value;
  final String label;

  static Facing? tryParse(String? value) =>
      values.where((item) => item.value == value).firstOrNull;
}

enum ApprovalType {
  dtcp('dtcp', 'DTCP'),
  vmrda('vmrda', 'VMRDA'),
  hmda('hmda', 'HMDA'),
  apcrda('apcrda', 'APCRDA'),
  panchayat('panchayat', 'Panchayat'),
  rera('rera', 'RERA'),
  other('other', 'Other approval'),
  notApplicable('not_applicable', 'Not applicable');

  const ApprovalType(this.value, this.label);
  final String value;
  final String label;

  static ApprovalType parse(String value) =>
      values.firstWhere((item) => item.value == value);
}

enum NearbyCategory {
  school('school', 'School'),
  college('college', 'College'),
  hospital('hospital', 'Hospital'),
  busStop('bus_stop', 'Bus stop'),
  railwayStation('railway_station', 'Railway station'),
  airport('airport', 'Airport'),
  highway('highway', 'Highway'),
  market('market', 'Market'),
  landmark('landmark', 'Landmark'),
  other('other', 'Other');

  const NearbyCategory(this.value, this.label);
  final String value;
  final String label;

  static NearbyCategory parse(String value) =>
      values.firstWhere((item) => item.value == value, orElse: () => other);
}
