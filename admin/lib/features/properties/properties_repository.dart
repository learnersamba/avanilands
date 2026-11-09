import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/supabase_client.dart';
import '../activity/activity_repository.dart';
import 'property_enums.dart';
import 'property_models.dart';

enum PropertySort {
  updated('updated', 'Recently updated'),
  newest('newest', 'Newest first'),
  code('code', 'Code'),
  priceLow('price_asc', 'Price: low to high'),
  priceHigh('price_desc', 'Price: high to low');

  const PropertySort(this.value, this.label);
  final String value;
  final String label;

  static PropertySort parse(String? value) =>
      values.firstWhere((item) => item.value == value, orElse: () => updated);
}

/// List filters. Kept in the page address so Back and shared links work.
class PropertyQuery {
  const PropertyQuery({
    this.search = '',
    this.state,
    this.availability,
    this.typeId,
    this.locationId,
    this.sort = PropertySort.updated,
    this.page = 1,
  });

  factory PropertyQuery.fromUri(Uri uri) {
    final p = uri.queryParameters;
    PublishState? state;
    Availability? availability;
    for (final item in PublishState.values) {
      if (item.value == p['state']) state = item;
    }
    for (final item in Availability.values) {
      if (item.value == p['availability']) availability = item;
    }
    return PropertyQuery(
      search: p['q'] ?? '',
      state: state,
      availability: availability,
      typeId: int.tryParse(p['type'] ?? ''),
      locationId: p['location'],
      sort: PropertySort.parse(p['sort']),
      page: (int.tryParse(p['page'] ?? '') ?? 1).clamp(1, 100000),
    );
  }

  static const pageSize = 25;

  final String search;
  final PublishState? state;
  final Availability? availability;
  final int? typeId;
  final String? locationId;
  final PropertySort sort;
  final int page;

  bool get hasFilters =>
      search.isNotEmpty ||
      state != null ||
      availability != null ||
      typeId != null ||
      locationId != null;

  Map<String, String> toQueryParameters() => {
    if (search.isNotEmpty) 'q': search,
    if (state != null) 'state': state!.value,
    if (availability != null) 'availability': availability!.value,
    if (typeId != null) 'type': '$typeId',
    'location': ?locationId,
    if (sort != PropertySort.updated) 'sort': sort.value,
    if (page > 1) 'page': '$page',
  };

  /// A changed copy; changing any filter goes back to page 1.
  PropertyQuery copyWith({
    String? search,
    PublishState? Function()? state,
    Availability? Function()? availability,
    int? Function()? typeId,
    String? Function()? locationId,
    PropertySort? sort,
    int? page,
  }) => PropertyQuery(
    search: search ?? this.search,
    state: state != null ? state() : this.state,
    availability: availability != null ? availability() : this.availability,
    typeId: typeId != null ? typeId() : this.typeId,
    locationId: locationId != null ? locationId() : this.locationId,
    sort: sort ?? this.sort,
    page: page ?? 1,
  );

  @override
  bool operator ==(Object other) =>
      other is PropertyQuery &&
      other.toQueryParameters().toString() == toQueryParameters().toString();

  @override
  int get hashCode => toQueryParameters().toString().hashCode;
}

class PropertyPage {
  const PropertyPage({required this.items, required this.total});

  final List<PropertyListItem> items;
  final int total;
}

/// Characters that would break a PostgREST `or=(…)` filter.
String cleanSearch(String text) =>
    text.replaceAll(RegExp(r'[,()"\\%*:]'), ' ').trim();

class PropertiesRepository {
  PropertiesRepository(this._client);

  final SupabaseClient _client;

  Future<PropertyPage> list(PropertyQuery query) async {
    var request = _client
        .from('properties')
        .select(PropertyListItem.select)
        .eq('cover.is_cover', true);
    final search = cleanSearch(query.search);
    if (search.isNotEmpty) {
      // Also match the city or district (a separate table).
      final places = await _client
          .from('locations')
          .select('id')
          .or('city.ilike.%$search%,district.ilike.%$search%');
      final placeIds = places.map((row) => row['id'] as String).join(',');
      request = request.or(
        'code.ilike.%$search%,title.ilike.%$search%,locality.ilike.%$search%'
        '${placeIds.isEmpty ? '' : ',location_id.in.($placeIds)'}',
      );
    }
    if (query.state != null) {
      request = request.eq('publish_state', query.state!.value);
    }
    if (query.availability != null) {
      request = request.eq('availability', query.availability!.value);
    }
    if (query.typeId != null) {
      request = request.eq('property_type_id', query.typeId!);
    }
    if (query.locationId != null) {
      request = request.eq('location_id', query.locationId!);
    }

    final sorted = switch (query.sort) {
      PropertySort.updated => request.order('updated_at', ascending: false),
      PropertySort.newest => request.order('created_at', ascending: false),
      PropertySort.code => request.order('code', ascending: true),
      PropertySort.priceLow => request.order(
        'price',
        ascending: true,
        nullsFirst: false,
      ),
      PropertySort.priceHigh => request.order(
        'price',
        ascending: false,
        nullsFirst: false,
      ),
    };
    final from = (query.page - 1) * PropertyQuery.pageSize;
    final response = await sorted
        .order('id', ascending: true)
        .range(from, from + PropertyQuery.pageSize - 1)
        .count(CountOption.exact);
    return PropertyPage(
      items: response.data.map(PropertyListItem.fromJson).toList(),
      total: response.count,
    );
  }

