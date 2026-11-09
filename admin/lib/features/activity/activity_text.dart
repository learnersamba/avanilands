import '../../core/formatting.dart';
import '../site_visits/site_visit_models.dart';
import 'activity_repository.dart';

/// Entity types that can be filtered on the Activity page.
const activityEntityTypes = <String, String>{
  'property': 'Properties',
  'image': 'Photos',
  'video': 'Videos',
  'document': 'Documents',
  'enquiry': 'Enquiries',
  'site_visit': 'Site visits',
  'booking': 'Bookings',
  'content': 'Website content',
  'faq': 'FAQs',
  'testimonial': 'Testimonials',
  'banner': 'Banners',
  'location': 'Locations',
  'property_type': 'Property types',
  'amenity': 'Amenities',
  'nearby_place': 'Nearby places',
  'property_amenity': 'Property amenities',
  'admin': 'Admin users',
  'settings': 'Settings',
};

/// One readable line for an audit entry, e.g. "Marked AL-0007 as reserved".
/// [propertyCode] is the code of the property the entry belongs to.
String describeActivity(AuditEntry entry, {String? propertyCode}) {
  final d = entry.details;
  final code = (d['code'] as String?) ?? propertyCode;
  final property = code ?? 'a property';
  final on = code == null ? '' : ' on $code';
  final name = d['name'] as String?;
  final changes = (d['changes'] as Map?)?.cast<String, dynamic>() ?? const {};

  switch (entry.action) {
    case 'property.created':
      return 'Created property $property${_suffix(d['title'])}';
    case 'property.deleted':
      return 'Deleted draft $property${_suffix(d['title'])}';
    case 'property.updated':
      return 'Updated $property: ${_fieldList(changes.keys)}';
    case 'property.price_changed':
      return 'Changed the price of $property from ${_price(d['old_price'], d['old_price_type'])} '
          'to ${_price(d['new_price'], d['new_price_type'])}';
    case 'property.published':
      return 'Published $property';
    case 'property.unpublished':
      return 'Unpublished $property';
    case 'property.hidden':
      return 'Hid $property';
    case 'property.archived':
      return 'Archived $property';
    case 'property.marked_available':
      return 'Marked $property as available';
    case 'property.marked_reserved':
      return 'Marked $property as reserved';
    case 'property.marked_sold':
      return 'Marked $property as sold';
    case 'images.reordered':
      return 'Reordered the photos$on';
    case 'image.created':
      return 'Uploaded a photo$on';
    case 'image.deleted':
      return 'Deleted a photo$on';
    case 'image.updated':
      if (changes['is_cover']?['new'] == true) {
        return 'Changed the cover photo$on';
      }
      if (changes.keys.every((key) => key == 'is_cover')) {
        return 'Changed the cover photo$on';
      }
      return 'Edited a photo$on';
    case 'video.created':
      return 'Added a video$on';
    case 'video.deleted':
      return 'Removed a video$on';
    case 'video.updated':
      return changes.containsKey('is_primary')
          ? 'Changed the main video$on'
          : 'Edited a video$on';
    case 'document.created':
      return 'Uploaded document${_suffix(name)}$on';
    case 'document.deleted':
      return 'Deleted document${_suffix(name)}$on';
    case 'document.updated':
      final public = changes['is_public']?['new'];
      if (public == true) return 'Made a document public$on';
      if (public == false) return 'Made a document private$on';
      return 'Edited a document$on';
    case 'nearby_place.created':
    case 'nearby_place.updated':
    case 'nearby_place.deleted':
      return '${_verb(entry.action)} nearby place${_suffix(name)}$on';
    case 'property_amenity.created':
      return 'Added an amenity$on';
    case 'property_amenity.deleted':
      return 'Removed an amenity$on';
    case 'enquiry.received':
      return 'New enquiry ${d['reference'] ?? ''}$on'.trim();
    case 'enquiry.status_changed':
      return 'Moved enquiry ${d['reference']} to ${humanize('${d['to']}')}';
    case 'content.published':
      return 'Published website content: ${_contentName('${d['name'] ?? entry.entityId}')}';
    case 'faq.created':
      return 'Added a question to the FAQs';
    case 'faq.updated':
      return 'Edited an FAQ: ${_fieldList(changes.keys)}';
    case 'faq.deleted':
      return 'Deleted a question from the FAQs';
    case 'testimonial.created' ||
        'testimonial.updated' ||
        'testimonial.deleted':
      return '${_verb(entry.action)} the testimonial from ${name ?? 'a customer'}';
    case 'banner.created' || 'banner.updated' || 'banner.deleted':
      return '${_verb(entry.action)} the banner "${name ?? (changes['title']?['new'] ?? '')}"';
    case 'booking.requested':
      return 'Booking ${d['reference'] ?? ''} ${d['source'] == 'admin' ? 'started' : 'requested'}$on';
    case 'booking.status_changed':
      return 'Booking ${d['reference']}: ${_bookingStep('${d['to']}')}';
    case 'booking.assigned':
      return 'Reassigned booking ${d['reference']}';
    case 'site_visit.requested':
      return 'Site visit ${d['reference'] ?? ''} requested$on for ${_visitTime(d['visit_date'], d['slot'])}';
    case 'site_visit.status_changed':
      return '${_visitVerb('${d['to']}')} site visit ${d['reference']}';
    case 'site_visit.rescheduled':
      return 'Moved site visit ${d['reference']} to ${_visitMoment(d['to'])}';
    case 'site_visit.assigned':
      return 'Reassigned site visit ${d['reference']}';
    case 'enquiry.assigned':
      return 'Reassigned enquiry ${d['reference']}';
    case 'admin.added':
      return 'Added ${d['email']} as ${humanize('${d['role']}')}';
    case 'admin.role_changed':
      return 'Changed ${d['email']} to ${humanize('${d['to']}')}';
    case 'admin.deactivated':
      return 'Deactivated ${d['email']}';
    case 'admin.reactivated':
      return 'Reactivated ${d['email']}';
    case 'settings.updated':
      return 'Updated website settings: ${_fieldList(changes.keys)}';
  }

  final parts = entry.action.split('.');
  if (parts.length == 2 &&
      const {'created', 'updated', 'deleted'}.contains(parts[1])) {
    return '${_verb(entry.action)} ${humanize(parts[0]).toLowerCase()}${_suffix(name)}';
  }
  return humanize(entry.action.replaceAll('.', ' '));
}

