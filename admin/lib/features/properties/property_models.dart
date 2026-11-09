import 'property_enums.dart';

double? _num(Object? value) => switch (value) {
  final num n => n.toDouble(),
  final String s => double.tryParse(s),
  _ => null,
};

/// One row of the property list.
class PropertyListItem {
  const PropertyListItem({
    required this.id,
    required this.code,
    required this.title,
    required this.slug,
    required this.typeName,
    required this.city,
    required this.locality,
    required this.areaValue,
    required this.areaUnit,
    required this.priceType,
    required this.price,
    required this.publishState,
    required this.availability,
    required this.isFeatured,
    required this.updatedAt,
    required this.coverThumb,
  });

  /// Columns for [PropertiesRepository.list].
  static const select =
      'id, code, title, slug, locality, area_value, area_unit, price_type, price, '
      'publish_state, availability, is_featured, updated_at, '
      'type:property_types(name), location:locations(city), cover:property_images(path_thumb)';

  factory PropertyListItem.fromJson(Map<String, dynamic> json) {
    final covers = (json['cover'] as List?) ?? const [];
    return PropertyListItem(
      id: json['id'] as String,
      code: json['code'] as String,
      title: json['title'] as String,
      slug: json['slug'] as String?,
      typeName: (json['type'] as Map?)?['name'] as String? ?? '',
      city: (json['location'] as Map?)?['city'] as String? ?? '',
      locality: json['locality'] as String?,
      areaValue: _num(json['area_value']),
      areaUnit: AreaUnit.parse(json['area_unit'] as String),
      priceType: PriceType.parse(json['price_type'] as String),
      price: _num(json['price']),
      publishState: PublishState.parse(json['publish_state'] as String),
      availability: Availability.parse(json['availability'] as String),
      isFeatured: json['is_featured'] as bool,
      updatedAt: DateTime.parse(json['updated_at'] as String),
      coverThumb: covers.isEmpty
          ? null
          : (covers.first as Map)['path_thumb'] as String?,
    );
  }

  final String id;
  final String code;
  final String title;
  final String? slug;
  final String typeName;
  final String city;
  final String? locality;
  final double? areaValue;
  final AreaUnit areaUnit;
  final PriceType priceType;
  final double? price;
  final PublishState publishState;
  final Availability availability;
  final bool isFeatured;
  final DateTime updatedAt;
  final String? coverThumb;
}

class NearbyPlace {
  const NearbyPlace({
    this.id,
    required this.name,
    required this.category,
    this.distanceKm,
    this.sortOrder = 0,
  });

  factory NearbyPlace.fromJson(Map<String, dynamic> json) => NearbyPlace(
    id: json['id'] as String,
    name: json['name'] as String,
    category: NearbyCategory.parse(json['category'] as String),
    distanceKm: _num(json['distance_km']),
    sortOrder: json['sort_order'] as int? ?? 0,
  );

  /// Null until saved.
  final String? id;
  final String name;
  final NearbyCategory category;
  final double? distanceKm;
  final int sortOrder;

  Map<String, dynamic> toJson(String propertyId, int order) => {
    'property_id': propertyId,
    'name': name.trim(),
    'category': category.value,
    'distance_km': distanceKm,
    'sort_order': order,
  };

  bool sameAs(NearbyPlace other) =>
      name.trim() == other.name.trim() &&
      category == other.category &&
      distanceKm == other.distanceKm;
}

/// Everything the editor needs about one property.
class PropertyDetail {
  const PropertyDetail({
    required this.id,
    required this.code,
    required this.fields,
    required this.amenityIds,
    required this.nearby,
    required this.imageCount,
    required this.hasCover,
  });

  static const select =
      '*, amenities:property_amenities(amenity_id), '
      'nearby:property_nearby_places(id, name, category, distance_km, sort_order), '
      'images:property_images(id, is_cover)';

