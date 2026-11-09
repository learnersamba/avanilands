import 'package:avanilands_admin/core/number_input.dart';
import 'package:avanilands_admin/features/properties/properties_repository.dart';
import 'package:avanilands_admin/features/properties/property_actions.dart';
import 'package:avanilands_admin/features/properties/property_enums.dart';
import 'package:avanilands_admin/features/properties/property_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('area', () {
    test('conversions match the database table', () {
      expect(AreaUnit.cent.toSqft(25), closeTo(10890, 0.001));
      expect(AreaUnit.acre.toSqft(2), 87120);
      expect(AreaUnit.gunta.toSqft(20), 21780);
      expect(AreaUnit.sqYd.toSqft(200), 1800);
    });

    test('display keeps the unit and adds sq ft', () {
      expect(formatArea(25, AreaUnit.cent), '25 cents (10,890 sq ft)');
      expect(formatArea(1800, AreaUnit.sqFt), '1800 sq ft');
      expect(formatArea(null, AreaUnit.acre), '—');
    });
  });

  group('rupees', () {
    test('short form', () {
      expect(shortRupees(4500000), '₹45 L');
      expect(shortRupees(24000000), '₹2.4 Cr');
      expect(shortRupees(85000), '₹85,000');
    });

    test('typing formats with Indian grouping', () {
      final out = IndianNumberFormatter().formatEditUpdate(
        TextEditingValue.empty,
        const TextEditingValue(text: '4500000'),
      );
      expect(out.text, '45,00,000');
      expect(parseNumber(out.text), 4500000);
    });

    test('decimal field rejects letters and extra places', () {
      final formatter = DecimalFormatter(decimals: 2);
      const old = TextEditingValue(text: '2.5');
      expect(
        formatter
            .formatEditUpdate(old, const TextEditingValue(text: '2.55'))
            .text,
        '2.55',
      );
      expect(
        formatter
            .formatEditUpdate(old, const TextEditingValue(text: '2.555'))
            .text,
        '2.5',
      );
      expect(
        formatter
            .formatEditUpdate(old, const TextEditingValue(text: '2.5a'))
            .text,
        '2.5',
      );
    });
  });

  group('fields sent to the database', () {
    test('price on request clears the prices', () {
      final json = const PropertyFields(
        title: 'Plot',
        priceType: PriceType.onRequest,
        price: 100,
        pricePerUnit: 10,
      ).toJson();
      expect(json['price'], isNull);
      expect(json['price_per_unit'], isNull);
      expect(json['price_per_unit_unit'], isNull);
    });

    test('per-unit price defaults to the area unit', () {
      final json = const PropertyFields(
        title: 'Plot',
        price: 100,
        pricePerUnit: 10,
        areaUnit: AreaUnit.cent,
      ).toJson();
      expect(json['price_per_unit_unit'], 'cent');
    });

    test('blank text becomes null and highlights are trimmed', () {
      final json = const PropertyFields(
        title: '  Plot  ',
        locality: '   ',
        highlights: [' East facing ', ''],
        featuredRank: 3,
      ).toJson();
      expect(json['title'], 'Plot');
      expect(json['locality'], isNull);
      expect(json['highlights'], ['East facing']);
      expect(
        json['featured_rank'],
        isNull,
        reason: 'rank only kept when featured',
      );
    });

    test('status columns are never sent with the form', () {
      final json = const PropertyFields(title: 'Plot').toJson();
      expect(json.containsKey('publish_state'), isFalse);
      expect(json.containsKey('availability'), isFalse);
    });
  });

  test('publish checklist mirrors the database rules', () {
    expect(
      publishBlockers(const PropertyFields(), hasCover: false),
      hasLength(6),
    );
    const ready = PropertyFields(
      title: 'A good plot',
      propertyTypeId: 1,
      locationId: 'l1',
      areaValue: 200,
      price: 3600000,
    );
    expect(publishBlockers(ready, hasCover: true), isEmpty);
    expect(publishBlockers(ready, hasCover: false), [
      'Add at least one photo (the first one is the cover)',
    ]);
    const onRequest = PropertyFields(
      title: 'A good plot',
      propertyTypeId: 1,
      locationId: 'l1',
      areaValue: 200,
      priceType: PriceType.onRequest,
    );
    expect(publishBlockers(onRequest, hasCover: true), isEmpty);
  });

  test('status menu never offers going back to draft', () {
    for (final state in PublishState.values) {
      expect(publishTargets(state), isNot(contains(PublishState.draft)));
      expect(publishTargets(state), isNot(contains(state)));
    }
  });

  group('list filters in the address', () {
    test('round trip', () {
      const query = PropertyQuery(
        search: 'anandapuram',
        state: PublishState.published,
        availability: Availability.reserved,
        typeId: 3,
        locationId: 'loc-1',
        sort: PropertySort.priceLow,
        page: 2,
      );
      final uri = Uri(
        path: '/properties',
        queryParameters: query.toQueryParameters(),
      );
      expect(PropertyQuery.fromUri(uri), query);
    });

    test('changing a filter goes back to page 1', () {
      const query = PropertyQuery(page: 4);
      expect(query.copyWith(state: () => PublishState.draft).page, 1);
      expect(query.copyWith(page: 5).page, 5);
    });

    test('bad values are ignored', () {
      final query = PropertyQuery.fromUri(
        Uri.parse('/properties?state=nope&page=-3&type=x'),
      );
      expect(query.state, isNull);
      expect(query.page, 1);
      expect(query.typeId, isNull);
    });

    test('search text cannot break the filter', () {
      expect(cleanSearch('AL-0001,(hack)*'), 'AL-0001  hack');
    });
  });
}