String _verb(String action) => switch (action.split('.').last) {
  'created' => 'Added',
  'deleted' => 'Removed',
  _ => 'Edited',
};

String _suffix(Object? value) =>
    (value is String && value.isNotEmpty) ? ' · $value' : '';

String _price(Object? price, Object? type) {
  if (type == 'on_request') return 'price on request';
  if (price is num) return formatRupees(price);
  if (price is String) {
    final parsed = num.tryParse(price);
    if (parsed != null) return formatRupees(parsed);
  }
  return 'no price';
}

String _fieldList(Iterable<String> keys) {
  final names = keys.map((key) => humanize(key).toLowerCase()).toList();
  if (names.isEmpty) return 'details';
  if (names.length <= 3) return names.join(', ');
  return '${names.take(3).join(', ')} and ${names.length - 3} more';
}

String _visitVerb(String status) => switch (status) {
  'confirmed' => 'Confirmed',
  'completed' => 'Completed',
  'no_show' => 'Marked no-show for',
  'cancelled' => 'Cancelled',
  _ => 'Updated',
};

/// ("2026-11-14", "15:00") → "Sat, 14 Nov 2026, 3:00 pm"
String _visitTime(Object? date, Object? slot) =>
    date is String && slot is String
    ? '${formatVisitDay(date)}, ${formatVisitSlot(slot)}'
    : 'a visit';

/// "2026-11-14 15:00" → "Sat, 14 Nov 2026, 3:00 pm"
String _visitMoment(Object? value) => value is String && value.length >= 16
    ? _visitTime(value.substring(0, 10), value.substring(11, 16))
    : 'a new time';

String _bookingStep(String status) => switch (status) {
  'pending_approval' => 'sent for approval',
  'approved' => 'approved (property reserved)',
  'payment_pending' => 'booking amount asked for',
  'reserved' => 'payment recorded',
  'completed' => 'sale completed (property sold)',
  'cancelled' => 'cancelled',
  _ => humanize(status).toLowerCase(),
};

String _contentName(String key) => switch (key) {
  'home.hero' => 'top of the home page',
  'home.trust_points' => 'home page promises',
  'home.why_us' => 'why choose us',
  'home.verification' => 'what we check',
  'home.steps' => 'how buying works',
  'about' => 'About page',
  'legal.terms' => 'Terms of use',
  'legal.privacy' => 'Privacy policy',
  'legal.disclaimer' => 'Disclaimer',
  _ => key,
};