  factory PropertyDetail.fromJson(Map<String, dynamic> json) {
    final images = (json['images'] as List?) ?? const [];
    final nearby =
        ((json['nearby'] as List?) ?? const [])
            .map((row) => NearbyPlace.fromJson(row as Map<String, dynamic>))
            .toList()
          ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return PropertyDetail(
      id: json['id'] as String,
      code: json['code'] as String,
      fields: PropertyFields.fromJson(json),
      amenityIds: {
        for (final row in (json['amenities'] as List?) ?? const [])
          (row as Map)['amenity_id'] as int,
      },
      nearby: nearby,
      imageCount: images.length,
      hasCover: images.any((row) => (row as Map)['is_cover'] == true),
    );
  }

  final String id;
  final String code;
  final PropertyFields fields;
  final Set<int> amenityIds;
  final List<NearbyPlace> nearby;
  final int imageCount;
  final bool hasCover;
}

/// The columns admins edit in the property form. Status columns are changed
/// separately (publish state, availability) so each change is deliberate.
class PropertyFields {
  const PropertyFields({
    this.title = '',
    this.propertyTypeId,
    this.description,
    this.locationId,
    this.locality,
    this.address,
    this.pincode,
    this.latitude,
    this.longitude,
    this.showExactLocation = false,
    this.areaValue,
    this.areaUnit = AreaUnit.sqYd,
    this.lengthFt,
    this.widthFt,
    this.dimensionsText,
    this.priceType = PriceType.total,
    this.price,
    this.pricePerUnit,
    this.pricePerUnitUnit,
    this.isNegotiable = false,
    this.facing,
    this.roadWidthFt,
    this.isCorner = false,
    this.waterAvailable,
    this.waterSource,
    this.electricityAvailable,
    this.approvalType = ApprovalType.notApplicable,
    this.approvalNumber,
    this.reraNumber,
    this.legalNotes,
    this.internalNotes,
    this.highlights = const [],
    this.isFeatured = false,
    this.featuredRank,
    this.seoTitle,
    this.seoDescription,
    this.slug,
    this.publishState = PublishState.draft,
    this.availability = Availability.available,
    this.publishedAt,
    this.updatedAt,
  });

  factory PropertyFields.fromJson(Map<String, dynamic> json) => PropertyFields(
    title: json['title'] as String,
    propertyTypeId: json['property_type_id'] as int?,
    description: json['description'] as String?,
    locationId: json['location_id'] as String?,
    locality: json['locality'] as String?,
    address: json['address'] as String?,
    pincode: json['pincode'] as String?,
    latitude: _num(json['latitude']),
    longitude: _num(json['longitude']),
    showExactLocation: json['show_exact_location'] as bool? ?? false,
    areaValue: _num(json['area_value']),
    areaUnit: AreaUnit.parse(json['area_unit'] as String),
    lengthFt: _num(json['length_ft']),
    widthFt: _num(json['width_ft']),
    dimensionsText: json['dimensions_text'] as String?,
    priceType: PriceType.parse(json['price_type'] as String),
    price: _num(json['price']),
    pricePerUnit: _num(json['price_per_unit']),
    pricePerUnitUnit: json['price_per_unit_unit'] == null
        ? null
        : AreaUnit.parse(json['price_per_unit_unit'] as String),
    isNegotiable: json['is_negotiable'] as bool? ?? false,
    facing: Facing.tryParse(json['facing'] as String?),
    roadWidthFt: _num(json['road_width_ft']),
    isCorner: json['is_corner'] as bool? ?? false,
    waterAvailable: json['water_available'] as bool?,
    waterSource: json['water_source'] as String?,
    electricityAvailable: json['electricity_available'] as bool?,
    approvalType: ApprovalType.parse(json['approval_type'] as String),
    approvalNumber: json['approval_number'] as String?,
    reraNumber: json['rera_number'] as String?,
    legalNotes: json['legal_notes'] as String?,
    internalNotes: json['internal_notes'] as String?,
    highlights: ((json['highlights'] as List?) ?? const []).cast<String>(),
    isFeatured: json['is_featured'] as bool? ?? false,
    featuredRank: json['featured_rank'] as int?,
    seoTitle: json['seo_title'] as String?,
    seoDescription: json['seo_description'] as String?,
    slug: json['slug'] as String?,
    publishState: PublishState.parse(json['publish_state'] as String),
    availability: Availability.parse(json['availability'] as String),
    publishedAt: json['published_at'] == null
        ? null
        : DateTime.parse(json['published_at'] as String),
    updatedAt: json['updated_at'] == null
        ? null
        : DateTime.parse(json['updated_at'] as String),
  );

