# Phase 13 — Bookings

**Goal:** the owner's flow — *site visit → customer decides → booking request → admin approval → property Reserved → payment → documentation → Sold* — tracked in the system, with the property's status always matching the booking. **No online payments** (owner's plan: the company's established process first; gateway is Phase 17).

## Rules (decisions 94–102)
- **Statuses** (owner's list): Requested → Pending approval → Approved → Payment pending → Reserved → Completed; **Cancelled** from any step before Completed.
  - *Send for approval* (any admin): Requested → Pending approval.
  - *Approve* (**super admin only**): Requested or Pending approval → Approved. **The property becomes Reserved** in the same database transaction.
  - *Ask for booking amount* (any admin, amount required): Approved → Payment pending.
  - *Record payment* (any admin: amount, date, method, reference — no card or bank details): Payment pending → Reserved.
  - *Complete* (super admin, after registration): Reserved → Completed. **The property becomes Sold** in the same transaction.
  - *Cancel* (any admin, reason): the property goes back to Available if this booking was holding it.
- **One booking holds a property at a time** (Approved / Payment pending / Reserved), enforced by a unique index, so two approvals at the same moment can't both win. Other requests can wait in the queue.
- Customers can only request booking for **published, Available** land (not Reserved or Sold), must be **signed in** with name and mobile in their profile, one open request per property, at most 3 requests a day.
- Staff can also start a booking for a customer (from a site visit or enquiry).
- While a booking holds a property, its availability can't be changed by hand and it can't be archived — only the booking's own steps change it.
- Customers are emailed at each step; their **payment instructions are never shown on the website or emailed** — the team gives them by phone from official channels (fraud protection), and every email says so.
- Customers see their bookings in My account in plain words; never staff notes.

## Checklist
### Database
- [x] `bookings`, `booking_notes`, holding-unique index, RLS, audit, Realtime
- [x] `request_booking` (customer), `create_booking` / `update_booking` / `add_booking_note` (admin; approve and complete super admin only); property Reserved / Available / Sold in the same transaction, locked against races
- [x] Guard: no manual availability change or archiving while a booking holds the property
- [x] Customer emails / sales alert via the website (same secret); `my_requests()` includes bookings; dashboard counts
- [x] pgTAP: every step, roles, refusals, the two-approvals race, the guard, customers' own rows only

### Website
- [x] "Ready to buy? Request booking" on Available property pages → `/book/AL-xxxx` (sign-in first, profile pre-filled)
- [x] Emails: sales on request; customer on each step (no payment details)
- [x] My account: bookings with status and what happens next

### Admin
- [x] Bookings page (filters, search), detail with the right buttons for the step and role, amounts, notes timeline, assign
- [x] "Start booking" from a site visit and an enquiry; live alert for new requests; dashboard card; property editor section; availability buttons explain when a booking holds the property
- [x] Activity log lines

## Done when
A signed-in customer requests a booking → sales email → admin sends for approval → super admin approves (property Reserved on the website within seconds; a second booking for it is refused) → ask for ₹1,00,000 → record payment → complete (property Sold). Another booking cancelled after approval puts the property back to Available. Two simultaneous approvals: exactly one wins.

## Notes (2026-11-09)
- **Database:** `20261109120001_bookings.sql` — `bookings`, `booking_notes`, unique index `bookings_one_holding_per_property`, `property_booking_guard` trigger (no manual availability change / archive while held; booking steps pass a transaction-local flag), `request_booking` / `cancel_my_booking` (customers), `create_booking` / `update_booking` / `add_booking_note` (admins; approve and complete check super admin), audit, Realtime, notify trigger → `/api/bookings/notify`, `my_requests()` and `link_my_guest_requests()` include bookings, dashboard counts. Seed: AL-0007 is held by a booking (payment pending); AL-0006 has a request awaiting approval. Tests: `09_bookings.test.sql` (39); the exposure scan allows the two new customer functions.
- **Race:** checked with two real database sessions approving two bookings for AL-0005 at the same moment: the second waits for the property lock, then is refused ("The property is no longer available…"); exactly one booking holds it.
- **Website:** "Decided? Request to book" on Available property pages → `/book/AL-xxxx` (sign in; name and mobile filled into the profile; message; what happens next; payment-safety note); My account shows bookings with plain status, next step, amounts and "Withdraw request"; `booking-emails.ts` (sales + customer per step, safety warning in every email; unit tests).
- **Admin:** Bookings list (in progress / all, step filter, search incl. BKG- and AL-), detail (progress, step buttons with role checks and dialogs, price and payment record, customer, property, notes, timeline, assignment), Start booking on site visits (confirmed / completed) and enquiries (available property), live alert for website requests, dashboard card, Bookings section in the property editor, activity lines, BKG- in the top-bar search.
- **Checked:** 240 database, 64 website, 79 admin tests; security check; enquiry, listing, comparison and account flows. Journey: phone customer signs in from the booking page → request → sales email → admin sends for approval (approve disabled for admins) → super admin approves → website shows Reserved and refuses booking → ₹1,00,000 asked → payment recorded (UPI, UTR) → My account shows it → complete → Sold; 5 customer emails, all with the safety warning.
- **Later (Phase 17):** online booking-amount payment with a gateway, receipts, refunds.
