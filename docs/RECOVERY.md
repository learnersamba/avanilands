# Backups and recovery

What protects the data, how to get it back, and who to call. Keep a printed copy with the owner.

## What is backed up

| What | How | How often | Kept for | Where |
|------|-----|-----------|----------|-------|
| Database (properties, enquiries, admins, activity log, settings) | Supabase automatic backups (Pro plan) | Daily | 7 days | Supabase |
| Database + every photo, video and document | `tool/weekly_backup.sh` (one dated archive) | Weekly | 8 weeks | A second provider (Cloudflare R2 or Backblaze B2) and the backup machine |
| Code, migrations, scripts | Git repository (once named) | Every change | Forever | GitHub |

The weekly archive matters because Supabase's daily backups **do not include stored files** (photos, videos, documents) and live with the same company. If the Supabase account were lost, the weekly archive is the only copy.

Not in any backup (write them in the password manager instead): the Vault secrets for the website cache refresh, API keys (Vercel, Resend, Turnstile, map tiles), and the Edge Function (redeployed from the code).

## 1. Setting up the weekly backup (once)

1. **(owner)** Create a bucket at a second provider (e.g. Cloudflare R2 `avanilands-backups`, private) and an access key that can only write to that bucket.
2. On an always-on machine (office PC or a small server) with this folder, Node 22, the Supabase CLI, Docker and [rclone](https://rclone.org):
   ```bash
   rclone config            # add a remote called "r2" with the key from step 1
   ```
3. Store the settings in a file only that user can read, e.g. `~/.avanilands-backup.env`:
   ```bash
   export BACKUP_DB_URL='postgresql://postgres.<ref>:<db-password>@aws-0-ap-south-1.pooler.supabase.com:5432/postgres'
   export SUPABASE_URL='https://<ref>.supabase.co'
   export SUPABASE_SECRET_KEY='sb_secret_…'
   export RCLONE_REMOTE='r2:avanilands-backups'
   ```
4. Schedule it every Sunday at 2 am (`crontab -e`):
   ```
   0 2 * * 0  . ~/.avanilands-backup.env && /path/to/Avanilands/tool/weekly_backup.sh >> ~/avanilands-backup.log 2>&1
   ```
5. First Monday: check the log ends with "Copied to …" and the archive is in the bucket. Then check monthly. (Once the code is on GitHub this can move to a scheduled GitHub Action.)

## 2. Restoring

Decide first **what** was lost. Most problems need only one of these.

### A. Someone changed or deleted something by mistake (a property, a photo)
Don't restore the whole database for one property. Look in the admin **Activity log** for the old values (price, status, fields) and type them back. Deleted photos: take the file from the latest weekly archive (`files/property-media/…`) and upload it again in the property editor.

### B. The database is damaged or wrongly changed in bulk (last 7 days)
Supabase dashboard → **Database → Backups** → choose the day → **Restore**. The site is down for a few minutes. Everything after that backup is lost: note any enquiries from the sales emails and re-enter them.

### C. Everything is gone (account lost, project deleted, older than 7 days)
Takes about 1–2 hours. Tested on 2026-11-09 against the local copy (see below).

1. Create a new Supabase project and do [DEPLOY.md](DEPLOY.md) step 1 items 1–8 (this rebuilds the empty structure with `supabase db push`). Skip "First super admin": admins come back from the backup.
2. Unpack the latest archive: `tar -xzf backup-YYYY-MM-DD.tar.gz`.
3. Load the data (empties the new project's tables and loads everything in one go; if anything fails, nothing changes):
   ```bash
   tool/restore_db.sh backup-YYYY-MM-DD/db '<new project session pooler connection string>'
   ```
4. Put the files back:
   ```bash
   SUPABASE_URL=https://<new-ref>.supabase.co SUPABASE_SECRET_KEY=sb_secret_… \
     node tool/backup_files.mjs restore backup-YYYY-MM-DD/files
   ```
5. Point the apps at the new project: new URL and keys in Vercel (DEPLOY step 5) and a rebuilt admin (step 6). Admins sign in with their old passwords.
6. Check: properties and photos on the website, a test enquiry, admin sign-in, `node tool/security_check.mjs` on staging.

## 3. If a key or password leaks

Change it first, investigate after.

| Leaked | Do this |
|--------|---------|
| Supabase **secret** key (`sb_secret_…`) | Supabase → API Keys → create a new secret key → put it in Vercel (and the backup machine) → redeploy → **delete the old key** |
| Database password | Supabase → Database → Reset password → update the backup machine |
| Admin's password / lost laptop | Super admin: **Admin users → Deactivate** (immediate), then reactivate after they reset their password |
| `REVALIDATE_SECRET` | New value in Vercel and in Vault (`select vault.update_secret(id, '<new>') from vault.secrets where name = 'website_revalidate_secret';`) |
| Resend / Turnstile / map keys | Create a new key in that service → Vercel → redeploy → delete the old one |

The publishable key (`sb_publishable_…`) and the Turnstile site key are public by design; leaking them is not a problem.

## 4. Restore test log

| Date | Where | Result |
|------|-------|--------|
| 2026-11-09 | Local copy | Backed up (3 SQL files + 102 files), deleted every stored file, wiped the database (`supabase db reset --no-seed`), restored with `tool/restore_db.sh` + `tool/backup_files.mjs restore`. Row counts and a fingerprint of all properties identical; photos load; admins sign in with old passwords; enquiry numbering continues (ENQ-000004). Found and fixed: Supabase-internal storage tables must be left out of the dump. |
| | Staging | **To do once staging exists** (repeat plan C on staging, record here) |

## 5. Who to contact

| For | Who | How |
|-----|-----|-----|
| Website/admin problems | Developer: _name_ | _phone / email_ |
| Business decisions, account owner | Owner: _name_ | _phone / email_ |
| Supabase (database, files, sign-in) | Supabase support | Dashboard → Support (Pro plan: email support) |
| Website hosting | Vercel support | vercel.com/help |
| Domain, DNS, admin hosting | Cloudflare | Dashboard → Support |
| Email delivery | Resend | resend.com/help |
