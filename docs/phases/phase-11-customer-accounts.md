# Phase 11 — Customer accounts

**Goal:** customers can (optionally) sign in to save properties and see all their enquiries and site visits in one place. Nothing that works for guests today changes.
**Depends on:** Phases 8, 10.

## Rules (decisions 80–88)
- Sign in with **email + a 6-digit code** sent by email. No passwords to forget. New emails get an account automatically. Phone sign-in later (needs an SMS provider and DLT registration).
- Accounts are **optional**: guests still enquire and book visits exactly as before.
- Signing in **links earlier guest enquiries and visits** sent with the same email (the code proves the email is theirs). Enquiries and visits sent while signed in are linked automatically.
- Customers see only **their own** profile, saved properties and requests, and only customer-friendly fields (never staff notes, assignments or internal ids). The database enforces it.
- **Recently viewed** properties are kept in the browser only (nothing stored about browsing).
- Customers can **delete their account**: profile and saved properties are removed; enquiries and visits stay with the business but are no longer linked to an account.
- Staff accounts are untouched: being signed in as a customer never gives admin access (admin access still comes only from `admin_users`).

## Checklist
### Database
- [x] Sign-ups on for customers (email confirmation required for any password sign-up); branded code emails
- [x] `customer_profiles` (name, mobile) and `saved_properties`, owner-only RLS; saving only published properties
- [x] `site_visits.customer_id`; enquiries and visits record the signed-in customer
- [x] `my_requests()` (customer-friendly view of own enquiries and visits), `link_my_guest_requests()`
- [x] Exposure scan updated for customer tables (customers may touch only their own rows); pgTAP tests incl. one customer trying another's rows

### Website
- [x] Sign-in page: email → code → signed in (cookies), with "Back to the property" return
- [x] Header: "Sign in" / "My account" (works on cached pages)
- [x] Account page: profile (name, mobile), saved properties, enquiries and visits with status, recently viewed, sign out, delete account
- [x] Save (heart) on property cards and the property page; prompts sign-in for guests
- [x] Forms pre-filled for signed-in customers; their requests linked to the account
- [x] `/account` never indexed; unit tests

### Admin
- [x] Enquiry and visit pages show when the customer has an account

## Done when
A guest enquires, later signs in with the same email → the earlier enquiry appears in "My account"; they save two properties, book a visit while signed in (pre-filled, linked); another customer can't see any of it; deleting the account removes the profile and saved properties but keeps the requests for the team.

## Notes (2026-11-09)
- **Database:** `20261109110001_customer_accounts.sql` — `customer_profiles`, `saved_properties` (owner-only RLS; only public properties can be saved; admins may read), `site_visits.customer_id` (+ `submit_site_visit` gained `p_customer_id`), `my_requests()`, `link_my_guest_requests()`. Auth config: sign-ups on, email confirmation on, code template `supabase/templates/sign_in_code.html`. The exposure scan now allows exactly two shapes: admin-only, or "customer's own rows" (and checks a customer can't reach another's rows); `08_customer_accounts.test.sql` (27) covers two customers, linking, deletion.
- **Website:** `@supabase/ssr` browser client (session in cookies) and `currentCustomer()` for server actions; `AccountProvider` (session, profile, saved ids) in the layout; header `AccountLink`; `SaveButton` on cards and the property page (guests → sign in → saved); `/account/sign-in` (email → code, "send a new code" after 60 s, safe return address); `/account` (visits, enquiries, profile, saved land, recently viewed, sign out, delete); `RecordView`; forms pre-filled via `usePrefill`; enquiry and visit actions record the customer; `deleteMyAccount` refuses staff accounts. `/account` is noindex and disallowed in robots.
- **Admin:** "Has an account" pill on enquiry and visit pages.
- **Bugs found by the journey test and fixed:** saving the profile failed (an "insert or update" also tried to write the account id, which customers may not change); the saved heart could show empty right after sign-in (the reload ran before the session was known); sign-out and delete jumped to the sign-in page instead of home.
- **Checked:** 201 database, 56 website, 73 admin tests; security check (51); enquiry, visit and listing flows. Journey: guest enquiry → heart → sign in by code → back with it saved and the enquiry linked → second save → profile → visit pre-filled and linked → second customer sees nothing → delete account (requests kept, unlinked).
- **Expected noise:** after deleting an account the browser's log-out call gets a 403 (the user is already gone); the session is cleared anyway.
- **Later:** phone sign-in (SMS), notifications page (Phase 15), comparison (Phase 12).
