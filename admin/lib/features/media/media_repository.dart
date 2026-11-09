import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/storage_upload.dart';
import '../../core/supabase_client.dart';

const mediaBucket = 'property-media';
const documentsBucket = 'property-documents';
const siteAssetsBucket = 'site-assets';

class PropertyImage {
  const PropertyImage({
    required this.id,
    required this.pathThumb,
    required this.pathMedium,
    required this.pathLarge,
    this.width,
    this.height,
    this.altText,
    required this.sortOrder,
    required this.isCover,
  });

  factory PropertyImage.fromJson(Map<String, dynamic> json) => PropertyImage(
    id: json['id'] as String,
    pathThumb: json['path_thumb'] as String,
    pathMedium: json['path_medium'] as String,
    pathLarge: json['path_large'] as String,
    width: json['width'] as int?,
    height: json['height'] as int?,
    altText: json['alt_text'] as String?,
    sortOrder: json['sort_order'] as int,
    isCover: json['is_cover'] as bool,
  );

  final String id;
  final String pathThumb;
  final String pathMedium;
  final String pathLarge;
  final int? width;
  final int? height;
  final String? altText;
  final int sortOrder;
  final bool isCover;

  List<String> get paths => [pathThumb, pathMedium, pathLarge];
}

class PropertyVideo {
  const PropertyVideo({
    required this.id,
    required this.kind,
    this.youtubeId,
    this.storagePath,
    this.title,
    required this.isPrimary,
    required this.sortOrder,
  });

  factory PropertyVideo.fromJson(Map<String, dynamic> json) => PropertyVideo(
    id: json['id'] as String,
    kind: json['kind'] as String,
    youtubeId: json['youtube_id'] as String?,
    storagePath: json['storage_path'] as String?,
    title: json['title'] as String?,
    isPrimary: json['is_primary'] as bool,
    sortOrder: json['sort_order'] as int,
  );

  final String id;

  /// 'youtube' or 'upload'.
  final String kind;
  final String? youtubeId;
  final String? storagePath;
  final String? title;
  final bool isPrimary;
  final int sortOrder;

  bool get isYoutube => kind == 'youtube';
}

enum DocumentType {
  brochure('brochure', 'Brochure'),
  layoutPlan('layout_plan', 'Layout plan'),
  approval('approval', 'Approval document'),
  titleDocument('title_document', 'Title document'),
  encumbrance('encumbrance', 'Encumbrance certificate'),
  other('other', 'Other');

  const DocumentType(this.value, this.label);
  final String value;
  final String label;

  static DocumentType parse(String value) =>
      values.firstWhere((item) => item.value == value, orElse: () => other);
}

class PropertyDocument {
  const PropertyDocument({
    required this.id,
    required this.type,
    required this.title,
    required this.storagePath,
    required this.mimeType,
    required this.sizeBytes,
    required this.isPublic,
    required this.sortOrder,
  });

  factory PropertyDocument.fromJson(Map<String, dynamic> json) =>
      PropertyDocument(
        id: json['id'] as String,
        type: DocumentType.parse(json['doc_type'] as String),
        title: json['title'] as String,
        storagePath: json['storage_path'] as String,
        mimeType: json['mime_type'] as String,
        sizeBytes: json['size_bytes'] as int,
        isPublic: json['is_public'] as bool,
        sortOrder: json['sort_order'] as int,
      );

  final String id;
  final DocumentType type;
  final String title;
  final String storagePath;
  final String mimeType;
  final int sizeBytes;
  final bool isPublic;
  final int sortOrder;
}

/// Database rows for photos, videos and documents. Files themselves are
/// uploaded with [StorageUploader]; this class removes them when rows go.
class MediaRepository {
  MediaRepository(this._client, this._uploader);

  final SupabaseClient _client;
  final StorageUploader _uploader;

  // Photos --------------------------------------------------------------------

  Future<List<PropertyImage>> images(String propertyId) async {
    final rows = await _client
        .from('property_images')
        .select()
        .eq('property_id', propertyId)
        .order('sort_order', ascending: true)
        .order('created_at', ascending: true);
    return rows.map(PropertyImage.fromJson).toList();
  }

  Future<void> insertImage(Map<String, dynamic> row) =>
      _client.from('property_images').insert(row);

  /// Points a photo at new files, then removes the old ones.
  Future<void> replaceImageFiles(
    PropertyImage image,
    Map<String, dynamic> newFiles,
  ) async {
    await _client
        .from('property_images')
        .update(newFiles)
        .eq('id', image.id)
        .select('id')
        .single();
    await _uploader.remove(mediaBucket, image.paths);
  }

  Future<void> setAltText(String imageId, String? alt) => _client
      .from('property_images')
      .update({
        'alt_text': (alt == null || alt.trim().isEmpty) ? null : alt.trim(),
      })
      .eq('id', imageId);

