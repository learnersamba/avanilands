import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/browser_files.dart';
import '../../core/errors.dart';
import '../../core/storage_upload.dart';
import '../../core/supabase_client.dart';
import '../../core/theme.dart';
import '../../core/widgets/common.dart';
import '../media/media_repository.dart' show siteAssetsBucket;
import '../media/media_rules.dart';

/// Picks a photo, shrinks it in the browser (WebP) and uploads it to
/// `site-assets/content/<folder>/`. Returns the stored path, or null.
Future<String?> uploadContentImage(
  BuildContext context,
  WidgetRef ref, {
  required String folder,
  int longestSide = 2000,
}) async {
  final files = await pickFiles(accept: MediaKind.photo.accept);
  if (files.isEmpty || !context.mounted) return null;
  final file = files.first;
  final problem = checkFile(
    MediaKind.photo,
    name: file.name,
    type: file.type,
    size: file.size,
  );
  if (problem != null) {
    showMessage(context, problem, error: true);
    return null;
  }
  showMessage(context, 'Uploading photo…');
  try {
    final photo = await shrinkPhotoTo(file, longestSide);
    final path = 'content/$folder/${randomId()}.${photo.extension}';
    await ref
        .read(storageUploaderProvider)
        .upload(
          bucket: siteAssetsBucket,
          path: path,
          body: photo.blob,
          contentType: photo.contentType,
        );
    if (context.mounted) showMessage(context, 'Photo uploaded.');
    return path;
  } catch (error) {
    if (context.mounted) {
      showMessage(context, friendlyError(error), error: true);
    }
    return null;
  }
}

/// Public address of a website content photo.
final contentImageUrlProvider = Provider<String Function(String path)>(
  (ref) =>
      ref.watch(supabaseProvider).storage.from(siteAssetsBucket).getPublicUrl,
);

/// A photo box with Upload / Replace / Remove.
class ContentImageField extends ConsumerWidget {
  const ContentImageField({
    super.key,
    required this.label,
    required this.path,
    required this.folder,
    required this.onChanged,
    this.width = 240,
  });

  final String label;
  final String? path;
  final String folder;
  final ValueChanged<String?> onChanged;
  final double width;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final url = ref.watch(contentImageUrlProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 6),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Container(
                width: width,
                height: width * 9 / 16,
                color: BrandColors.line,
                child: path == null
                    ? const Icon(Icons.image_outlined, color: BrandColors.sold)
                    : Image.network(url(path!), fit: BoxFit.cover),
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                OutlinedButton.icon(
                  onPressed: () async {
                    final uploaded = await uploadContentImage(
                      context,
                      ref,
                      folder: folder,
                    );
                    if (uploaded != null) onChanged(uploaded);
                  },
                  icon: const Icon(Icons.upload, size: 18),
                  label: Text(path == null ? 'Upload photo' : 'Replace photo'),
                ),
                if (path != null)
                  TextButton(
                    onPressed: () => onChanged(null),
                    child: const Text('Remove photo'),
                  ),
              ],
            ),
          ],
        ),
      ],
    );
  }
}
