import 'package:flutter/material.dart';

import '../../core/formatting.dart';
import '../../core/theme.dart';
import 'activity_repository.dart';
import 'activity_text.dart';

/// One line of the activity feed: what happened, who, when.
class ActivityTile extends StatelessWidget {
  const ActivityTile({
    super.key,
    required this.entry,
    required this.actorName,
    this.propertyCode,
  });

  final AuditEntry entry;
  final String actorName;
  final String? propertyCode;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(_icon(entry.entityType), size: 20, color: BrandColors.forest),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  describeActivity(entry, propertyCode: propertyCode),
                  style: textTheme.bodyMedium,
                ),
                const SizedBox(height: 2),
                Tooltip(
                  message: formatDateTime(entry.createdAt),
                  child: Text(
                    '$actorName · ${formatRelative(entry.createdAt)}',
                    style: textTheme.bodySmall?.copyWith(
                      color: BrandColors.sold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static IconData _icon(String entityType) => switch (entityType) {
    'property' => Icons.landscape_outlined,
    'image' => Icons.photo_outlined,
    'video' => Icons.videocam_outlined,
    'document' => Icons.description_outlined,
    'enquiry' => Icons.mail_outline,
    'site_visit' => Icons.event_available_outlined,
    'booking' => Icons.key_outlined,
    'content' || 'faq' || 'testimonial' || 'banner' => Icons.web_outlined,
    'location' => Icons.place_outlined,
    'admin' => Icons.admin_panel_settings_outlined,
    'settings' => Icons.settings_outlined,
    _ => Icons.edit_note,
  };
}

/// Name to show for an audit entry's actor.
String actorLabel(String? actorId, Map<String, String> adminNames) {
  if (actorId == null) return 'System / website';
  return adminNames[actorId] ?? 'Former admin';
}
