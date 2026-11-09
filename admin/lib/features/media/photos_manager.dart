import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:web/web.dart' as web;

import '../../core/browser_files.dart';
import '../../core/errors.dart';
import '../../core/storage_upload.dart';
import '../../core/theme.dart';
import '../../core/widgets/common.dart';
import 'media_repository.dart';
import 'media_rules.dart';
import 'upload_progress.dart';

/// Photos of one property: upload (shrunk in the browser), reorder by
/// dragging, choose the cover, describe, replace and delete.
/// Changes are saved straight away, not with "Save changes".
class PhotosManager extends ConsumerStatefulWidget {
  const PhotosManager({
    super.key,
    required this.propertyId,
    required this.onChanged,
  });

  final String propertyId;

  /// Called after any change (the editor refreshes its checklist).
  final VoidCallback onChanged;

  @override
  ConsumerState<PhotosManager> createState() => _PhotosManagerState();
}

class _PendingPhoto {
  _PendingPhoto(this.file, this.item);

  final web.File file;
  final UploadItem item;
}

class _PhotosManagerState extends ConsumerState<PhotosManager> {
  final List<_PendingPhoto> _queue = [];
  final Set<String> _busy = {};
  List<PropertyImage>? _optimistic;
  bool _running = false;

  MediaRepository get _repository => ref.read(mediaRepositoryProvider);
  StorageUploader get _uploader => ref.read(storageUploaderProvider);

  void _changed() {
    ref.invalidate(propertyImagesProvider(widget.propertyId));
    widget.onChanged();
  }

  Future<void> _addPhotos(int existing) async {
    final files = await pickFiles(
      accept: MediaKind.photo.accept,
      multiple: true,
    );
    if (files.isEmpty || !mounted) return;
    var room = maxPhotosPerProperty - existing - _queue.length;
    setState(() {
      for (final file in files) {
        final problem = checkFile(
          MediaKind.photo,
          name: file.name,
          type: file.type,
          size: file.size,
        );
        if (problem != null) {
          _queue.add(
            _PendingPhoto(file, UploadItem.refused(file.name, problem)),
          );
        } else if (room <= 0) {
          _queue.add(
            _PendingPhoto(
              file,
              UploadItem.refused(
                file.name,
                'A property can have at most $maxPhotosPerProperty photos.',
              ),
            ),
          );
        } else {
          room--;
          _queue.add(_PendingPhoto(file, UploadItem(name: file.name)));
        }
      }
    });
    await _runQueue();
  }

  Future<void> _runQueue() async {
    if (_running) return;
    _running = true;
    try {
      while (true) {
        final next = _queue
            .where((p) => p.item.status == UploadStatus.waiting)
            .firstOrNull;
        if (next == null || !mounted) break;
        await _upload(next);
      }
    } finally {
      _running = false;
    }
  }

  /// Shrink → upload three sizes → add the row. Any failure removes the
  /// files already uploaded for this photo, so nothing is left behind.
  Future<void> _upload(_PendingPhoto pending) async {
    final item = pending.item;
    final uploaded = <String>[];
    try {
      setState(() => item.status = UploadStatus.preparing);
      final variants = await shrinkPhoto(pending.file);
      final id = randomId();
      setState(() => item.status = UploadStatus.uploading);
      final total = variants.fold<int>(0, (sum, v) => sum + v.blob.size);
      var done = 0;
      final paths = <PhotoSize, String>{};
      for (final variant in variants) {
        final path =
            '${widget.propertyId}/$id-${variant.size.name}.${variant.extension}';
        await _uploader.upload(
          bucket: mediaBucket,
          path: path,
          body: variant.blob,
          contentType: variant.contentType,
          onProgress: (fraction) {
            if (mounted) {
              setState(
                () => item.progress =
                    (done + fraction * variant.blob.size) / total,
              );
            }
          },
        );
        uploaded.add(path);
        paths[variant.size] = path;
        done += variant.blob.size;
      }
      final large = variants.last;
      await _repository.insertImage({
        'id': id,
        'property_id': widget.propertyId,
        'path_thumb': paths[PhotoSize.thumb],
        'path_medium': paths[PhotoSize.medium],
        'path_large': paths[PhotoSize.large],
        'width': large.width,
        'height': large.height,
      });
      if (!mounted) return;
      setState(() => _queue.remove(pending));
      _changed();
    } catch (error) {
      await _uploader.remove(mediaBucket, uploaded);
      if (mounted) {
        setState(() {
          item
            ..status = UploadStatus.failed
            ..error = friendlyError(error);
        });
      }
    }
  }

