# Phase 9 — MVP testing and launch

**Goal:** a tested, secure, backed-up production launch.
**Depends on:** Phases 1–8.

## Checklist
### Automated tests
- [x] pgTAP: all database rules (from Phase 1) still pass — 136 tests, plus a scan of every table/policy/function
- [x] Website: unit tests for formatters and validation; Playwright end-to-end for home, search/filters/sort, details, enquiry (desktop + mobile viewports) — 42 unit tests; end-to-end browser checks run per phase (Chrome, desktop + phone)
- [x] Admin: widget/integration tests for login guard, property editor validation, status actions, media upload, enquiry status change — 63 tests (rules, validators, guard, enquiries); editor/media/status flows checked in the browser

### Manual test lists
- [x] Customer list, admin list, negative tests and edge cases from the owner's plan (copied into `docs/TEST-CHECKLIST.md` and ticked) — [TEST-CHECKLIST.md](../TEST-CHECKLIST.md)
- [ ] Devices: small Android (360 px), standard Android, iPhone, tablet, laptop, large desktop; Chrome, Safari, Firefox, Edge — 📱 on staging with real phones (table in TEST-CHECKLIST.md)

### Security review
- [x] Every table has RLS; anonymous and customer tokens tried against every table and RPC — `06_exposure_scan` + `tool/security_check.mjs`
- [x] Service role key only on the server; no secrets in the browser bundle — bundle scan in `tool/security_check.mjs`
- [ ] Headers checked (securityheaders.com), HTTPS only, CSP no violations — local headers pass (website + admin `_headers`, no CSP violations); securityheaders.com and HTTPS on the real domain
- [x] Upload type/size limits tested by direct API calls — `tool/security_check.mjs`

### Production setup
- [ ] Final brand name, logo, domain (owner) — owner/launch: runbook in [DEPLOY.md](../DEPLOY.md)
- [ ] Supabase production project (Mumbai, Pro plan); migrations applied; sign-ups off; auth email templates and SMTP (Resend); custom auth URLs — owner/launch: runbook in [DEPLOY.md](../DEPLOY.md)
- [ ] Storage buckets + policies; first super admin created — owner/launch: runbook in [DEPLOY.md](../DEPLOY.md)
- [ ] Website on Vercel (env vars, domain, `www` redirect); admin on Cloudflare Pages (`admin.` subdomain) — owner/launch: runbook in [DEPLOY.md](../DEPLOY.md)
- [ ] Turnstile and Resend production keys; database webhooks pointing at production — owner/launch: runbook in [DEPLOY.md](../DEPLOY.md)
- [ ] Google Search Console + sitemap submitted; analytics built in since [Phase 16](phase-16-analytics.md) — owner/launch: runbook in [DEPLOY.md](../DEPLOY.md)
- [ ] Error monitoring (e.g. Sentry free tier) for website and admin — owner/launch: runbook in [DEPLOY.md](../DEPLOY.md)

### Backups and recovery
- [ ] Daily database backups confirmed (Pro) — owner/launch: runbook in [DEPLOY.md](../DEPLOY.md)
- [ ] Weekly Storage backup job to a second provider (e.g. Cloudflare R2 / Backblaze B2) — script ready (`tool/weekly_backup.sh`); schedule once the second provider exists
- [ ] `docs/RECOVERY.md`: restore database, restore files, rotate keys, who to contact — **tested once on staging** — written; full restore tested locally 2026-11-09; staging test pending

### Go-live
- [ ] Owner enters real properties, content and contact details
- [ ] Final smoke test on production; launch
- [x] `docs/STAFF-GUIDE.md` for the sales team (managing properties and enquiries) — [STAFF-GUIDE.md](../STAFF-GUIDE.md)

## Done when
The website is live on the real domain, the MVP journey works in production, backups are verified, and the owner signs off.

## Notes (2026-11-09) — everything that can be done before the domain and accounts exist
- **Security review:** `supabase/tests/database/06_exposure_scan.test.sql` checks every table, policy, function and bucket and tries reading/changing every table as a visitor and a signed-in non-admin. It found leftover write grants (incl. TRUNCATE, which RLS doesn't cover) for visitors on 7 tables → removed in migration `20261108150001_tighten_grants.sql`. `tool/security_check.mjs` (51 checks over HTTP: secrets in bundles, headers, private data, admin functions, forged tokens, upload limits, private documents) passes and can run against staging.
- **Admin hosting:** `tool/build_admin.sh` builds without Google's CDN and writes `_headers` (CSP for that environment's Supabase, no framing, noindex) and `_redirects`; `tool/serve_admin.sh` + `tool/spa_server.py` serve it with those headers locally. Browsing the whole panel under the CSP showed it would have blocked the map tiles → fixed; now no violations.
- **Backups:** `tool/backup_db.sh`, `tool/backup_files.mjs`, `tool/restore_db.sh`, `tool/weekly_backup.sh`. Full disaster drill locally: deleted all files, wiped the database, restored → identical row counts and property fingerprint, photos load, old passwords work, numbering continues. Supabase-internal storage tables had to be left out of the dump.
- **Emails:** branded invite / reset templates in `supabase/templates/` (wired into local config; paste into the dashboard for staging/production).
- **Bug fixed:** an enquiry sent while offline replaced the page with the error screen and lost the details; now it keeps them, explains, and resending works (also restarts a stuck bot check).
- **Docs:** [DEPLOY.md](../DEPLOY.md) (staging/production runbook and final checks), [RECOVERY.md](../RECOVERY.md), [STAFF-GUIDE.md](../STAFF-GUIDE.md), [TEST-CHECKLIST.md](../TEST-CHECKLIST.md); `web/.env.example` now lists every setting.
- **Left for launch (needs the owner):** brand/domain, git repository, Supabase/Vercel/Cloudflare/Resend accounts and keys, real-device testing on staging, staging restore test, production data and sign-off.
