import 'package:flutter/material.dart';

import '../../core/theme.dart';

enum UploadStatus { waiting, preparing, uploading, failed }

/// One file in an upload queue.
class UploadItem {
  UploadItem({required this.name, this.error})
    : status = error == null ? UploadStatus.waiting : UploadStatus.failed;

  final String name;
  UploadStatus status;
  double progress = 0;
  String? error;

  /// False for files refused before upload (wrong type, too big): retrying won't help.
  bool get canRetry => status == UploadStatus.failed && !_refused;
  bool _refused = false;

  factory UploadItem.refused(String name, String error) =>
      UploadItem(name: name, error: error).._refused = true;
}

/// A row per file: name, progress bar or error, retry / dismiss.
class UploadQueueView extends StatelessWidget {
  const UploadQueueView({
    super.key,
    required this.items,
    required this.onRetry,
    required this.onDismiss,
  });

  final List<UploadItem> items;
  final ValueChanged<UploadItem> onRetry;
  final ValueChanged<UploadItem> onDismiss;

  @override
  Widget build(BuildContext context) {
    final small = Theme.of(context).textTheme.bodySmall;
    return Column(
      children: [
        for (final item in items)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                Icon(
                  item.status == UploadStatus.failed
                      ? Icons.error_outline
                      : Icons.upload_file,
                  color: item.status == UploadStatus.failed
                      ? BrandColors.danger
                      : BrandColors.forest,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.name, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 4),
                      if (item.status == UploadStatus.failed)
                        Text(
                          item.error ?? 'Failed.',
                          style: small?.copyWith(color: BrandColors.danger),
                        )
                      else ...[
                        LinearProgressIndicator(
                          value: item.status == UploadStatus.uploading
                              ? item.progress
                              : null,
                        ),
                        const SizedBox(height: 2),
                        Text(switch (item.status) {
                          UploadStatus.waiting => 'Waiting…',
                          UploadStatus.preparing => 'Preparing…',
                          _ => 'Uploading ${(item.progress * 100).round()}%',
                        }, style: small),
                      ],
                    ],
                  ),
                ),
                if (item.canRetry)
                  TextButton(
                    onPressed: () => onRetry(item),
                    child: const Text('Retry'),
                  ),
                if (item.status == UploadStatus.failed)
                  IconButton(
                    tooltip: 'Dismiss',
                    onPressed: () => onDismiss(item),
                    icon: const Icon(Icons.close, size: 18),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}
