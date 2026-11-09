import 'package:flutter/widgets.dart';

import '../../../core/number_input.dart';
import '../../../core/unsaved_changes.dart';
import '../property_enums.dart';
import '../property_models.dart';

class NearbyRow {
  NearbyRow({
    this.id,
    String name = '',
    this.category = NearbyCategory.other,
    double? distance,
  }) : name = TextEditingController(text: name),
       distance = TextEditingController(text: formatInputNumber(distance));

  final String? id;
  final TextEditingController name;
  NearbyCategory category;
  final TextEditingController distance;

  NearbyPlace toPlace() => NearbyPlace(
    id: id,
    name: name.text.trim(),
    category: category,
    distanceKm: parseNumber(distance.text),
  );

  void dispose() {
    name.dispose();
    distance.dispose();
  }
}

/// All values of the property form. Text fields mark the form dirty;
/// other changes go through [set] so the screen rebuilds.
class PropertyFormController extends ChangeNotifier {
  PropertyFormController() {
    for (final controller in _texts) {
      controller.addListener(_touch);
    }
  }

  final title = TextEditingController();
  final description = TextEditingController();
  final locality = TextEditingController();
  final address = TextEditingController();
  final pincode = TextEditingController();
  final latitude = TextEditingController();
  final longitude = TextEditingController();
  final areaValue = TextEditingController();
  final lengthFt = TextEditingController();
  final widthFt = TextEditingController();
  final dimensionsText = TextEditingController();
  final price = TextEditingController();
  final pricePerUnit = TextEditingController();
  final roadWidthFt = TextEditingController();
  final waterSource = TextEditingController();
  final approvalNumber = TextEditingController();
  final reraNumber = TextEditingController();
  final legalNotes = TextEditingController();
  final internalNotes = TextEditingController();
  final featuredRank = TextEditingController();
  final seoTitle = TextEditingController();
  final seoDescription = TextEditingController();
  final slug = TextEditingController();

  late final List<TextEditingController> _texts = [
    title,
    description,
    locality,
    address,
    pincode,
    latitude,
    longitude,
    areaValue,
    lengthFt,
    widthFt,
    dimensionsText,
    price,
    pricePerUnit,
    roadWidthFt,
    waterSource,
    approvalNumber,
    reraNumber,
    legalNotes,
    internalNotes,
    featuredRank,
    seoTitle,
    seoDescription,
    slug,
  ];

  int? typeId;
  String? locationId;
  bool showExactLocation = false;
  AreaUnit areaUnit = AreaUnit.sqYd;
  PriceType priceType = PriceType.total;
  AreaUnit? pricePerUnitUnit;
  bool isNegotiable = false;
  Facing? facing;
  bool isCorner = false;
  bool? waterAvailable;
  bool? electricityAvailable;
  ApprovalType approvalType = ApprovalType.notApplicable;
  bool isFeatured = false;
  Set<int> amenityIds = {};
  final List<TextEditingController> highlights = [];
  final List<NearbyRow> nearby = [];

  /// What was last loaded or saved, to work out changes.
  Set<int> savedAmenityIds = {};
  List<NearbyPlace> savedNearby = const [];

  bool dirty = false;
  bool _loading = false;

  /// Bumped on every [load] so fields that keep their own value (dropdowns)
  /// can be rebuilt with the loaded data.
  int loads = 0;

  void _touch() {
    if (_loading || dirty) return;
    dirty = true;
    unsavedChanges.value = true;
    notifyListeners();
  }

  /// Apply a non-text change and rebuild.
  void set(VoidCallback change) {
    change();
    if (!_loading) {
      dirty = true;
      unsavedChanges.value = true;
    }
    notifyListeners();
  }

  void markSaved() {
    dirty = false;
    unsavedChanges.value = false;
    notifyListeners();
  }