  Future<void> _act(
    String imageId,
    Future<void> Function() action, {
    String? done,
  }) async {
    setState(() => _busy.add(imageId));
    try {
      await action();
      if (mounted && done != null) showMessage(context, done);
    } catch (error) {
      if (mounted) showMessage(context, friendlyError(error), error: true);
    } finally {
      if (mounted) setState(() => _busy.remove(imageId));
      _changed();
    }
  }

  Future<void> _move(
    List<PropertyImage> images,
    String draggedId,
    int toIndex,
  ) async {
    final ordered = [...images];
    final from = ordered.indexWhere((image) => image.id == draggedId);
    if (from < 0 || from == toIndex) return;
    ordered.insert(toIndex, ordered.removeAt(from));
    setState(() => _optimistic = ordered);
    try {
      await _repository.reorderImages(widget.propertyId, [
        for (final image in ordered) image.id,
      ]);
    } catch (error) {
      if (mounted) showMessage(context, friendlyError(error), error: true);
    } finally {
      _changed();
    }
  }

  Future<void> _replace(PropertyImage image) async {
    final files = await pickFiles(accept: MediaKind.photo.accept);
    if (files.isEmpty || !mounted) return;
    final file = files.first;
    final problem = checkFile(
      MediaKind.photo,
      name: file.name,
      type: file.type,
      size: file.size,
    );
    if (problem != null) {
      showMessage(context, problem, error: true);
      return;
    }
    await _act(image.id, () async {
      final uploaded = <String>[];
      try {
        final variants = await shrinkPhoto(file);
        final version = randomId();
        final paths = <PhotoSize, String>{};
        for (final variant in variants) {
          final path =
              '${widget.propertyId}/$version-${variant.size.name}.${variant.extension}';
          await _uploader.upload(
            bucket: mediaBucket,
            path: path,
            body: variant.blob,
            contentType: variant.contentType,
          );
          uploaded.add(path);
          paths[variant.size] = path;
        }
        await _repository.replaceImageFiles(image, {
          'path_thumb': paths[PhotoSize.thumb],
          'path_medium': paths[PhotoSize.medium],
          'path_large': paths[PhotoSize.large],
          'width': variants.last.width,
          'height': variants.last.height,
        });
      } catch (_) {
        await _uploader.remove(mediaBucket, uploaded);
        rethrow;
      }
    }, done: 'Photo replaced.');
  }

