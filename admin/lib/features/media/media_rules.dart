/// Plain rules for media files (no browser code, so they can be unit-tested).
/// Limits match the Storage buckets set in the Phase 1 migration.
library;

const _mb = 1024 * 1024;

enum MediaKind {
  /// Photos are shrunk in the browser before upload, so the original may be big.
  photo(
    maxBytes: 15 * _mb,
    types: {
      'image/jpeg',
      'image/png',
      'image/webp',
      'image/heic',
      'image/heif',
    },
    extensions: {'jpg', 'jpeg', 'png', 'webp', 'heic', 'heif'},
    accept: 'image/jpeg,image/png,image/webp,image/heic,image/heif,.heic,.heif',
    label: 'JPEG, PNG, WebP or HEIC photos',
  ),
  video(
    maxBytes: 50 * _mb,
    types: {'video/mp4'},
    extensions: {'mp4'},
    accept: 'video/mp4,.mp4',
    label: 'MP4 videos',
  ),
  document(
    maxBytes: 20 * _mb,
    types: {'application/pdf', 'image/jpeg', 'image/png'},
    extensions: {'pdf', 'jpg', 'jpeg', 'png'},
    accept: 'application/pdf,image/jpeg,image/png,.pdf',
    label: 'PDF, JPEG or PNG files',
  );

  const MediaKind({
    required this.maxBytes,
    required this.types,
    required this.extensions,
    required this.accept,
    required this.label,
  });

  final int maxBytes;
  final Set<String> types;
  final Set<String> extensions;

  /// Value for the file picker's `accept`.
  final String accept;
  final String label;
}

/// Most photos per property (same limit as the database trigger).
const maxPhotosPerProperty = 40;

/// Null when the file is acceptable, otherwise a sentence for the admin.
/// Some browsers leave `type` empty (e.g. HEIC), so the extension is checked too.
String? checkFile(
  MediaKind kind, {
  required String name,
  required String type,
  required int size,
}) {
  final extension = name.contains('.')
      ? name.split('.').last.toLowerCase()
      : '';
  final typeOk = kind.types.contains(type.toLowerCase());
  if (!typeOk && !(type.isEmpty && kind.extensions.contains(extension))) {
    return '"$name" is not allowed. Use ${kind.label}.';
  }
  if (size <= 0) return '"$name" is empty.';
  if (size > kind.maxBytes) {
    return '"$name" is ${formatBytes(size)}. The limit is ${formatBytes(kind.maxBytes)}.';
  }
  return null;
}

String formatBytes(int bytes) {
  if (bytes >= _mb) {
    return '${(bytes / _mb).toStringAsFixed(bytes >= 10 * _mb ? 0 : 1)} MB';
  }
  if (bytes >= 1024) return '${(bytes / 1024).round()} KB';
  return '$bytes B';
}

/// The three photo sizes (longest side in pixels), per decision 21.
enum PhotoSize {
  thumb(400),
  medium(1200),
  large(2000);

  const PhotoSize(this.longestSide);
  final int longestSide;
}

/// Width and height that fit within [longestSide] without enlarging.
({int width, int height}) fitWithin(int width, int height, int longestSide) {
  final longest = width > height ? width : height;
  if (longest <= longestSide) return (width: width, height: height);
  final scale = longestSide / longest;
  return (
    width: (width * scale).round().clamp(1, longestSide),
    height: (height * scale).round().clamp(1, longestSide),
  );
}

/// The 11-character video id from any common YouTube link, or null.
/// Accepts watch, youtu.be, shorts, embed and live links, or a bare id.
String? youtubeId(String input) {
  final text = input.trim();
  final bare = RegExp(r'^[A-Za-z0-9_-]{11}$');
  if (bare.hasMatch(text)) return text;
  final uri = Uri.tryParse(text.startsWith('http') ? text : 'https://$text');
  if (uri == null) return null;
  final host = uri.host
      .toLowerCase()
      .replaceFirst('www.', '')
      .replaceFirst('m.', '');
  String? candidate;
  if (host == 'youtu.be') {
    candidate = uri.pathSegments.isEmpty ? null : uri.pathSegments.first;
  } else if (host == 'youtube.com' ||
      host == 'music.youtube.com' ||
      host == 'youtube-nocookie.com') {
    final segments = uri.pathSegments;
    if (segments.isNotEmpty && segments.first == 'watch') {
      candidate = uri.queryParameters['v'];
    } else if (segments.length >= 2 &&
        const {'shorts', 'embed', 'live', 'v'}.contains(segments.first)) {
      candidate = segments[1];
    }
  }
  return (candidate != null && bare.hasMatch(candidate)) ? candidate : null;
}

/// Turns a file name into a readable default title: "layout_plan-v2.pdf" → "Layout plan v2".
String titleFromFileName(String name) {
  final base = name.contains('.')
      ? name.substring(0, name.lastIndexOf('.'))
      : name;
  final words = base.replaceAll(RegExp(r'[_\-]+'), ' ').trim();
  if (words.isEmpty) return 'Document';
  final title = words[0].toUpperCase() + words.substring(1);
  return title.length > 120 ? title.substring(0, 120) : title;
}

/// "a.PDF" → "pdf"; used for storage file names.
String extensionFor(String name, String type) {
  final fromType = switch (type) {
    'application/pdf' => 'pdf',
    'image/jpeg' => 'jpg',
    'image/png' => 'png',
    'image/webp' => 'webp',
    'video/mp4' => 'mp4',
    _ => null,
  };
  if (fromType != null) return fromType;
  return name.contains('.') ? name.split('.').last.toLowerCase() : 'bin';
}

/// A media problem with a sentence the admin can act on.
class MediaException implements Exception {
  const MediaException(this.message);

  final String message;

  @override
  String toString() => message;
}
