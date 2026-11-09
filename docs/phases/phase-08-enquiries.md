# Phase 8 — Enquiries (website form + admin management)

**Goal:** complete the MVP journey: customer enquires → admin receives → admin follows up.
**Depends on:** Phases 2, 7.

## Checklist
### Website
- [x] Enquiry form on details page (property pre-selected) and contact page (general): name, phone, email (optional), preferred contact method, message
- [x] Server Action: zod validation → Turnstile → `submit_enquiry` → email to sales → confirmation with reference number
- [x] Friendly errors: invalid phone, too many enquiries (rate limit), property just sold, network failure (keeps typed data, retry)
- [x] Double-submit protection (button disabled + idempotency key)
- [x] Customer confirmation email when an email address is given
- [x] WhatsApp (and call) taps logged in `contact_taps` (no personal data)

### Admin
- [x] Enquiries list: reference, name, phone, property, status, date; filters by status, property, date; search by phone/name/reference
- [x] Live new-enquiry badge (Realtime) + browser notification while the admin tab is open
- [x] Detail: contact actions (call, WhatsApp, email links), property card, message, status change with note, notes timeline, assign to admin
- [x] Enquiries tab inside each property
- [x] CSV export (filtered list)

### Email
- [ ] ⏭ (Phase 9, needs the real domain) Resend domain verified (staging uses test mode); templates for "new enquiry" (to sales) and "we received your enquiry" (to customer)

## Done when
The full MVP journey works on staging from a real phone: publish → find → enquire → email arrives → admin marks Contacted with a note. Spam test: 6th enquiry within an hour from the same phone is refused; a missing Turnstile token is refused.

## Notes (2026-11-08)
- **Website:** `EnquiryForm` (property page aside `#enquire`, contact page). `submitEnquiry` server action: zod → Turnstile → `submit_enquiry` (limits, sold check, idempotency) → confirmation with ENQ- reference; emails go out afterwards via `after()` (Mailpit locally, Resend in production). All field errors show at once, typed values are kept. The double-submit key is made on the first send, not while rendering (Cache Components rejects random values during prerender).
- **Taps:** `TrackedLink` counts WhatsApp/call taps through `log_contact_tap`; the dashboard shows the last 7 days.
- **Admin:** `/enquiries` (filters in the address: `q`, `status`, `range`, `assigned`, `property`; search understands ENQ-, AL-, phone numbers, names, emails), `/enquiries/:id` (call/WhatsApp/email, Mark contacted, status + note, timeline, assign), Enquiries section in the property editor, CSV export of the filtered list. `EnquiryAlerts` in the shell listens with Supabase Realtime, refreshes badge/lists and announces new enquiries.
- **Checked:** 121 DB, 42 website unit, 63 admin tests. Browser journey: admin publishes AL-0010 → phone visitor finds it, enquires → sales + customer emails arrive → admin marks Contacted with a note. Spam: 6th enquiry from one phone refused; 6th from one IP refused with a friendly message; no bot-check token → nothing sent (plus unit tests for forged/missing tokens).
- **Not yet:** Resend domain verification and testing on staging from a real phone need the real domain (Phase 9).
- **Seen, not changed:** in dev only, Next.js logs an "instant validation" invariant on `/land/[slug]` (production build and the production property flow are clean). In production, link prefetches stay open in the background, so tests should wait for `load`, not `networkidle`.

- **Correction (Phase 9):** network failure during sending was *not* handled as noted above: the page showed the error screen and lost the typed details. Fixed in Phase 9 (decision 71) and tested with the connection cut and restored.
