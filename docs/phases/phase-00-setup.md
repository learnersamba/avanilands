# Phase 0 — Project setup ✅

**Goal:** empty but working website, admin app and local Supabase, ready for real work.
**Depends on:** nothing. **No git** yet (decision 4).

## Checklist
- [x] Check tools: Node LTS, npm, Flutter stable, Docker, Supabase CLI
- [x] `web/`: create Next.js app (TypeScript, App Router, Tailwind, ESLint), add `@supabase/ssr`, `@supabase/supabase-js`, `zod`
- [x] `web/`: placeholder home page, `.env.example` (all variable names, no values), `.env.local` git-ignored
- [x] `admin/`: create Flutter web app; add `supabase_flutter`, `flutter_riverpod`, `riverpod_annotation`, `go_router`, `intl`; same versions as Godavari Ghaatu
- [x] `admin/`: placeholder login page; env via `--dart-define-from-file=env/local.json` (git-ignored) + `env/example.json`
- [x] `supabase/`: `supabase init`, start local stack on free ports (avoid clashes with Godavari Ghaatu's 553xx ports)
- [x] Both apps connect to local Supabase (simple health query)
- [x] `.gitignore` ready for when git starts (env files, build output, node_modules)
- [x] Root `README.md`: how to run each part locally
- [x] `.claude/launch.json` entries for the website and admin previews

## Done when
- `npm run dev` shows the placeholder website at localhost
- `flutter run -d chrome` (or web-server) shows the admin login placeholder
- both talk to local Supabase without errors

## Notes (2026-11-08)
- Versions: Next.js 16.4 (Cache Components on, React 19.3, Tailwind 4), Flutter 3.47 / Dart 3.13, Supabase CLI 2.117, Node 22.
- Ports: website **3100**, admin **3101**, local Supabase **564xx** (API 56421, DB 56422, Studio 56423, email 56424). Godavari Ghaatu uses 553xx and another project uses 543xx.
- Keys: both apps use the new **publishable key** (`sb_publishable_…`); the website server uses the **secret key** (`sb_secret_…`) instead of the old anon/service-role JWTs. Checked: the secret key is not in either browser bundle.
- `health()` database function (first migration) is what both "Backend: ok" checks call.
- Email sign-ups are off in `supabase/config.toml` (decision 23).
- `supabase migration new` waits for SQL on stdin when it isn't run in a terminal: use `< /dev/null`.
- Admin preview in the browser pane uses the release build (`tool/serve_admin.sh`); the debug server (`tool/run_admin.sh`) is for hot reload in a normal browser.
