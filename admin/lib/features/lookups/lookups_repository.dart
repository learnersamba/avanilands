import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/supabase_client.dart';

class PropertyType {
  const PropertyType({
    required this.id,
    required this.name,
    required this.slug,
    required this.seoSlug,
    required this.sortOrder,
    required this.isActive,
  });

  factory PropertyType.fromJson(Map<String, dynamic> json) => PropertyType(
    id: json['id'] as int,
    name: json['name'] as String,
    slug: json['slug'] as String,
    seoSlug: json['seo_slug'] as String,
    sortOrder: json['sort_order'] as int,
    isActive: json['is_active'] as bool,
  );

  final int id;
  final String name;
  final String slug;
  final String seoSlug;
  final int sortOrder;
  final bool isActive;
}

class Location {
  const Location({
    required this.id,
    required this.state,
    required this.district,
    required this.city,
    required this.slug,
    this.description,
    this.coverImagePath,
    required this.isPopular,
    required this.sortOrder,
    required this.isActive,
  });

  factory Location.fromJson(Map<String, dynamic> json) => Location(
    id: json['id'] as String,
    state: json['state'] as String,
    district: json['district'] as String,
    city: json['city'] as String,
    slug: json['slug'] as String,
    description: json['description'] as String?,
    coverImagePath: json['cover_image_path'] as String?,
    isPopular: json['is_popular'] as bool,
    sortOrder: json['sort_order'] as int,
    isActive: json['is_active'] as bool,
  );

  final String id;
  final String state;
  final String district;
  final String city;
  final String slug;
  final String? description;

  /// File in the `site-assets` bucket, shown on the website's location pages.
  final String? coverImagePath;
  final bool isPopular;
  final int sortOrder;
  final bool isActive;

  /// "Visakhapatnam" or "Bheemunipatnam, Visakhapatnam district".
  String get label => city == district ? city : '$city, $district';
}

class Amenity {
  const Amenity({
    required this.id,
    required this.name,
    this.icon,
    required this.sortOrder,
    required this.isActive,
  });

  factory Amenity.fromJson(Map<String, dynamic> json) => Amenity(
    id: json['id'] as int,
    name: json['name'] as String,
    icon: json['icon'] as String?,
    sortOrder: json['sort_order'] as int,
    isActive: json['is_active'] as bool,
  );

  final int id;
  final String name;
  final String? icon;
  final int sortOrder;
  final bool isActive;
}

/// "Bheemunipatnam Beach" → "bheemunipatnam-beach".
String slugify(String text) {
  final slug = text
      .toLowerCase()
      .replaceAll(RegExp('[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');
  return slug;
}

class LookupsRepository {
  LookupsRepository(this._client);

  final SupabaseClient _client;

  Future<List<PropertyType>> types() async {
    final rows = await _client
        .from('property_types')
        .select()
        .order('sort_order', ascending: true)
        .order('name', ascending: true);
    return rows.map(PropertyType.fromJson).toList();
  }

  Future<List<Location>> locations() async {
    final rows = await _client
        .from('locations')
        .select()
        .order('sort_order', ascending: true)
        .order('city', ascending: true);
    return rows.map(Location.fromJson).toList();
  }

  Future<List<Amenity>> amenities() async {
    final rows = await _client
        .from('amenities')
        .select()
        .order('sort_order', ascending: true)
        .order('name', ascending: true);
    return rows.map(Amenity.fromJson).toList();
  }

  // Locations -----------------------------------------------------------------

  Future<void> saveLocation({
    String? id,
    required String state,
    required String district,
    required String city,
    required String slug,
    String? description,
    required bool isPopular,
    required bool isActive,
  }) async {
    final data = {
      'state': state.trim(),
      'district': district.trim(),
      'city': city.trim(),
      'slug': slug.trim(),
      'description': (description?.trim().isEmpty ?? true)
          ? null
          : description!.trim(),
      'is_popular': isPopular,
      'is_active': isActive,
    };
    if (id == null) {
      await _client.from('locations').insert({
        ...data,
        'sort_order': await _nextOrder('locations'),
      });
    } else {
      await _client.from('locations').update(data).eq('id', id);
    }
  }

  Future<void> setLocationFlags(String id, {bool? isActive, bool? isPopular}) =>
      _client
          .from('locations')
          .update({'is_active': ?isActive, 'is_popular': ?isPopular})
          .eq('id', id);

  Future<void> setLocationCover(String id, String? path) => _client
      .from('locations')
      .update({'cover_image_path': path})
      .eq('id', id)
      .select('id')
      .single();

  Future<void> deleteLocation(String id) =>
      _client.from('locations').delete().eq('id', id);

  // Property types ------------------------------------------------------------

  Future<void> saveType(
    int id, {
    required String name,
    required String seoSlug,
  }) => _client
      .from('property_types')
      .update({'name': name.trim(), 'seo_slug': seoSlug.trim()})
      .eq('id', id);

  Future<void> setTypeActive(int id, {required bool active}) =>
      _client.from('property_types').update({'is_active': active}).eq('id', id);

  // Amenities -----------------------------------------------------------------

  Future<void> saveAmenity({int? id, required String name}) async {
    final data = {'name': name.trim()};
    if (id == null) {
      await _client.from('amenities').insert({
        ...data,
        'sort_order': await _nextOrder('amenities'),
      });
    } else {
      await _client.from('amenities').update(data).eq('id', id);
    }
  }

  Future<void> setAmenityActive(int id, {required bool active}) =>
      _client.from('amenities').update({'is_active': active}).eq('id', id);

  Future<void> deleteAmenity(int id) =>
      _client.from('amenities').delete().eq('id', id);

  /// One more than the current last position, so new items go to the end.
  Future<int> _nextOrder(String table) async {
    final row = await _client
        .from(table)
        .select('sort_order')
        .order('sort_order', ascending: false)
        .limit(1)
        .maybeSingle();
    return ((row?['sort_order'] as int?) ?? 0) + 1;
  }

  /// Saves a new order: `ids` from first to last. Only changed rows are written.
  Future<void> reorder(
    String table,
    List<Object> ids,
    Map<Object, int> current,
  ) async {
    for (var index = 0; index < ids.length; index++) {
      final id = ids[index];
      final order = index + 1;
      if (current[id] != order) {
        await _client.from(table).update({'sort_order': order}).eq('id', id);
      }
    }
  }
}

final lookupsRepositoryProvider = Provider<LookupsRepository>(
  (ref) => LookupsRepository(ref.watch(supabaseProvider)),
);

final propertyTypesProvider = FutureProvider.autoDispose<List<PropertyType>>(
  (ref) => ref.watch(lookupsRepositoryProvider).types(),
);

final locationsProvider = FutureProvider.autoDispose<List<Location>>(
  (ref) => ref.watch(lookupsRepositoryProvider).locations(),
);

final amenitiesProvider = FutureProvider.autoDispose<List<Amenity>>(
  (ref) => ref.watch(lookupsRepositoryProvider).amenities(),
);
