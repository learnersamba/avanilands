# Phase 15 — Notifications

**Goal:** nobody misses an update. Customers see everything about their enquiries, visits, bookings and saved land in one place (and by email where it matters); the team gets a notification list in the admin panel instead of alerts that vanish. From the plan: *email + in-app first; WhatsApp Business API and push later.*

## What is new (emails for enquiries, visits and bookings already exist since Phases 8, 10 and 13)
| Who | Event | In-app | Email |
|-----|-------|--------|-------|
| Customer (signed in) | Enquiry received / the team got in touch | ✓ | received (already) |
| Customer | Site visit requested / confirmed / moved / cancelled / done | ✓ | already |
| Customer | Booking steps | ✓ | already |
| Customer | **Saved land changed**: price changed, reserved, sold, available again, removed from the website | ✓ | **new** (can be switched off) |
| Every admin | New enquiry, new site visit request, new booking request (website), **payment recorded**, **new customer account** | ✓ (bell + list, live) | sales inbox (already for the first three) |

## Rules (decisions 111–117)
- One `notifications` row per person; each person sees only their own; they can only mark them read. Rows are written by the database itself (triggers), so no screen can forget one.
- Admin notifications go to every active admin **except the one who did the action**.
- Saved-land emails: on by default for saved land, one switch in My account turns them off; they never contain anything the property page doesn't show.
- Old notifications are deleted after **90 days** (daily job).
- WhatsApp Business messages and phone push notifications come later (need a WhatsApp Business account / a mobile app).

## Checklist
### Database
- [x] `notifications` (own rows only, mark read only), Realtime; `customer_profiles.email_updates`
- [x] Triggers: enquiries, site visits, bookings (incl. payment recorded), saved-land changes, new verified customer
- [x] Saved-land emails queued and sent by the website (claimed once); 90-day clean-up
- [x] pgTAP tests

### Website
- [x] Header shows unread updates (live); My account → **Updates** list with links, "Mark all as read"
- [x] "Email me when saved land changes" switch
- [x] Saved-land email (unit tested)

### Admin
- [x] Bell = unread notifications (live), notifications page with links, mark read / mark all read

## Done when
A customer saves a plot → the price is changed and the plot is reserved in the admin → the customer sees two updates live and gets the emails (none after switching emails off); a website enquiry / visit / booking each appear in every other admin's bell; recording a payment notifies the other admins; a new customer signing up notifies the admins; nobody can read anyone else's notifications.

## Notes (2026-11-09)
- **Database:** `20261109140001_notifications.sql` — `notifications` (own rows only; only `read_at` can be changed; Realtime), `customer_profiles.email_updates`, helpers (`private.inr` for ₹ Indian grouping, `notify_user`, `notify_admins` skipping the actor), triggers on enquiries, site visits, bookings (incl. payment recorded), properties (saved-land changes) and `auth.users` (newly verified non-staff account), email queue → `/api/notifications/send` (`claim_notification_emails`, `finish_notification_emails`), `cleanup_notifications` (90 days). Tests: `11_notifications.test.sql` (23); the exposure scan covers the new table.
- **Website:** `AccountProvider` keeps the unread count live (Realtime, counted once connected); header badge; My account **Updates** (latest 30, "New" marks, marked read on view); "Email me when saved land changes" (switches immediately); `notification-emails.ts` (unit tested); the daily job also cleans up.
- **Admin:** bell = unread notifications (live), `/notifications` page (All / Unread, open → marks read, Mark all as read).
- **Checked:** 292 database, 71 website, 88 admin tests; security check; enquiry, listing, comparison and account flows; production build. Journey: customer signs up and saves AL-0002 (admin bell +1 live: new customer) → price lowered and reserved → customer badge shows 2 live, both emails arrive, Updates shows both as New then clears the badge → emails switched off → next change in-app only → guest enquiry: admin bell +1 live → opening it goes to the enquiry and marks it read.
- **Later:** WhatsApp Business API, push notifications (with a mobile app).
