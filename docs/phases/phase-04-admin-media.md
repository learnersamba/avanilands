# Phase 4 — Admin: images, videos, documents ✅

**Goal:** admins fully control every property's media and files.
**Depends on:** Phase 3.

## Checklist
### Images
- [x] Pick many images at once (JPEG/PNG/WebP/HEIC where the browser supports it), max 15 MB each before shrinking, max 40 per property
- [x] Shrink in the browser to WebP 400 / 1200 / 2000 px (keep aspect ratio, strip location metadata)
- [x] Upload with progress per file; retry failed ones; partial failures don't lose finished uploads
- [x] Grid with drag-to-reorder, star to set cover, alt text, replace, delete (with confirm; removes files from Storage)
- [x] First uploaded image becomes cover automatically
- [x] Orphan clean-up: files whose row failed to save are deleted

### Videos
- [x] Add YouTube link (accepts watch, share and shorts URLs; stores the video id; shows thumbnail preview)
- [x] Optional MP4 upload ≤ 50 MB with progress
- [x] Set primary, reorder, remove

### Documents
- [x] Upload PDF/JPEG/PNG ≤ 20 MB to the private bucket; choose type and title
- [x] Public/private switch (private by default) with a warning before making public
- [x] Admin can open any document via a signed link; delete, replace, reorder

### Location cover images
- [x] Same image pipeline for location covers (`site-assets`)

## Done when
A property gets 10 images (reordered, cover changed), one YouTube video and two documents (one public, one private). The public one is listed by `public_property_documents`; the private one can't be fetched without admin login. Wrong file types and oversize files are refused by the app **and** by Storage.

## Notes (2026-11-08)
- Code: `admin/lib/features/media/` (rules, repository, photos / videos / documents managers, upload queue), `admin/lib/core/browser_files.dart` (file picker, photo shrinking), `admin/lib/core/storage_upload.dart` (uploads with progress). The editor's "Media" section holds the three managers; location covers are in the Locations menu.
- **Media saves straight away** (not with "Save changes"). The managers keep their upload queue even when the form reloads.
- **Photos**: shrunk in the browser to WebP at 400 / 1200 / 2000 px (longest side, never enlarged); browsers that can't make WebP get JPEG. Re-drawing removes camera location data. Files: `property-media/<property>/<photo-id>-<size>.webp`. If any step fails, files already uploaded for that photo are removed. Tested: a 4000×3000 JPEG became a 2000×1500 WebP with a 6.5 KB thumbnail.
- **Uploads go straight to the Storage API** with the admin's token, because the Supabase SDK can't report progress. Storage still applies the bucket limits and admin-only rules.
- **Videos**: YouTube links (watch, youtu.be, shorts, embed, live, or a bare id) with thumbnail preview; MP4 up to 50 MB. First video becomes the main one.
- **Documents**: private bucket, private by default; making one public asks first and warns about deeds/IDs. Admins open them through 2-minute signed links.
- **Location covers**: one 1600 px WebP in `site-assets/locations/<id>/…`; the old file is removed when replaced.
- Storage checked directly (bypassing the app): text file into photos → refused; 21 MB PDF → refused; visitor upload → refused; private document without a signed link → refused; signed link → works.
- Tests: 55 Flutter tests (17 new: file checks for each kind, photo sizes, YouTube links, titles, sizes). No database changes this phase.
- Checked in headless Chrome: 10 photos uploaded to AL-0002 (3 → 13) with progress, a .txt refused with a clear message, photo dragged to a new place, cover changed (exactly one cover), YouTube video added as main video, one public and one private PDF uploaded; visitors' view lists only the public one; location cover saved.
- The local database now holds this test media on AL-0002 and Visakhapatnam (handy for building the website). `supabase db reset` brings back the plain sample data — run it before `supabase test db`, whose counts assume the plain sample.
- Not clicked through: MP4 upload, replace photo/document, delete photo/video/document, alt text dialog (same code paths as the tested ones: upload with progress, row update, file removal).
