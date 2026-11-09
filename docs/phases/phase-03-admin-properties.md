# Phase 3 — Admin: properties and lookups ✅

**Goal:** admins fully manage property information and status.
**Depends on:** Phase 2.

## Checklist
### Lookups
- [x] Locations: list, add, edit, hide/show, mark popular, reorder, delete when unused. *Cover image moves to Phase 4 with the photo uploader.*
- [x] Property types: rename, reorder, activate/deactivate
- [x] Amenities: add, edit, reorder, deactivate

### Property list
- [x] Table: cover thumb, code, title, type, location, area, price, publish state, availability, featured, updated
- [x] Search by code/title/locality; filters by state, availability, type, location; sort; pagination
- [x] Row actions: edit, preview on website, publish/unpublish, hide, archive, mark reserved/sold, delete (drafts without enquiries only)

### Property editor
- [x] Sections: Basic · Location · Size & price · Details · Highlights & nearby · Media (Phase 4) · Documents (Phase 4) · SEO · Status
- [x] Location: pick location (city), locality, address, pincode, map picker with `flutter_map` (tap/drag pin, or type coordinates), "show exact location" switch
- [x] Size: value + unit, live sq ft conversion, length/width, dimensions text
- [x] Price: total or on request, per-unit price + unit, negotiable; Indian number formatting while typing
- [x] Details: facing, road width, corner, water + source, electricity, approval type/number, RERA number, public legal notes, internal notes (clearly marked "admin only")
- [x] Highlights (max 8, reorder), nearby places (name, category, distance), amenities checklist
- [x] SEO: optional title/description with character counters and a Google-style preview
- [x] Validation matches database rules; server errors shown in plain words
- [x] Unsaved-changes warning; save as draft any time
- [x] Publish button with checklist of what's missing (same rules as the database trigger)
- [x] Featured toggle and featured order
- [x] Price change and status change confirmations (they're logged)
- [x] Property history tab (audit log for this property)

## Done when
An admin creates a property from scratch, saves a draft, edits it, and changes its state through draft → published → reserved → sold, and archive; every step appears in the activity log. Publishing without a cover image is refused (until Phase 4 adds images, test with seed images).

## Notes (2026-11-08)
- Pages: **Properties** (`/properties`, filters kept in the address), **property editor** (`/properties/new`, `/properties/<id>`), **Locations & lists** (`/locations`: locations, property types, amenities). Top-bar search: a code like `AL-0007` opens that property; other words search the list (enquiry references go to Enquiries, Phase 8).
- Editor is one page with jump buttons, a status panel (publish / hide / archive, available / reserved / sold, view on website, delete draft), a live "Ready to publish?" checklist and the property's history. Publish stays switched off until the checklist is complete; the database checks again anyway.
- Status changes act on the saved property: with unsaved edits the editor offers "Save and continue" first. Leaving the page (or closing the tab) with unsaved edits asks first.
- Prices are typed with Indian grouping (45,00,000) and show the short form (₹45 L). Area shows the sq ft equivalent as you type.
- Map: OpenStreetMap tiles straight from openstreetmap.org (fine for a handful of admins). The public website must use a proper tile provider (Phase 7).
- Saving only writes what changed: one property update, then the amenities and nearby places that were added, edited, moved or removed — so the activity log stays readable.
- Fixed while testing: the Supabase Dart `.order()` sorts **descending** unless `ascending: true` is given — lists (locations, amenities, types, admins, code sort) were reversed. Also: search now matches the city/district, the table fits a laptop screen, new locations/amenities go to the end of the list.
- Tests: 38 Flutter tests (15 new: area units, rupee formatting, form → database values, publish checklist, status menu, list filters in the address) pass; 105 database tests pass.
- Checked in headless Chrome with real data: list, filters, city search, quick search, editor save (price change logged as ₹45 L → ₹47.5 L), highlight add, mark reserved, new draft saved, publish refused without a cover, leave-without-saving warning, full lifecycle on AL-0010 (publish → reserved → sold → archive, each logged), nearby place + amenity saved, location added, phone layouts.
- Not tested by click: drag-to-reorder (the save path is the same `sort_order` update used elsewhere), delete draft from the UI (database function tested in Phase 1).
