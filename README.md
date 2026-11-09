# Avanilands

Company-owned land-selling platform.

| Folder | What | Tech |
|--------|------|------|
| `web/` | Customer website | Next.js 16 (App Router, TypeScript, Tailwind CSS 4) |
| `admin/` | Admin panel | Flutter web (Riverpod 3, go_router, supabase_flutter) |
| `supabase/` | Database migrations, seed, functions, tests | Supabase |
| `docs/` | Requirements, decisions, architecture, phase plans | Markdown — start with [docs/README.md](docs/README.md) |

## Requirements

Node 22+, Flutter 3.47+ (stable), Docker, Supabase CLI 2.x.

## Run locally

1. **Start Supabase** (from this folder). The first start downloads Docker images.
   ```bash
   supabase start
   ```
   Local ports: API `56421`, database `56422`, Studio `http://127.0.0.1:56423`, email inbox `http://127.0.0.1:56424`.

2. **Website** — copy `web/.env.example` to `web/.env.local` and fill in the values from `supabase status`, then:
   ```bash
   npm --prefix web install
   npm --prefix web run dev
   ```
   Opens at http://localhost:3100.

3. **Admin** — copy `admin/env/example.json` to `admin/env/local.json` and fill in the values from `supabase status`, then:
   ```bash
   tool/run_admin.sh
   ```
   Opens at http://127.0.0.1:3101 (debug mode, hot reload with `r`).
   To test the release build instead (what gets deployed): `tool/serve_admin.sh`.

The website opens on its homepage with the sample properties; the admin opens on its sign-in page.

## Sample photos (local only)

After `supabase db reset`, run `tool/seed_photos.sh` to give the sample properties placeholder photos (needs ffmpeg).

## Test logins (local only)

Listed at the top of `supabase/seed.sql`. Emails sent by local Supabase (invites, password resets) appear at http://127.0.0.1:56424.

## Database changes

Add a migration with `supabase migration new <name> < /dev/null` (the `< /dev/null` stops it waiting for input), write the SQL, then apply it from scratch with `supabase db reset`.

## Edge Functions

Live in `supabase/functions/`. After editing one locally, restart the runtime: `docker restart supabase_edge_runtime_avanilands`.

## Tests

- Database: `supabase test db`
- Admin: `cd admin && flutter test`
- Website: `cd web && npm test`
- Security over HTTP (website + Supabase must be running): `node tool/security_check.mjs`
- Speed test data: `docker exec -i supabase_db_avanilands psql -U postgres -f - < tool/load_test_properties.sql` (500 extra properties; remove with `supabase db reset` + `tool/seed_photos.sh`)

## Backups and going live

- Backups: `tool/backup_db.sh`, `tool/backup_files.mjs`, `tool/weekly_backup.sh`; restore with `tool/restore_db.sh` — see [docs/RECOVERY.md](docs/RECOVERY.md).
- Admin build for hosting (security headers included): `tool/build_admin.sh admin/env/<env>.json`.
- Staging/production setup: [docs/DEPLOY.md](docs/DEPLOY.md). Sales team guide: [docs/STAFF-GUIDE.md](docs/STAFF-GUIDE.md).

## Secrets

Never commit `web/.env.local` or `admin/env/local.json`. Only the example files are shared. Server-only keys (`SUPABASE_SECRET_KEY` and later Resend/Turnstile secrets) must never have the `NEXT_PUBLIC_` prefix.