  Future<PropertyDetail> get(String id) async => PropertyDetail.fromJson(
    await _client
        .from('properties')
        .select(PropertyDetail.select)
        .eq('id', id)
        .single(),
  );

  /// Creates a draft and returns its id.
  Future<String> create(PropertyFields fields) async {
    final row = await _client
        .from('properties')
        .insert(fields.toJson())
        .select('id')
        .single();
    return row['id'] as String;
  }

  Future<void> update(String id, PropertyFields fields) => _client
      .from('properties')
      .update(fields.toJson())
      .eq('id', id)
      .select('id')
      .single();

  Future<void> setPublishState(String id, PublishState state) => _client
      .from('properties')
      .update({'publish_state': state.value})
      .eq('id', id)
      .select('id')
      .single();

  Future<void> setAvailability(String id, Availability availability) => _client
      .from('properties')
      .update({'availability': availability.value})
      .eq('id', id)
      .select('id')
      .single();

  /// Writes only the amenities that changed.
  Future<void> saveAmenities(
    String propertyId,
    Set<int> before,
    Set<int> after,
  ) async {
    final removed = before.difference(after);
    final added = after.difference(before);
    if (removed.isNotEmpty) {
      await _client
          .from('property_amenities')
          .delete()
          .eq('property_id', propertyId)
          .inFilter('amenity_id', removed.toList());
    }
    if (added.isNotEmpty) {
      await _client.from('property_amenities').insert([
        for (final id in added) {'property_id': propertyId, 'amenity_id': id},
      ]);
    }
  }

  /// Writes only the nearby places that were added, changed, moved or removed.
  Future<void> saveNearby(
    String propertyId,
    List<NearbyPlace> before,
    List<NearbyPlace> after,
  ) async {
    final keptIds = after.map((place) => place.id).whereType<String>().toSet();
    final removed = before
        .where((place) => !keptIds.contains(place.id))
        .map((place) => place.id!)
        .toList();
    if (removed.isNotEmpty) {
      await _client
          .from('property_nearby_places')
          .delete()
          .inFilter('id', removed);
    }
    final previous = {for (final place in before) place.id: place};
    for (var index = 0; index < after.length; index++) {
      final place = after[index];
      final order = index + 1;
      if (place.id == null) {
        await _client
            .from('property_nearby_places')
            .insert(place.toJson(propertyId, order));
      } else {
        final old = previous[place.id];
        if (old == null || !old.sameAs(place) || old.sortOrder != order) {
          await _client
              .from('property_nearby_places')
              .update(place.toJson(propertyId, order))
              .eq('id', place.id!);
        }
      }
    }
  }

  /// Deletes a draft (database checks it has no enquiries) and its files.
  Future<void> deleteDraft(String id) async {
    final result = await _client.rpc<Map<String, dynamic>>(
      'delete_draft_property',
      params: {'p_property_id': id},
    );
    final media = (result['media'] as List).cast<String>();
    final documents = (result['documents'] as List).cast<String>();
    if (media.isNotEmpty) {
      await _client.storage.from('property-media').remove(media);
    }
    if (documents.isNotEmpty) {
      await _client.storage.from('property-documents').remove(documents);
    }
  }

  /// This property's entries in the activity log, newest first.
  Future<List<AuditEntry>> history(String id, {int limit = 100}) async {
    final rows = await _client
        .from('audit_logs')
        .select()
        .or('entity_id.eq.$id,details->>property_id.eq.$id')
        .order('created_at', ascending: false)
        .order('id', ascending: false)
        .limit(limit);
    return rows.map(AuditEntry.fromJson).toList();
  }

  /// Property id for a code such as "AL-0007", if it exists.
  Future<String?> idForCode(String code) async {
    final row = await _client
        .from('properties')
        .select('id')
        .eq('code', code.trim().toUpperCase())
        .maybeSingle();
    return row?['id'] as String?;
  }
}

final propertiesRepositoryProvider = Provider<PropertiesRepository>(
  (ref) => PropertiesRepository(ref.watch(supabaseProvider)),
);

final propertyPageProvider = FutureProvider.autoDispose
    .family<PropertyPage, PropertyQuery>(
      (ref, query) => ref.watch(propertiesRepositoryProvider).list(query),
    );

final propertyDetailProvider = FutureProvider.autoDispose
    .family<PropertyDetail, String>(
      (ref, id) => ref.watch(propertiesRepositoryProvider).get(id),
    );

final propertyHistoryProvider = FutureProvider.autoDispose
    .family<List<AuditEntry>, String>(
      (ref, id) => ref.watch(propertiesRepositoryProvider).history(id),
    );
