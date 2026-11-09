# Phase 2 — Admin foundation: login, shell, dashboard ✅

**Goal:** an admin can sign in safely and see the dashboard.
**Depends on:** Phase 1.

## Checklist
- [x] Theme (green/gold placeholder palette, typography) and shared widgets: buttons, inputs, cards, status badges, tables, dialogs, snack bars, empty/error/loading states
- [x] Data layer: models + repositories per feature (`admin/lib/features/...`), Riverpod providers
- [x] Login page (email + password), "forgot password" email
- [x] After login: `is_admin()` check; non-admins signed out with a clear message
- [x] Session expiry handled (back to login, keeps the page the admin was on)
- [x] Route guards on every route; super-admin-only routes
- [x] Shell: sidebar, top bar (bell, profile menu, change password, sign out), responsive (sidebar → icon rail → drawer). *Search box moved to Phase 3, when there is something to search.*
- [x] Dashboard: cards from `dashboard_summary()` (total, available, reserved, sold, draft, new enquiries), recent activity from `audit_logs`, latest 5 enquiries
- [x] Settings page (super admin): company contact details, WhatsApp, sales notification email, default SEO
- [x] Admin users page (super admin): list, invite by email (Edge Function `invite-admin`), change role, deactivate
- [x] Activity log page: filter by entity, admin, date
- [x] `noindex` meta and robots for the admin site

## Done when
- Super admin signs in, sees correct counts from the seed data, invites a second admin
- A non-admin account cannot get past login; direct API calls with it return nothing

## Notes (2026-11-08)
- Structure: `admin/lib/core` (theme, widgets, errors, validators, formatting, router) and `admin/lib/features/<area>` (auth, shell, dashboard, activity, settings, admins). Plain Riverpod providers, no code generation.
- **Sign-in guard**: `AuthController` follows the Supabase session and loads the `admin_users` row. No row, or a deactivated one → signed out with the reason shown on the sign-in page. Route rules live in `core/router/redirect.dart` (unit-tested): unknown → splash, signed out → `/login?from=…`, plain admins can't open `/settings` or `/admins`.
- **Passwords**: invited admins (and anyone following a reset link) must choose a password before anything else; it's tracked on the account (`password_set`), so it can't be skipped by changing the address. Rule: 10+ characters with letters and a number.
- **Invites**: Edge Function `supabase/functions/invite-admin` — super admins only, refuses existing admins, sends the email, then inserts `admin_users` with the caller's token so the activity log shows who invited whom. Local emails: http://127.0.0.1:56424.
- After editing an Edge Function locally, restart its container: `docker restart supabase_edge_runtime_avanilands`.
- Fixed a Phase 0 setting: `[auth.email] enable_signup` must stay **true** (it switches email sign-in on); public sign-ups are blocked by `[auth] enable_signup = false`. Checked: public sign-up returns "Signups not allowed".
- New migration `20261108120001_audit_publish_noise.sql`: the first publish no longer adds an extra "Updated …: slug" log entry.
- Tests: 23 Flutter tests (route rules, activity wording, login form, error messages, validators) pass; 105 database tests still pass.
- Checked in a real browser (headless Chrome): non-admin refused; super admin sees dashboard (11 / 7 / 1 / 1 / 1 / 3 matches the seed), activity, admin users, settings; phone layout uses the drawer; plain admin sent away from `/settings`; full invite → email → set password → dashboard → sign in with the new password.
- Not checked live: the "session ended" message after a token expires (needs 1 hour); covered by code review only.