  final String title;
  final int? propertyTypeId;
  final String? description;
  final String? locationId;
  final String? locality;
  final String? address;
  final String? pincode;
  final double? latitude;
  final double? longitude;
  final bool showExactLocation;
  final double? areaValue;
  final AreaUnit areaUnit;
  final double? lengthFt;
  final double? widthFt;
  final String? dimensionsText;
  final PriceType priceType;
  final double? price;
  final double? pricePerUnit;
  final AreaUnit? pricePerUnitUnit;
  final bool isNegotiable;
  final Facing? facing;
  final double? roadWidthFt;
  final bool isCorner;
  final bool? waterAvailable;
  final String? waterSource;
  final bool? electricityAvailable;
  final ApprovalType approvalType;
  final String? approvalNumber;
  final String? reraNumber;
  final String? legalNotes;
  final String? internalNotes;
  final List<String> highlights;
  final bool isFeatured;
  final int? featuredRank;
  final String? seoTitle;
  final String? seoDescription;
  final String? slug;

  // Read-only here.
  final PublishState publishState;
  final Availability availability;
  final DateTime? publishedAt;
  final DateTime? updatedAt;

  /// The editable columns, as sent to the database.
  Map<String, dynamic> toJson() => {
    'title': title.trim(),
    'property_type_id': propertyTypeId,
    'description': _blank(description),
    'location_id': locationId,
    'locality': _blank(locality),
    'address': _blank(address),
    'pincode': _blank(pincode),
    'latitude': latitude,
    'longitude': longitude,
    'show_exact_location': showExactLocation,
    'area_value': areaValue,
    'area_unit': areaUnit.value,
    'length_ft': lengthFt,
    'width_ft': widthFt,
    'dimensions_text': _blank(dimensionsText),
    'price_type': priceType.value,
    'price': priceType == PriceType.total ? price : null,
    'price_per_unit': priceType == PriceType.total ? pricePerUnit : null,
    'price_per_unit_unit': priceType == PriceType.total && pricePerUnit != null
        ? (pricePerUnitUnit ?? areaUnit).value
        : null,
    'is_negotiable': isNegotiable,
    'facing': facing?.value,
    'road_width_ft': roadWidthFt,
    'is_corner': isCorner,
    'water_available': waterAvailable,
    'water_source': _blank(waterSource),
    'electricity_available': electricityAvailable,
    'approval_type': approvalType.value,
    'approval_number': _blank(approvalNumber),
    'rera_number': _blank(reraNumber),
    'legal_notes': _blank(legalNotes),
    'internal_notes': _blank(internalNotes),
    'highlights': [
      for (final h in highlights)
        if (h.trim().isNotEmpty) h.trim(),
    ],
    'is_featured': isFeatured,
    'featured_rank': isFeatured ? featuredRank : null,
    'seo_title': _blank(seoTitle),
    'seo_description': _blank(seoDescription),
    'slug': _blank(slug),
  };

  double? get areaSqft =>
      areaValue == null ? null : areaUnit.toSqft(areaValue!);

  static String? _blank(String? value) {
    final trimmed = value?.trim();
    return (trimmed == null || trimmed.isEmpty) ? null : trimmed;
  }
}

/// What still blocks publishing, mirroring the database rules.
/// Empty list = ready.
List<String> publishBlockers(PropertyFields fields, {required bool hasCover}) =>
    [
      if (fields.title.trim().length < 5) 'Add a title (at least 5 characters)',
      if (fields.propertyTypeId == null) 'Choose the property type',
      if (fields.locationId == null) 'Choose the location',
      if (fields.areaValue == null || fields.areaValue! <= 0) 'Enter the area',
      if (fields.priceType == PriceType.total &&
          (fields.price == null || fields.price! <= 0))
        'Enter the price (or choose "Price on request")',
      if (!hasCover) 'Add at least one photo (the first one is the cover)',
    ];
