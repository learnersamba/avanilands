# Going live — step by step

Everything here is done **once per environment**: first for **staging** (a test copy on the internet), then again for **production**. Do staging first and run the checks at the end before touching production.

Who does what: steps marked **(owner)** need the owner's accounts, payment or decisions. Everything else a developer can do with access.

What you need before starting:
- The final **brand name and domain** (decision 5). Until then, staging can run on the free Firebase addresses.
- Production (decisions 131–132): domain **avanilands.in** (DNS at GoDaddy), website on **Firebase App Hosting** and admin panel on **Firebase Hosting** (both in Firebase project `avanilands`), Supabase project `vyfooevrfflmbihmahap` (Mumbai) on the **Free plan** at launch.
- Launch is lean (decision 132): customer accounts, online bookings and MP4 video uploads are switched off (`web/src/lib/features.ts`, `admin/lib/core/features.dart`); steps for them below are marked *(when switched on)*.
- Accounts: Supabase, Firebase (Blaze plan for App Hosting), GoDaddy (DNS), Cloudflare (Turnstile only), Resend. Use a shared company email, not a personal one, and turn on two-factor sign-in everywhere.
- On the developer's laptop: this folder, Node 22, Flutter, Supabase CLI, Docker.
- **Secrets**: keep them in the company password manager. A gitignored `.env.production-setup` in the project folder can hold them while setting up (App Hosting secrets + the vault SQL of step 1.8); delete it afterwards.

---

## 1. Supabase project

1. **(owner)** Create the project: region **Mumbai (ap-south-1)**. Save the database password in the company password manager.
   - **Plan** (decision 132): start on **Free** (500 MB database, 1 GB files, 5 GB egress). Free has no backups, so run `tool/weekly_backup.sh` every week ([RECOVERY.md](RECOVERY.md)). It pauses after a week without use; the daily job (step 1.8) keeps it in use. Move to **Pro ($25/month, daily backups)** when files approach 1 GB (Usage page), when real sales start, or if the project is ever paused.
2. Link and apply the database:
   ```bash
   supabase link --project-ref <project-ref>
   supabase db push
   ```
   This creates every table, rule, function, storage bucket and policy. **Never run `supabase/seed.sql` on staging or production** (test logins and made-up properties).
3. **Authentication → Sign In / Providers**: turn "Allow new users to sign up" **off** while customer accounts are switched off (staff are invited; nobody else needs an account). *(When switched on:* turn it **on** — staff access still needs `admin_users`.) Keep the Email provider on with **Confirm email on**. **Rate limits**: emails per hour ~100 (needs the custom SMTP below).
4. **Authentication → URL Configuration**:
   - Site URL: `https://admin.<domain>`
   - Redirect URLs: `https://admin.<domain>/**`
5. **Authentication → Emails → SMTP**: use Resend (step 4) so invites and password resets don't hit Supabase's tiny built-in limit:
   host `smtp.resend.com`, port `465`, user `resend`, password = a Resend API key, sender `Avanilands <no-reply@<domain>>`.
