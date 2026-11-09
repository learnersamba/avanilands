# Phase 10 — Site visits

**Goal:** a customer books a visit to the land from the property page; the team confirms, reschedules, cancels or completes it in the admin panel; the customer is emailed at each step and reminded the day before.
**Depends on:** Phases 7–9.

## Rules (decisions 72–79)
- Visits are always for one **published, not sold** property.
- Bookable days: from **tomorrow** up to **30 days** ahead (setting), only on **visit days** (default Mon–Sat), never on **closed dates** (holidays), at one of the **time slots** (default 10:00, 12:00, 15:00). All in India time.
- Statuses: **Requested** → **Confirmed** → **Completed** / **No-show**; **Cancelled** from Requested or Confirmed. **Reschedule** is an action (new date/slot, status becomes Confirmed), recorded in the timeline with the old and new times.
- Staff may reschedule to any future date and time (special arrangements), not only the website's slots.
- Spam: at most 3 requests an hour per phone, 5 per visitor IP (hashed). One open request per phone per property: asking again returns the existing reference.
- No slot capacity limit: the team confirms each visit by phone.

## Checklist
### Database
- [x] Visit settings in `site_settings` (days, slots, closed dates, days ahead) and the public settings view
- [x] `site_visits` + `site_visit_notes`, RLS (admins read; may only reassign directly), audit log, Realtime
- [x] `submit_site_visit` (website server only), `update_site_visit` (confirm / reschedule / complete / no-show / cancel), `add_site_visit_note`
- [x] Customer emails on confirm / reschedule / cancel: database → website (same secret as the cache refresh)
- [x] Reminder claim function for visits tomorrow; dashboard counts
- [x] pgTAP tests

### Website
- [x] "Book a site visit" next to the enquiry form (tabs), available days and slots only
- [x] Server action: validation → bot check → `submit_site_visit` → confirmation with SV- reference; emails to sales and customer
- [x] `/api/site-visits/notify` (from the database) and `/api/site-visits/reminders` (daily cron) send the customer emails, with an "Add to Google Calendar" link
- [x] Unit tests (available dates, form rules, emails)

### Admin
- [x] Site visits list (filters, search, upcoming / today / past) and month calendar
- [x] Detail: call / WhatsApp / email, property, visit time, actions, notes timeline, assign
- [x] Live alert for new requests; dashboard card; Site visits section in the property editor
- [x] Settings: visit days, time slots, closed dates, days ahead
- [x] Activity log text for visit events

## Done when
A visitor books a slot on a phone → sales and customer emails arrive → admin confirms (customer emailed) → reschedules (emailed) → reminder goes out the day before → admin marks it completed with a note. Past dates, closed days and unknown slots are refused.

## Notes (2026-11-09)
- **Database:** migration `20261109100001_site_visits.sql` (settings columns + public view, `site_visits`, `site_visit_notes`, RLS, Realtime, `submit_site_visit`, `update_site_visit`, `add_site_visit_note`, `claim_site_visit_reminders`, audit trigger, customer-email trigger via pg_net, dashboard counts). Seed has three sample visits dated from today. Tests: `07_site_visits.test.sql` (38); the Phase 9 exposure scan covers the new tables and functions automatically.
- **Website:** `ContactTabs` ("Ask a question" / "Book a site visit"; `#visit` opens booking; phone action bar has **Visit**), `SiteVisitForm` (days worked out in the browser in India time, because the page itself is cached), `submitSiteVisit` action, `site-visit-emails.ts`, `/api/site-visits/notify` (from the database) and `/api/site-visits/reminders` (Vercel Cron in `vercel.json`, `CRON_SECRET`). Settings now always fall back to defaults for fields the database doesn't have yet: a settings copy cached from before the migration crashed the page.
- **Admin:** Site visits page (filters in the address, upcoming first, month calendar), detail page (actions in dialogs, notes, timeline, assignment), live alerts for new requests, calendar badge in the top bar, dashboard card, Site visits section in the property editor, Settings card (days / times / holidays / days ahead), activity log lines, `SV-` in the top-bar search.
- **Checked:** 174 database, 53 website, 73 admin tests; the security check (51) and the Phase 8 enquiry flow still pass. Browser journey: booked on a phone → live alert → confirmed (email) → moved (email) → Sundays opened in Settings appear on the website → reminder job sent once → marked done with a note.
- **Later:** WhatsApp messages to customers (needs WhatsApp Business), per-slot limits if visits get busy, customers cancelling online.
