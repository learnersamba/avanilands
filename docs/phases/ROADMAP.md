# Roadmap after the MVP

Each item gets its own detailed phase file (like Phases 0–9) when we reach it. Order follows the owner's plan; real customer behaviour after launch may change it.

## Phase 10 — Site visits ✅ (done 2026-11-09, see [phase-10-site-visits.md](phase-10-site-visits.md))
- Customer form on details page: date (no past dates, closed days blocked), time slot, visitors count, contact details, message
- Statuses: Requested → Confirmed / Rescheduled → Completed / Cancelled; admin notes
- Admin calendar + list; confirm / reschedule / cancel / complete; email (and later WhatsApp) to the customer on each action; reminder the day before
- Dashboard: pending site visits card

## Phase 11 — Customer accounts ✅ (done 2026-11-09, see [phase-11-customer-accounts.md](phase-11-customer-accounts.md); notifications page moved to Phase 15)
- Sign-up / login (email + password or email OTP; phone OTP later — needs SMS/DLT costs)
- Profile, saved properties (wishlist), enquiry history, site visits, recently viewed, notifications page
- Link earlier guest enquiries by verified phone/email
- RLS: customers only ever see their own rows

## Phase 12 — Property comparison ✅ (done 2026-11-09, see [phase-12-comparison.md](phase-12-comparison.md))
- Compare up to 3 properties side by side (type, area, price, per-unit, road width, facing, water, electricity, approval, location, distance between them)
- Works without login (stored on the device); shareable link

## Phase 13 — Bookings ✅ (done 2026-11-09, see [phase-13-bookings.md](phase-13-bookings.md))
- Booking request after a site visit; statuses Requested → Pending approval → Approved → Payment pending → Reserved → Completed / Cancelled
- Approve → property Reserved; complete → property Sold (one database transaction); only one active booking per property
- Refuse bookings on reserved/sold properties; handle the race when two customers book at once

## Phase 14 — CMS ✅ (done 2026-11-09, see [phase-14-cms.md](phase-14-cms.md))
- Homepage hero (image/video, title, text), featured order, promo sections
- About page (description, mission, vision, values, images), FAQ (add/edit/delete/reorder), testimonials, banners (add/replace/reorder/schedule), legal pages
- Live preview before publishing

## Phase 15 — Notifications ✅ (done 2026-11-09, see [phase-15-notifications.md](phase-15-notifications.md); WhatsApp / push still later)
- Customer: enquiry received/answered, site visit confirmed/rescheduled/reminder, booking updates, saved property status changed
- Admin: new enquiry, new site visit, new customer, booking request, payment
- Email + in-app first; WhatsApp Business API and push later

## Phase 16 — Analytics ✅ (done 2026-11-09, see [phase-16-analytics.md](phase-16-analytics.md))
- Property views, unique visitors, enquiries, site visits, saves, bookings, sales per property
- Funnel and conversion rates, top searched locations, top properties, date ranges, CSV export

## Phase 17 — Online payments ⏸ (postponed by the owner 2026-11-09; payments stay offline and are recorded in Bookings)
- Booking amount through a payment gateway (e.g. Razorpay); payment status, transaction id, receipts, history, refunds
- Only after legal/accounting sign-off; webhooks verified on the server

## Phase 18 — More admin roles ✖ (not planned: the owner decided 2026-11-09 to keep the two roles, Super Admin and Admin)
- Property Manager, Sales Manager, Content Manager with per-role permissions in RLS
