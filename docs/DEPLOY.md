# Going live — step by step

Everything here is done **once per environment**: first for **staging** (a test copy on the internet), then again for **production**. Do staging first and run the checks at the end before touching production.

Who does what: steps marked **(owner)** need the owner's accounts, payment or decisions. Everything else a developer can do with access.

What you need before starting:
- The final **brand name and domain** (decision 5). Until then, staging can run on the free Vercel/Cloudflare addresses.
- Accounts: Supabase, Vercel, Cloudflare (domain DNS, Pages, Turnstile), Resend. Use a shared company email, not a personal one, and turn on two-factor sign-in everywhere.
- On the developer's laptop: this folder, Node 22, Flutter, Supabase CLI, Docker.

---

## 1. Supabase project

1. **(owner)** Create the project: region **Mumbai (ap-south-1)**; production on the **Pro plan** (daily backups; the free plan pauses and has none). Save the database password in the company password manager.
2. Link and apply the database:
   ```bash
   supabase link --project-ref <project-ref>
   supabase db push
   ```
   This creates every table, rule, function, storage bucket and policy. **Never run `supabase/seed.sql` on staging or production** (test logins and made-up properties).
3. **Authentication → Sign In / Providers**: keep "Allow new users to sign up" **on** (customer accounts, Phase 11 — staff access still needs `admin_users`), keep the Email provider on with **Confirm email on**. **Rate limits**: emails per hour ~100 (needs the custom SMTP below).
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
8. **Website cache refresh** (admin changes appear on the website within seconds). In the SQL editor, with the real website address and a long random secret (the same secret goes into Vercel as `REVALIDATE_SECRET`):
   ```sql
   select vault.create_secret('https://<domain>/api/revalidate', 'website_revalidate_url');
   select vault.create_secret('<long random secret>', 'website_revalidate_secret');
   ```
   Generate a secret with `openssl rand -hex 32`.
9. **First super admin**:
   - **Authentication → Users → Add user**: their email and a temporary password, tick "Auto confirm".
   - SQL editor:
     ```sql
     insert into public.admin_users (user_id, full_name, email, role)
     select id, 'Full Name', email, 'super_admin' from auth.users where email = 'owner@<domain>';
     ```
   - They sign in at `https://admin.<domain>` and change the password (account menu → Change password). Everyone else is invited from **Admin users** inside the panel.
10. **Site settings**: the super admin fills in **Settings** (company name, phone, WhatsApp, email, address, office hours, sales notification emails).
11. Copy from **Project Settings → API Keys**: the project URL, the **publishable** key (`sb_publishable_…`) and a **secret** key (`sb_secret_…`). The secret key bypasses every rule: it goes only into Vercel's server settings and the password manager.

## 2. Cloudflare Turnstile (bot check)

1. Cloudflare dashboard → **Turnstile → Add widget**: domains `<domain>`, `www.<domain>` (staging: the staging address). Mode **Managed**.
2. Keep the **site key** (public) and **secret key** (server only) for step 5.

## 3. Map tiles

OpenStreetMap's own servers are not for public website traffic. Create a free account at a tile provider (e.g. MapTiler: free tier is enough at launch), restrict the key to `<domain>`, and use its URL in step 5 (`NEXT_PUBLIC_MAP_TILE_URL`, `NEXT_PUBLIC_MAP_ATTRIBUTION`). The admin panel's map can stay on OpenStreetMap (staff only, very little traffic).

## 4. Resend (email)

1. **(owner)** Resend → **Domains → Add** `<domain>`; add the DNS records it shows (SPF, DKIM, and a DMARC record such as `v=DMARC1; p=none; rua=mailto:dmarc@<domain>`) in Cloudflare DNS; wait for "Verified".
2. Create an API key with **Sending access** only, restricted to that domain.
3. Send a test enquiry once the website is up (step 9): sales and customer emails must arrive and not land in spam.

## 5. Website on Vercel

1. **(owner)** Vercel project → import the repository (`learnersamba/avanilands` on GitHub) with **Root Directory** `web`. Production needs the **Pro plan** (Hobby is non-commercial only, decision 27).
2. **Environment variables** (Production; and Preview for staging, with the staging values):

   | Name | Value |
   |------|-------|
   | `NEXT_PUBLIC_SITE_URL` | `https://<domain>` (no `www`, no trailing slash) |
   | `NEXT_PUBLIC_SUPABASE_URL` | project URL |
   | `NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY` | `sb_publishable_…` |
   | `SUPABASE_SECRET_KEY` | `sb_secret_…` (**Sensitive**) |
   | `REVALIDATE_SECRET` | the secret from step 1.8 (**Sensitive**) |
   | `NEXT_PUBLIC_TURNSTILE_SITE_KEY` / `TURNSTILE_SECRET_KEY` | from step 2 (secret: **Sensitive**) |
   | `RESEND_API_KEY` | from step 4 (**Sensitive**) |
   | `EMAIL_FROM` | `Avanilands <enquiries@<domain>>` |
   | `SALES_NOTIFY_EMAIL` | fallback sales inbox (Settings in the admin panel wins) |
   | `IP_HASH_SALT` | `openssl rand -hex 32` (**Sensitive**) |
   | `ADMIN_URL` | `https://admin.<domain>` (link in sales emails) |
   | `CRON_SECRET` | `openssl rand -hex 24` (**Sensitive**) — Vercel sends it to the daily reminder job in `vercel.json` |
   | `NEXT_PUBLIC_MAP_TILE_URL` / `NEXT_PUBLIC_MAP_ATTRIBUTION` | from step 3 |

   Do **not** set `DEV_MAILPIT_URL` anywhere but your laptop.