6. **Authentication → Emails → Templates**: paste `supabase/templates/invite.html` into **Invite user**, `supabase/templates/recovery.html` into **Reset password**, and `supabase/templates/sign_in_code.html` into both **Confirm signup** and **Magic link** (customers' 6-digit codes), with the subjects from `supabase/config.toml`.
7. **Edge Function** (admin invitations):
   ```bash
   supabase functions deploy invite-admin
   ```
8. **Website cache refresh** (admin changes appear on the website within seconds). In the SQL editor, with the real website address and a long random secret (the same secret is the website's `REVALIDATE_SECRET`, step 5.2):
   ```sql
   select vault.create_secret('https://<domain>/api/revalidate', 'website_revalidate_url');
   select vault.create_secret('<long random secret>', 'website_revalidate_secret');
   select vault.create_secret('<CRON_SECRET>', 'website_cron_secret');
   ```
   Generate secrets with `openssl rand -hex 32`. The third one starts the website's **daily job** (site visit reminders, clean-up) at 09:00 India time from the database's scheduler (`cron.job` → `website-daily-job`); use the same value as the website's `CRON_SECRET`.
9. **First super admin**:
   - **Authentication → Users → Add user**: their email and a temporary password, tick "Auto confirm".
   - SQL editor:
     ```sql
     insert into public.admin_users (user_id, full_name, email, role)
     select id, 'Full Name', email, 'super_admin' from auth.users where email = 'owner@<domain>';
     ```
   - They sign in at `https://admin.<domain>` and change the password (account menu → Change password). Everyone else is invited from **Admin users** inside the panel.
10. **Site settings**: the super admin fills in **Settings**: brand and company (tagline, line under the logo, legal name, and the registered office address, GST and RERA numbers if known), company name, phone, WhatsApp, email, address, office hours, sales notification emails. The website footer, Contact page and legal pages use these.
11. Copy from **Project Settings → API Keys**: the project URL, the **publishable** key (`sb_publishable_…`) and a **secret** key (`sb_secret_…`). The secret key bypasses every rule: it goes only into the website's secrets (step 5.2) and the password manager.

## 2. Cloudflare Turnstile (bot check)

1. Cloudflare dashboard → **Turnstile → Add widget**: domains `<domain>`, `www.<domain>` (staging: the staging address). Mode **Managed**.
2. Keep the **site key** (public) and **secret key** (server only) for step 5.

## 3. Map tiles

OpenStreetMap's own servers are not for public website traffic. Create a free account at a tile provider (e.g. MapTiler: free tier is enough at launch), restrict the key to `<domain>`, and use its URL in step 5 (`NEXT_PUBLIC_MAP_TILE_URL`, `NEXT_PUBLIC_MAP_ATTRIBUTION`). The admin panel's map can stay on OpenStreetMap (staff only, very little traffic).

## 4. Resend (email)

1. **(owner)** Resend → **Domains → Add** `<domain>`; add the DNS records it shows (SPF, DKIM, and a DMARC record such as `v=DMARC1; p=none; rua=mailto:dmarc@<domain>`) in the domain's DNS (GoDaddy, step 9); wait for "Verified".
2. Create an API key with **Sending access** only, restricted to that domain.
3. Send a test enquiry once the website is up (step 10): sales and customer emails must arrive and not land in spam.

## 5. Website on Firebase App Hosting

Decision 132. Settings that are not secret are in `web/apphosting.yaml` (one server, so cache refreshes reach every visitor; pages not stored at the CDN, so admin changes show at once). Secrets are in Google Cloud Secret Manager.

1. **(owner)** Firebase console → project `avanilands` → upgrade to the **Blaze** plan (pay as you go; App Hosting needs it). Then Google Cloud console → **Billing → Budgets & alerts**: a budget of e.g. ₹500/month with email alerts. Expected cost at launch traffic: ₹0–400/month.
2. Secrets (from the project folder; each asks to give the backend access — yes):
   ```bash
   npx firebase-tools login
   printf %s '<value>' | npx firebase-tools apphosting:secrets:set <name> --data-file - --project avanilands
   ```
   Names: `supabase-secret-key` (`sb_secret_…`), `revalidate-secret` (step 1.8), `ip-hash-salt` (`openssl rand -hex 32`), `cron-secret` (step 1.8's third secret). Later `turnstile-secret-key` (step 2) and `resend-api-key` (step 4) — and uncomment them, the Turnstile site key, map tiles and `SALES_NOTIFY_EMAIL` in `web/apphosting.yaml`. Until Turnstile is set, the website's forms refuse submissions (on purpose).
3. Create the backend:
   ```bash
   npx firebase-tools apphosting:backends:create --project avanilands \
     --backend avanilands-web --primary-region asia-southeast1 --root-dir web
   ```
   Connect GitHub (`learnersamba/avanilands`, branch `main`, automatic rollouts **on**) when asked. Singapore is the nearest App Hosting region (no Mumbai yet). The first rollout takes a few minutes; it prints the test address (`https://avanilands-web--avanilands.asia-southeast1.hosted.app`).
4. On the test address: properties show, and a change in the admin panel (e.g. a price) shows on the website within seconds.
5. Firebase console → **App Hosting → avanilands-web → Settings → Domains → Add custom domain**: `avanilands.in`, then `www.avanilands.in` (the website itself redirects `www` to `avanilands.in`). Add the records it shows in GoDaddy (step 9); HTTPS follows automatically.

Do **not** set `DEV_MAILPIT_URL` anywhere but your laptop. (Vercel still works if ever needed: the same values as plain environment variables, without `CDN_PAGE_CACHE`; `vercel.json` would then also run the daily job — harmless, each reminder is sent once.)

## 6. Admin panel on Firebase Hosting

Built on the laptop (no Flutter on hosting build machines) and uploaded. `tool/build_admin.sh` writes `admin/build/firebase.json` with the security headers (Content-Security-Policy for this Supabase project), app routing and no-cache, so every deploy is picked up at once.

1. Create `admin/env/production.json` (never shared, like `local.json`):
   ```json
   { "APP_ENV": "production", "SUPABASE_URL": "https://<ref>.supabase.co",
     "SUPABASE_PUBLISHABLE_KEY": "sb_publishable_…", "WEBSITE_URL": "https://<domain>" }
   ```
2. First time on this laptop: `npx firebase-tools login` (the Google account that owns the Firebase project).
3. Build and publish:
   ```bash
   tool/deploy_admin.sh admin/env/production.json      # Firebase project "avanilands"
   ```
   It prints the Hosting address (`https://avanilands.web.app`); the sign-in page must open there.
4. Firebase console → **Hosting → Add custom domain** → `admin.<domain>`. Add the records it shows in GoDaddy (step 9); Firebase then issues the HTTPS certificate (can take up to a few hours).
5. (Cloudflare Pages still works the same way if ever needed: `npx wrangler pages deploy admin/build/web` uses the `_headers` and `_redirects` files in the build.)

## 7. Search engines and analytics

1. **(owner)** Google Search Console → add the domain (DNS verification: a TXT record in GoDaddy) → **Sitemaps** → submit `https://<domain>/sitemap.xml`.
2. Analytics are built in (Phase 16, no extra service or cookies). After launch, open a few pages on a phone and check they appear in the admin's **Analytics** page within seconds. `IP_HASH_SALT` must be set (step above); changing it later only means visitors that day may be counted twice.

## 8. Error alerts

- Firebase console → **App Hosting → avanilands-web**: failed rollouts show on the Rollouts tab; **Logs** show website errors (search for `submit_enquiry failed`, `Turnstile`, `email`). Budget alerts (step 5.1) warn about unusual cost.
- Supabase → **Reports / Logs** and **Advisors** (security and performance warnings — should stay empty).
- Optional later: Sentry (free tier) for both apps; not added yet to keep the browser code small (decision 70).

## 9. Domain records at GoDaddy

GoDaddy → **My Products → avanilands.in → DNS**. Always copy the exact values each service shows (they can differ per project); typical values:

| Type | Name | Value | For |
|------|------|-------|-----|
| A | `@` | the IP App Hosting shows | website |
| TXT | `@` | the verification value App Hosting shows | website domain check |
| A / CNAME | `www` | as App Hosting shows | website (`www` → redirect) |
| TXT | `admin` (or `@`) | the verification value Firebase shows | admin domain check |
| A | `admin` | the IP(s) Firebase shows | admin panel |
| TXT / CNAME / MX | as Resend shows (`resend._domainkey`, `send`, …) | as Resend shows | email (SPF, DKIM) |
| TXT | `_dmarc` | `v=DMARC1; p=none; rua=mailto:dmarc@<domain>` | email |
| TXT | `@` | the value Search Console shows | Google |

- Delete GoDaddy's default **parked** `A @` record and the default `CNAME www → @` before adding the website's, or they clash.
- Keep any existing **MX** records if the company already receives email at this domain.
- New records usually work within minutes; allow up to 48 hours.

## 10. Final checks before telling anyone

Run on staging, then on production (production: only steps that don't create test data, plus one real enquiry you then close):

- [ ] `WEB_URL=https://<domain> SUPABASE_URL=… SUPABASE_PUBLISHABLE_KEY=… ADMIN_EMAIL=… ADMIN_PASSWORD=… VISITOR_EMAIL=… VISITOR_PASSWORD=… node tool/security_check.mjs` → ALL PASSED (**staging only**: it uploads and deletes test files; the visitor is a signed-in non-admin test user created for this)
- [ ] securityheaders.com on `https://<domain>` and `https://admin.<domain>`: grade A
- [ ] Firebase Hosting → Usage: the admin is served from `admin.<domain>` with a valid certificate
- [ ] `http://<domain>` and `https://www.<domain>` both end at `https://<domain>`
- [ ] Supabase Advisors: no security warnings
- [ ] The journey from a real phone: publish a property in the admin → find it on the website → send an enquiry → sales email arrives → mark it Contacted with a note
- [ ] Desktop alert appears in the admin panel when an enquiry arrives
- [ ] A site visit booked on the phone: sales + customer emails; confirm it in the admin → "confirmed" email arrives
- [ ] Daily job: Supabase SQL editor → `select private.run_daily_website_job();` → App Hosting **Logs** show `GET /api/site-visits/reminders` answered 200 (`select * from cron.job_run_details order by start_time desc limit 5;` shows the scheduled runs)
- [ ] `https://<domain>/account` and `/book/AL-0001` answer "not found" while those features are off
- [ ] *(When switched on)* A customer signs in with the emailed code, saves a property and sees it in My account
- [ ] *(When switched on)* A booking: request (signed in) → send for approval → super admin approves → the property shows Reserved on the website → cancel it → Available again
- [ ] **(owner)** Replace every PLACEHOLDER text in Website content (About, two FAQs) and mark the legal pages final once your legal advisor has approved them
- [ ] An admin invite email arrives and the link opens the "set password" page on `admin.<domain>`
- [ ] Backups: step 1 of [RECOVERY.md](RECOVERY.md) done and the first backup downloaded
- [ ] Lighthouse (mobile) on home, listing and a property page: 90+

## Updating later

- Database changes: `supabase db push` (staging first).
- Website: App Hosting builds and rolls out automatically on every push to `main` (console → App Hosting → Rollouts).
- Switching a feature back on (decision 132): set it to `true` in `web/src/lib/features.ts` and/or `admin/lib/core/features.dart`, push, and redeploy the admin; for customer accounts also turn Supabase sign-ups on (step 1.3).
- Admin: `tool/deploy_admin.sh admin/env/production.json` (step 6.3).
- Edge Function changes: `supabase functions deploy invite-admin`.