  Future<void> _editAlt(PropertyImage image) async {
    final controller = TextEditingController(text: image.altText);
    final text = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Photo description'),
        content: SizedBox(
          width: 420,
          child: TextField(
            controller: controller,
            autofocus: true,
            maxLength: 160,
            decoration: const InputDecoration(
              labelText: 'What does the photo show?',
              hintText: 'e.g. Entrance road with avenue trees',
              helperText:
                  'Read out by screen readers and used by Google Images.',
            ),
            onSubmitted: (value) => Navigator.pop(context, value),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (text == null) return;
    await _act(
      image.id,
      () => _repository.setAltText(image.id, text),
      done: 'Description saved.',
    );
  }

  Future<void> _delete(PropertyImage image) async {
    final ok = await confirmAction(
      context,
      title: 'Delete this photo?',
      message:
          'The photo is removed from the property and its files are deleted.',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!ok) return;
    await _act(
      image.id,
      () => _repository.deleteImage(image),
      done: 'Photo deleted.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(propertyImagesProvider(widget.propertyId));
    ref.listen(propertyImagesProvider(widget.propertyId), (_, next) {
      if (next.hasValue && _optimistic != null) {
        setState(() => _optimistic = null);
      }
    });
    final images = _optimistic ?? async.value ?? const <PropertyImage>[];
    final textTheme = Theme.of(context).textTheme;

    return SectionCard(
      title: 'Photos (${images.length}/$maxPhotosPerProperty)',
      trailing: FilledButton.icon(
        onPressed: images.length + _queue.length >= maxPhotosPerProperty
            ? null
            : () => _addPhotos(images.length),
        icon: const Icon(Icons.add_photo_alternate_outlined, size: 18),
        label: const Text('Add photos'),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Saved straight away. Drag photos to change the order; the ★ photo is the cover on the website. '
            'Photos are shrunk before upload and location data inside them is removed.',
            style: textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          if (_queue.isNotEmpty)
            UploadQueueView(
              items: [for (final p in _queue) p.item],
              onRetry: (item) {
                setState(() => item.status = UploadStatus.waiting);
                _runQueue();
              },
              onDismiss: (item) => setState(
                () => _queue.removeWhere((p) => identical(p.item, item)),
              ),
            ),
          if (async.hasError && async.value == null)
            ErrorView(
              error: async.error!,
              onRetry: () =>
                  ref.invalidate(propertyImagesProvider(widget.propertyId)),
            )
          else if (!async.hasValue)
            const LoadingView()
          else if (images.isEmpty)
            const EmptyState(
              icon: Icons.photo_library_outlined,
              message:
                  'No photos yet. The first photo you add becomes the cover.',
            )
          else
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (var i = 0; i < images.length; i++)
                  _PhotoTile(
                    image: images[i],
                    index: i,
                    count: images.length,
                    busy: _busy.contains(images[i].id),
                    url: _repository.publicUrl(
                      mediaBucket,
                      images[i].pathThumb,
                    ),
                    onDrop: (draggedId) => _move(images, draggedId, i),
                    onAction: (action) => switch (action) {
                      'cover' => _act(
                        images[i].id,
                        () => _repository.setCover(images[i].id),
                        done: 'Cover photo changed.',
                      ),
                      'alt' => _editAlt(images[i]),
                      'earlier' => _move(images, images[i].id, i - 1),
                      'later' => _move(images, images[i].id, i + 1),
                      'replace' => _replace(images[i]),
                      'delete' => _delete(images[i]),
                      _ => Future.value(),
                    },
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

class _PhotoTile extends StatelessWidget {
  const _PhotoTile({
    required this.image,
    required this.index,
    required this.count,
    required this.busy,
    required this.url,
    required this.onDrop,
    required this.onAction,
  });

  static const _width = 176.0;
  static const _height = 132.0;

  final PropertyImage image;
  final int index;
  final int count;
  final bool busy;
  final String url;
  final ValueChanged<String> onDrop;
  final Future<void> Function(String action) onAction;

  Widget _picture({double opacity = 1}) => Opacity(
    opacity: opacity,
    child: ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Image.network(
        url,
        width: _width,
        height: _height,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => Container(
          width: _width,
          height: _height,
          color: BrandColors.line,
          child: const Icon(
            Icons.broken_image_outlined,
            color: BrandColors.sold,
          ),
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return DragTarget<String>(
      onWillAcceptWithDetails: (details) => details.data != image.id,
      onAcceptWithDetails: (details) => onDrop(details.data),
      builder: (context, candidates, _) => Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: candidates.isNotEmpty
                ? BrandColors.sand
                : Colors.transparent,
            width: 3,
          ),
        ),
        child: Stack(
          children: [
            Draggable<String>(
              data: image.id,
              feedback: Material(
                color: Colors.transparent,
                child: _picture(opacity: 0.85),
              ),
              childWhenDragging: _picture(opacity: 0.3),
              child: Tooltip(
                message: image.altText ?? 'Drag to move',
                child: _picture(),
              ),
            ),
            Positioned(
              left: 6,
              top: 6,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: image.isCover ? BrandColors.sand : Colors.black54,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  image.isCover ? '★ Cover' : '${index + 1}',
                  style: TextStyle(
                    color: image.isCover
                        ? BrandColors.forestDark
                        : Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            Positioned(
              right: 2,
              top: 2,
              child: busy
                  ? const Padding(
                      padding: EdgeInsets.all(10),
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : PopupMenuButton<String>(
                      tooltip: 'Photo actions',
                      icon: const CircleAvatar(
                        radius: 14,
                        backgroundColor: Colors.white,
                        child: Icon(
                          Icons.more_vert,
                          size: 18,
                          color: BrandColors.ink,
                        ),
                      ),
                      onSelected: onAction,
                      itemBuilder: (_) => [
                        if (!image.isCover)
                          const PopupMenuItem(
                            value: 'cover',
                            child: Text('Make cover photo'),
                          ),
                        const PopupMenuItem(
                          value: 'alt',
                          child: Text('Edit description'),
                        ),
                        if (index > 0)
                          const PopupMenuItem(
                            value: 'earlier',
                            child: Text('Move earlier'),
                          ),
                        if (index < count - 1)
                          const PopupMenuItem(
                            value: 'later',
                            child: Text('Move later'),
                          ),
                        const PopupMenuItem(
                          value: 'replace',
                          child: Text('Replace photo'),
                        ),
                        const PopupMenuItem(
                          value: 'delete',
                          child: Text('Delete'),
                        ),
                      ],
                    ),
            ),
            if (image.altText == null)
              const Positioned(
                left: 6,
                bottom: 6,
                child: Tooltip(
                  message: 'No description yet (the title is used)',
                  child: CircleAvatar(
                    radius: 11,
                    backgroundColor: Colors.white,
                    child: Icon(
                      Icons.short_text,
                      size: 14,
                      color: BrandColors.reserved,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