3. **Domains**: add `<domain>` and `www.<domain>`; set `www` to redirect (308) to `<domain>`. Vercel issues HTTPS certificates automatically.
4. Deploy, then open `https://<domain>`: properties, photos and the map must show.

## 6. Admin panel on Cloudflare Pages

Cloudflare's build machines don't have Flutter, so build on the laptop and upload:

1. Create `admin/env/production.json` (never shared, like `local.json`):
   ```json
   { "APP_ENV": "production", "SUPABASE_URL": "https://<ref>.supabase.co",
     "SUPABASE_PUBLISHABLE_KEY": "sb_publishable_…", "WEBSITE_URL": "https://<domain>" }
   ```
2. Build (adds the security headers and app routing for this Supabase project) and upload:
   ```bash
   tool/build_admin.sh admin/env/production.json
   npx wrangler pages deploy admin/build/web --project-name avanilands-admin
   ```
3. Cloudflare Pages → the project → **Custom domains** → `admin.<domain>`.
4. Optional extra lock: **Cloudflare Zero Trust → Access** on `admin.<domain>` allowing only company email addresses (a second sign-in before the panel even loads).

## 7. Search engines and analytics

1. **(owner)** Google Search Console → add the domain (DNS verification in Cloudflare) → **Sitemaps** → submit `https://<domain>/sitemap.xml`.
2. Analytics are built in (Phase 16, no extra service or cookies). After launch, open a few pages on a phone and check they appear in the admin's **Analytics** page within seconds. `IP_HASH_SALT` must be set (step above); changing it later only means visitors that day may be counted twice.

## 8. Error alerts

- Vercel → project → **Settings → Notifications**: email on failed deployments; **Logs** show website errors (search for `submit_enquiry failed`, `Turnstile`, `email`).
- Supabase → **Reports / Logs** and **Advisors** (security and performance warnings — should stay empty).
- Optional later: Sentry (free tier) for both apps; not added yet to keep the browser code small (decision 70).

## 9. Final checks before telling anyone

Run on staging, then on production (production: only steps that don't create test data, plus one real enquiry you then close):

- [ ] `WEB_URL=https://<domain> SUPABASE_URL=… SUPABASE_PUBLISHABLE_KEY=… ADMIN_EMAIL=… ADMIN_PASSWORD=… VISITOR_EMAIL=… VISITOR_PASSWORD=… node tool/security_check.mjs` → ALL PASSED (**staging only**: it uploads and deletes test files; the visitor is a signed-in non-admin test user created for this)
- [ ] securityheaders.com on `https://<domain>` and `https://admin.<domain>`: grade A
- [ ] `http://<domain>` and `https://www.<domain>` both end at `https://<domain>`
- [ ] Supabase Advisors: no security warnings
- [ ] The journey from a real phone: publish a property in the admin → find it on the website → send an enquiry → sales email arrives → mark it Contacted with a note
- [ ] Desktop alert appears in the admin panel when an enquiry arrives
- [ ] A site visit booked on the phone: sales + customer emails; confirm it in the admin → "confirmed" email arrives
- [ ] Vercel → project → **Cron Jobs** lists `/api/site-visits/reminders`; **Run** it once and check the log says `sent`
- [ ] A customer signs in with the emailed code, saves a property and sees it in My account
- [ ] A booking: request (signed in) → send for approval → super admin approves → the property shows Reserved on the website → cancel it → Available again
- [ ] **(owner)** Replace every PLACEHOLDER text in Website content (About, two FAQs) and mark the legal pages final once your legal advisor has approved them
- [ ] An admin invite email arrives and the link opens the "set password" page on `admin.<domain>`
- [ ] Backups: step 1 of [RECOVERY.md](RECOVERY.md) done and the first backup downloaded
- [ ] Lighthouse (mobile) on home, listing and a property page: 90+

## Updating later

- Database changes: `supabase db push` (staging first).
- Website: Vercel deploys automatically from the main branch once git is set up.
- Admin: repeat step 6.2.
- Edge Function changes: `supabase functions deploy invite-admin`.
