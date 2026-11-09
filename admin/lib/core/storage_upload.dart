import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:web/web.dart' as web;

import '../features/media/media_rules.dart';
import 'config/env.dart';
import 'supabase_client.dart';

/// Uploads a file to Supabase Storage with progress reports.
/// (The Supabase SDK has no progress, so this talks to the Storage API
/// directly with the signed-in admin's token. Storage still applies the
/// bucket's size and type limits and the admin-only policies.)
class StorageUploader {
  StorageUploader(this._client);

  final SupabaseClient _client;

  Future<void> upload({
    required String bucket,
    required String path,
    required web.Blob body,
    required String contentType,
    void Function(double fraction)? onProgress,
    String cacheControl = 'max-age=31536000',
  }) {
    final token = _client.auth.currentSession?.accessToken;
    if (token == null) {
      return Future.error(
        const MediaException('Your session ended. Please sign in again.'),
      );
    }
    final completer = Completer<void>();
    final request = web.XMLHttpRequest()
      ..open(
        'POST',
        '${Env.supabaseUrl}/storage/v1/object/$bucket/${Uri.encodeFull(path)}',
      )
      ..setRequestHeader('Authorization', 'Bearer $token')
      ..setRequestHeader('apikey', Env.supabasePublishableKey)
      ..setRequestHeader('Content-Type', contentType)
      ..setRequestHeader('cache-control', cacheControl)
      ..setRequestHeader('x-upsert', 'false');

    request.upload.addEventListener(
      'progress',
      ((web.ProgressEvent event) {
        if (event.lengthComputable && event.total > 0) {
          onProgress?.call(event.loaded / event.total);
        }
      }).toJS,
    );
    request.addEventListener(
      'load',
      ((web.Event _) {
        if (request.status >= 200 && request.status < 300) {
          onProgress?.call(1);
          completer.complete();
        } else {
          completer.completeError(
            MediaException(_explain(request.status, request.responseText)),
          );
        }
      }).toJS,
    );
    request.addEventListener(
      'error',
      ((web.Event _) => completer.completeError(
        const MediaException(
          "Upload failed: can't reach the server. Check the connection and retry.",
        ),
      )).toJS,
    );
    request.send(body);
    return completer.future;
  }

  /// Removes files; never throws (a leftover file is harmless).
  Future<void> remove(String bucket, List<String> paths) async {
    if (paths.isEmpty) return;
    try {
      await _client.storage.from(bucket).remove(paths);
    } catch (_) {}
  }

  static String _explain(int status, String body) {
    String message = '';
    try {
      final json = jsonDecode(body);
      if (json is Map) message = '${json['message'] ?? json['error'] ?? ''}';
    } catch (_) {}
    final lower = message.toLowerCase();
    if (status == 413 ||
        lower.contains('too large') ||
        lower.contains('exceeded the maximum')) {
      return 'The file is larger than this storage allows.';
    }
    if (lower.contains('mime') ||
        lower.contains('not supported') ||
        status == 415) {
      return 'This file type is not allowed here.';
    }
    if (status == 401 ||
        status == 403 ||
        lower.contains('row-level security')) {
      return 'You do not have permission to upload files.';
    }
    if (status == 409 || lower.contains('already exists')) {
      return 'A file with this name already exists.';
    }
    return 'Upload failed ($status). Please retry.';
  }
}

final storageUploaderProvider = Provider<StorageUploader>(
  (ref) => StorageUploader(ref.watch(supabaseProvider)),
);
