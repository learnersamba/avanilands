import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/browser_files.dart';
import '../../core/errors.dart';
import '../../core/storage_upload.dart';
import '../../core/theme.dart';
import '../../core/widgets/common.dart';
import 'media_repository.dart';
import 'media_rules.dart';
import 'upload_progress.dart';

/// Videos of one property: YouTube links (recommended, decision 20) or MP4
/// uploads up to 50 MB. The main video is shown first on the website.
class VideosManager extends ConsumerStatefulWidget {
  const VideosManager({
    super.key,
    required this.propertyId,
    required this.onChanged,
  });

  final String propertyId;
  final VoidCallback onChanged;

  @override
  ConsumerState<VideosManager> createState() => _VideosManagerState();
}

class _VideosManagerState extends ConsumerState<VideosManager> {
  UploadItem? _upload;
  bool _busy = false;

  MediaRepository get _repository => ref.read(mediaRepositoryProvider);

  void _changed() {
    ref.invalidate(propertyVideosProvider(widget.propertyId));
    widget.onChanged();
  }

  Future<void> _run(Future<void> Function() action, {String? done}) async {
    setState(() => _busy = true);
    try {
      await action();
      if (mounted && done != null) showMessage(context, done);
    } catch (error) {
      if (mounted) showMessage(context, friendlyError(error), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
      _changed();
    }
  }

  Future<void> _addYoutube() async {
    final result = await showDialog<({String id, String title})>(
      context: context,
      builder: (_) => const _YoutubeDialog(),
    );
    if (result == null) return;
    await _run(
      () => _repository.addYoutube(
        widget.propertyId,
        youtubeId: result.id,
        title: result.title,
      ),
      done: 'Video added.',
    );
  }

  Future<void> _uploadMp4() async {
    final files = await pickFiles(accept: MediaKind.video.accept);
    if (files.isEmpty || !mounted) return;
    final file = files.first;
    final problem = checkFile(
      MediaKind.video,
      name: file.name,
      type: file.type,
      size: file.size,
    );
    if (problem != null) {
      showMessage(context, problem, error: true);
      return;
    }
    final item = UploadItem(name: file.name)..status = UploadStatus.uploading;
    setState(() => _upload = item);
    final path = '${widget.propertyId}/videos/${randomId()}.mp4';
    var uploaded = false;
    try {
      await ref
          .read(storageUploaderProvider)
          .upload(
            bucket: mediaBucket,
            path: path,
            body: file,
            contentType: 'video/mp4',
            onProgress: (fraction) {
              if (mounted) setState(() => item.progress = fraction);
            },
          );
      uploaded = true;
      await _repository.addUploadedVideo(
        widget.propertyId,
        storagePath: path,
        title: titleFromFileName(file.name),
      );
      if (mounted) setState(() => _upload = null);
      _changed();
    } catch (error) {
      if (uploaded) {
        await ref.read(storageUploaderProvider).remove(mediaBucket, [path]);
      }
      if (mounted) {
        setState(() {
          item
            ..status = UploadStatus.failed
            ..error = friendlyError(error);
        });
      }
    }
  }

  Future<void> _onAction(
    List<PropertyVideo> videos,
    int index,
    String action,
  ) async {
    final video = videos[index];
    switch (action) {
      case 'primary':
        await _run(
          () => _repository.setPrimaryVideo(video.id),
          done: 'Main video changed.',
        );
      case 'up' || 'down':
        final ordered = [...videos];
        final to = action == 'up' ? index - 1 : index + 1;
        ordered.insert(to, ordered.removeAt(index));
        await _run(
          () => _repository.saveOrder(
            'property_videos',
            [for (final v in ordered) v.id],
            {for (final v in videos) v.id: v.sortOrder},
          ),
        );
      case 'open':
        openInNewTab(
          video.isYoutube
              ? 'https://www.youtube.com/watch?v=${video.youtubeId}'
              : _repository.publicUrl(mediaBucket, video.storagePath!),
        );
      case 'delete':
        final ok = await confirmAction(
          context,
          title: 'Remove this video?',
          message: video.isYoutube
              ? 'The link is removed from the property. The video stays on YouTube.'
              : 'The video file is deleted.',
          confirmLabel: 'Remove',
          destructive: true,
        );
        if (ok) {
          await _run(
            () => _repository.deleteVideo(video),
            done: 'Video removed.',
          );
        }
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(propertyVideosProvider(widget.propertyId));
    return SectionCard(
      title: 'Videos',
      trailing: Wrap(
        spacing: 8,
        children: [
          OutlinedButton.icon(
            onPressed: _busy ? null : _addYoutube,
            icon: const Icon(Icons.smart_display_outlined, size: 18),
            label: const Text('Add YouTube link'),
          ),
          OutlinedButton.icon(
            onPressed: _busy || _upload?.status == UploadStatus.uploading
                ? null
                : _uploadMp4,
            icon: const Icon(Icons.upload, size: 18),
            label: const Text('Upload MP4'),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'YouTube is recommended (unlisted is fine): it is free and plays smoothly on phones. '
            'MP4 uploads are limited to 50 MB.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          if (_upload != null)
            UploadQueueView(
              items: [_upload!],
              onRetry: (_) => _uploadMp4(),
              onDismiss: (_) => setState(() => _upload = null),
            ),
          AsyncValueView(
            value: async,
            onRetry: () =>
                ref.invalidate(propertyVideosProvider(widget.propertyId)),
            data: (videos) => videos.isEmpty
                ? const EmptyState(
                    icon: Icons.videocam_off_outlined,
                    message: 'No videos.',
                  )
                : Column(
                    children: [
                      for (var i = 0; i < videos.length; i++)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: videos[i].isYoutube
                                ? Image.network(
                                    'https://img.youtube.com/vi/${videos[i].youtubeId}/mqdefault.jpg',
                                    width: 96,
                                    height: 54,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, _, _) =>
                                        const _VideoIcon(),
                                  )
                                : const _VideoIcon(),
                          ),
                          title: Text(
                            videos[i].title ??
                                (videos[i].isYoutube
                                    ? 'YouTube video'
                                    : 'Uploaded video'),
                          ),
                          subtitle: Text(
                            videos[i].isYoutube
                                ? 'YouTube · ${videos[i].youtubeId}'
                                : 'MP4 file',
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (videos[i].isPrimary)
                                const Pill(
                                  label: 'Main video',
                                  color: BrandColors.sand,
                                ),
                              PopupMenuButton<String>(
                                tooltip: 'Video actions',
                                enabled: !_busy,
                                onSelected: (action) =>
                                    _onAction(videos, i, action),
                                itemBuilder: (_) => [
                                  if (!videos[i].isPrimary)
                                    const PopupMenuItem(
                                      value: 'primary',
                                      child: Text('Make main video'),
                                    ),
                                  if (i > 0)
                                    const PopupMenuItem(
                                      value: 'up',
                                      child: Text('Move up'),
                                    ),
                                  if (i < videos.length - 1)
                                    const PopupMenuItem(
                                      value: 'down',
                                      child: Text('Move down'),
                                    ),
                                  const PopupMenuItem(
                                    value: 'open',
                                    child: Text('Watch'),
                                  ),
                                  const PopupMenuItem(
                                    value: 'delete',
                                    child: Text('Remove'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _VideoIcon extends StatelessWidget {
  const _VideoIcon();

  @override
  Widget build(BuildContext context) => Container(
    width: 96,
    height: 54,
    color: BrandColors.line,
    child: const Icon(Icons.movie_outlined, color: BrandColors.sold),
  );
}

class _YoutubeDialog extends StatefulWidget {
  const _YoutubeDialog();

  @override
  State<_YoutubeDialog> createState() => _YoutubeDialogState();
}

class _YoutubeDialogState extends State<_YoutubeDialog> {
  final _formKey = GlobalKey<FormState>();
  final _link = TextEditingController();
  final _title = TextEditingController();

  @override
  void dispose() {
    _link.dispose();
    _title.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.pop(context, (id: youtubeId(_link.text)!, title: _title.text));
  }

  @override
  Widget build(BuildContext context) {
    final id = youtubeId(_link.text);
    return AlertDialog(
      title: const Text('Add a YouTube video'),
      content: SizedBox(
        width: 460,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _link,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'YouTube link',
                  hintText: 'https://youtu.be/…  or  https://www.youtube.com/watch?v=…',
                ),
                onChanged: (_) => setState(() {}),
                validator: (value) => youtubeId(value ?? '') == null
                    ? 'This is not a YouTube video link.'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _title,
                maxLength: 120,
                decoration: const InputDecoration(
                  labelText: 'Title (optional)',
                  hintText: 'e.g. Drone walkthrough',
                ),
                onFieldSubmitted: (_) => _submit(),
              ),
              if (id != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    'https://img.youtube.com/vi/$id/mqdefault.jpg',
                    height: 140,
                    errorBuilder: (_, _, _) => const SizedBox.shrink(),
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Add video')),
      ],
    );
  }
}