  void load(PropertyDetail? detail) {
    _loading = true;
    final f = detail?.fields ?? const PropertyFields();
    title.text = f.title;
    description.text = f.description ?? '';
    locality.text = f.locality ?? '';
    address.text = f.address ?? '';
    pincode.text = f.pincode ?? '';
    latitude.text = f.latitude?.toString() ?? '';
    longitude.text = f.longitude?.toString() ?? '';
    areaValue.text = formatInputNumber(f.areaValue);
    lengthFt.text = formatInputNumber(f.lengthFt);
    widthFt.text = formatInputNumber(f.widthFt);
    dimensionsText.text = f.dimensionsText ?? '';
    price.text = formatInputNumber(f.price, rupees: true);
    pricePerUnit.text = formatInputNumber(f.pricePerUnit, rupees: true);
    roadWidthFt.text = formatInputNumber(f.roadWidthFt);
    waterSource.text = f.waterSource ?? '';
    approvalNumber.text = f.approvalNumber ?? '';
    reraNumber.text = f.reraNumber ?? '';
    legalNotes.text = f.legalNotes ?? '';
    internalNotes.text = f.internalNotes ?? '';
    featuredRank.text = f.featuredRank?.toString() ?? '';
    seoTitle.text = f.seoTitle ?? '';
    seoDescription.text = f.seoDescription ?? '';
    slug.text = f.slug ?? '';

    typeId = f.propertyTypeId;
    locationId = f.locationId;
    showExactLocation = f.showExactLocation;
    areaUnit = f.areaUnit;
    priceType = f.priceType;
    pricePerUnitUnit = f.pricePerUnitUnit;
    isNegotiable = f.isNegotiable;
    facing = f.facing;
    isCorner = f.isCorner;
    waterAvailable = f.waterAvailable;
    electricityAvailable = f.electricityAvailable;
    approvalType = f.approvalType;
    isFeatured = f.isFeatured;

    for (final controller in highlights) {
      controller.dispose();
    }
    highlights
      ..clear()
      ..addAll(f.highlights.map(_highlight));
    for (final row in nearby) {
      row.dispose();
    }
    nearby
      ..clear()
      ..addAll([
        for (final place in detail?.nearby ?? const <NearbyPlace>[])
          NearbyRow(
            id: place.id,
            name: place.name,
            category: place.category,
            distance: place.distanceKm,
          ),
      ]);
    amenityIds = {...?detail?.amenityIds};
    savedAmenityIds = {...amenityIds};
    savedNearby = [...?detail?.nearby];

    loads++;
    _loading = false;
    dirty = false;
    unsavedChanges.value = false;
    notifyListeners();
  }

  TextEditingController _highlight(String text) =>
      TextEditingController(text: text)..addListener(_touch);

  void addHighlight() => set(() => highlights.add(_highlight('')));

  void removeHighlight(int index) =>
      set(() => highlights.removeAt(index).dispose());

  void moveHighlight(int index, int by) => set(() {
    final item = highlights.removeAt(index);
    highlights.insert(index + by, item);
  });

  void addNearby() => set(
    () => nearby.add(
      NearbyRow()
        ..name.addListener(_touch)
        ..distance.addListener(_touch),
    ),
  );

  void removeNearby(int index) => set(() => nearby.removeAt(index).dispose());

  void moveNearby(int index, int by) => set(() {
    final item = nearby.removeAt(index);
    nearby.insert(index + by, item);
  });

  /// The form as database values.
  PropertyFields collect() => PropertyFields(
    title: title.text,
    propertyTypeId: typeId,
    description: description.text,
    locationId: locationId,
    locality: locality.text,
    address: address.text,
    pincode: pincode.text,
    latitude: parseNumber(latitude.text),
    longitude: parseNumber(longitude.text),
    showExactLocation: showExactLocation,
    areaValue: parseNumber(areaValue.text),
    areaUnit: areaUnit,
    lengthFt: parseNumber(lengthFt.text),
    widthFt: parseNumber(widthFt.text),
    dimensionsText: dimensionsText.text,
    priceType: priceType,
    price: parseNumber(price.text),
    pricePerUnit: parseNumber(pricePerUnit.text),
    pricePerUnitUnit: pricePerUnitUnit,
    isNegotiable: isNegotiable,
    facing: facing,
    roadWidthFt: parseNumber(roadWidthFt.text),
    isCorner: isCorner,
    waterAvailable: waterAvailable,
    waterSource: waterSource.text,
    electricityAvailable: electricityAvailable,
    approvalType: approvalType,
    approvalNumber: approvalNumber.text,
    reraNumber: reraNumber.text,
    legalNotes: legalNotes.text,
    internalNotes: internalNotes.text,
    highlights: [for (final controller in highlights) controller.text],
    isFeatured: isFeatured,
    featuredRank: int.tryParse(featuredRank.text.trim()),
    seoTitle: seoTitle.text,
    seoDescription: seoDescription.text,
    slug: slug.text,
  );

  List<NearbyPlace> collectNearby() => [
    for (final row in nearby)
      if (row.name.text.trim().isNotEmpty) row.toPlace(),
  ];

  /// Listenable for the parts that affect the publish checklist.
  Listenable get checklistInputs =>
      Listenable.merge([this, title, areaValue, price]);

  @override
  void dispose() {
    for (final controller in [..._texts, ...highlights]) {
      controller.dispose();
    }
    for (final row in nearby) {
      row.dispose();
    }
    unsavedChanges.value = false;
    super.dispose();
  }
}
