import 'dart:async';
import 'dart:js_interop';
import 'dart:math' as math;

import 'package:web/web.dart' as web;

import '../features/media/media_rules.dart';

/// Opens the browser's file picker. Returns an empty list when cancelled.
Future<List<web.File>> pickFiles({
  required String accept,
  bool multiple = false,
}) {
  final completer = Completer<List<web.File>>();
  final input = web.HTMLInputElement()
    ..type = 'file'
    ..accept = accept
    ..multiple = multiple
    ..style.display = 'none';
  void finish(List<web.File> files) {
    if (!completer.isCompleted) completer.complete(files);
    input.remove();
  }

  input.addEventListener(
    'change',
    ((web.Event _) {
      final list = input.files;
      finish([
        if (list != null)
          for (var i = 0; i < list.length; i++) list.item(i)!,
      ]);
    }).toJS,
  );
  input.addEventListener('cancel', ((web.Event _) => finish(const [])).toJS);
  web.document.body!.append(input);
  input.click();
  return completer.future;
}

/// A random id (UUID v4) for storage file names and new rows.
String randomId() => web.window.crypto.randomUUID();

/// One shrunk copy of a photo.
class PhotoVariant {
  const PhotoVariant({
    required this.size,
    required this.blob,
    required this.width,
    required this.height,
    required this.contentType,
  });

  final PhotoSize size;
  final web.Blob blob;
  final int width;
  final int height;
  final String contentType;

  String get extension => contentType == 'image/webp' ? 'webp' : 'jpg';
}

/// Shrinks a photo in the browser into the three sizes (decision 21).
/// Re-drawing on a canvas also drops the camera's location data (EXIF).
/// Browsers that can't make WebP (older Safari) get JPEG instead.
Future<List<PhotoVariant>> shrinkPhoto(web.File file) async {
  final web.ImageBitmap bitmap;
  try {
    bitmap = await web.window.createImageBitmap(file).toDart;
  } catch (_) {
    throw const MediaException(
      'This browser cannot open this photo. Save it as JPEG and try again.',
    );
  }
  try {
    final variants = <PhotoVariant>[];
    for (final size in PhotoSize.values) {
      final fit = fitWithin(bitmap.width, bitmap.height, size.longestSide);
      final canvas = web.OffscreenCanvas(fit.width, fit.height);
      final context =
          canvas.getContext('2d')! as web.OffscreenCanvasRenderingContext2D
            ..imageSmoothingEnabled = true
            ..imageSmoothingQuality = 'high';
      context.drawImage(bitmap, 0, 0, fit.width, fit.height);
      var blob = await canvas
          .convertToBlob(
            web.ImageEncodeOptions(type: 'image/webp', quality: 0.82),
          )
          .toDart;
      if (blob.type != 'image/webp') {
        blob = await canvas
            .convertToBlob(
              web.ImageEncodeOptions(type: 'image/jpeg', quality: 0.85),
            )
            .toDart;
      }
      variants.add(
        PhotoVariant(
          size: size,
          blob: blob,
          width: fit.width,
          height: fit.height,
          contentType: blob.type,
        ),
      );
    }
    return variants;
  } finally {
    bitmap.close();
  }
}

/// A single resized copy (used for location cover photos).
Future<PhotoVariant> shrinkPhotoTo(web.File file, int longestSide) async {
  final bitmap = await web.window.createImageBitmap(file).toDart;
  try {
    final fit = fitWithin(
      bitmap.width,
      bitmap.height,
      math.max(1, longestSide),
    );
    final canvas = web.OffscreenCanvas(fit.width, fit.height);
    final context =
        canvas.getContext('2d')! as web.OffscreenCanvasRenderingContext2D
          ..imageSmoothingQuality = 'high';
    context.drawImage(bitmap, 0, 0, fit.width, fit.height);
    var blob = await canvas
        .convertToBlob(
          web.ImageEncodeOptions(type: 'image/webp', quality: 0.82),
        )
        .toDart;
    if (blob.type != 'image/webp') {
      blob = await canvas
          .convertToBlob(
            web.ImageEncodeOptions(type: 'image/jpeg', quality: 0.85),
          )
          .toDart;
    }
    return PhotoVariant(
      size: PhotoSize.large,
      blob: blob,
      width: fit.width,
      height: fit.height,
      contentType: blob.type,
    );
  } finally {
    bitmap.close();
  }
}

/// Opens a link in a new browser tab.
void openInNewTab(String url) => web.window.open(url, '_blank');