  Future<void> setCover(String imageId) =>
      _client.rpc<void>('set_cover_image', params: {'p_image_id': imageId});

  Future<void> reorderImages(String propertyId, List<String> ids) =>
      _client.rpc<void>(
        'reorder_property_images',
        params: {'p_property_id': propertyId, 'p_image_ids': ids},
      );

  /// Deletes the row first (the database may refuse, e.g. the only photo of
  /// a published property), then the files.
  Future<void> deleteImage(PropertyImage image) async {
    await _client
        .from('property_images')
        .delete()
        .eq('id', image.id)
        .select('id')
        .single();
    await _uploader.remove(mediaBucket, image.paths);
  }

  // Videos --------------------------------------------------------------------

  Future<List<PropertyVideo>> videos(String propertyId) async {
    final rows = await _client
        .from('property_videos')
        .select()
        .eq('property_id', propertyId)
        .order('sort_order', ascending: true);
    return rows.map(PropertyVideo.fromJson).toList();
  }

  Future<void> addYoutube(
    String propertyId, {
    required String youtubeId,
    String? title,
  }) => _client.from('property_videos').insert({
    'property_id': propertyId,
    'kind': 'youtube',
    'youtube_id': youtubeId,
    'title': (title == null || title.trim().isEmpty) ? null : title.trim(),
  });

  Future<void> addUploadedVideo(
    String propertyId, {
    required String storagePath,
    String? title,
  }) => _client.from('property_videos').insert({
    'property_id': propertyId,
    'kind': 'upload',
    'storage_path': storagePath,
    'title': (title == null || title.trim().isEmpty) ? null : title.trim(),
  });

  Future<void> setPrimaryVideo(String videoId) =>
      _client.rpc<void>('set_primary_video', params: {'p_video_id': videoId});

  Future<void> deleteVideo(PropertyVideo video) async {
    await _client
        .from('property_videos')
        .delete()
        .eq('id', video.id)
        .select('id')
        .single();
    if (video.storagePath != null) {
      await _uploader.remove(mediaBucket, [video.storagePath!]);
    }
  }

  // Documents -----------------------------------------------------------------

  Future<List<PropertyDocument>> documents(String propertyId) async {
    final rows = await _client
        .from('property_documents')
        .select()
        .eq('property_id', propertyId)
        .order('sort_order', ascending: true)
        .order('created_at', ascending: true);
    return rows.map(PropertyDocument.fromJson).toList();
  }

  Future<void> insertDocument(Map<String, dynamic> row) =>
      _client.from('property_documents').insert(row);

  Future<void> updateDocument(String id, Map<String, dynamic> changes) =>
      _client
          .from('property_documents')
          .update(changes)
          .eq('id', id)
          .select('id')
          .single();

  /// Points a document at a new file, then removes the old one.
  Future<void> replaceDocumentFile(
    PropertyDocument document,
    Map<String, dynamic> newFile,
  ) async {
    await updateDocument(document.id, newFile);
    await _uploader.remove(documentsBucket, [document.storagePath]);
  }

  Future<void> deleteDocument(PropertyDocument document) async {
    await _client
        .from('property_documents')
        .delete()
        .eq('id', document.id)
        .select('id')
        .single();
    await _uploader.remove(documentsBucket, [document.storagePath]);
  }

  /// A link that works for 2 minutes (documents are in a private bucket).
  Future<String> documentLink(String path) =>
      _client.storage.from(documentsBucket).createSignedUrl(path, 120);

  // Shared --------------------------------------------------------------------

  /// Writes `sort_order` 1, 2, 3… for [ids] in [table], only where it changed.
  Future<void> saveOrder(
    String table,
    List<String> ids,
    Map<String, int> current,
  ) async {
    for (var index = 0; index < ids.length; index++) {
      if (current[ids[index]] != index + 1) {
        await _client
            .from(table)
            .update({'sort_order': index + 1})
            .eq('id', ids[index]);
      }
    }
  }

  String publicUrl(String bucket, String path) =>
      _client.storage.from(bucket).getPublicUrl(path);
}

final mediaRepositoryProvider = Provider<MediaRepository>(
  (ref) => MediaRepository(
    ref.watch(supabaseProvider),
    ref.watch(storageUploaderProvider),
  ),
);

final propertyImagesProvider = FutureProvider.autoDispose
    .family<List<PropertyImage>, String>(
      (ref, propertyId) =>
          ref.watch(mediaRepositoryProvider).images(propertyId),
    );

final propertyVideosProvider = FutureProvider.autoDispose
    .family<List<PropertyVideo>, String>(
      (ref, propertyId) =>
          ref.watch(mediaRepositoryProvider).videos(propertyId),
    );

final propertyDocumentsProvider = FutureProvider.autoDispose
    .family<List<PropertyDocument>, String>(
      (ref, propertyId) =>
          ref.watch(mediaRepositoryProvider).documents(propertyId),
    );
