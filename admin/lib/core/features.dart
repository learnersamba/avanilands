/// Features switched off for launch to keep the first months simple and
/// inside the free plans (decision 132). Code and database stay; turning one
/// back on is `true` here plus a deploy (the website has the same switches in
/// web/src/lib/features.ts).
abstract final class Features {
  /// Bookings (request → approval → reserved → sold). Off: no Bookings page,
  /// menu item, "Start booking" buttons, dashboard card or alerts. Bookings
  /// are agreed offline and noted on the enquiry or site visit.
  static const bookings = false;

  /// MP4 uploads for property videos. Off: YouTube links only, so the free
  /// plan's 1 GB file storage is kept for photos and documents.
  static const videoUploads = false;
}
