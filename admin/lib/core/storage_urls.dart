import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme.dart';
import 'supabase_client.dart';

/// Public URL of a file in the `property-media` bucket.
final mediaUrlProvider = Provider<String Function(String path)>((ref) {
  final storage = ref.watch(supabaseProvider).storage.from('property-media');
  return storage.getPublicUrl;
});

/// Small square photo; a placeholder when there is no photo or it fails to load.
class Thumbnail extends ConsumerWidget {
  const Thumbnail({super.key, required this.path, this.size = 48});

  final String? path;
  final double size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final placeholder = Container(
      width: size,
      height: size,
      color: BrandColors.line,
      child: Icon(
        Icons.landscape_outlined,
        size: size * 0.45,
        color: BrandColors.sold,
      ),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: path == null
          ? placeholder
          : Image.network(
              ref.watch(mediaUrlProvider)(path!),
              width: size,
              height: size,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => placeholder,
            ),
    );
  }
}
