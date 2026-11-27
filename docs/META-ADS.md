# Meta (Facebook & Instagram) ads — setup and how it works

Decision 133. Everything is **off** until you finish the steps below. Until then the
website stays cookie-free and shows no cookie banner.

## How it works (in one minute)

| What happens on the website | Sent to Meta as | From | When |
|---|---|---|---|
| A page is opened | `PageView` | Browser (Pixel) | Visitor allowed ad cookies |
| A property page is opened | `ViewContent` (property code, price in INR) | Browser | 〃 |
| /land searched by place or land type | `Search` | Browser | 〃 |
| Call or WhatsApp button tapped | `Contact` | Browser | 〃 |
| **Enquiry sent** | **`Lead`** — the event to optimise campaigns for | Browser **and** server (Conversions API), same event id so counted once | 〃 |
| Site visit requested | `Schedule` | Browser and server | 〃 |
| Team marks enquiry **Interested** | `QualifiedLead` (custom) | Server, from the admin panel | 〃, and Advertising on |
| Team marks enquiry **Converted** | `ConvertedLead` (custom) | Server | 〃 |
| Team marks site visit **Completed** | `SiteVisitCompleted` (custom) | Server | 〃 |

- **Consent first.** The banner offers "No thanks" and "Allow ad cookies" with equal weight. Nothing
  goes to Meta without a yes. Browsers sending Global Privacy Control are treated as no and not asked.
  Visitors can change their answer from **Cookie choices** in the footer.
- Names, messages and payments **never** go to Meta. Phone and email go **SHA-256 hashed**, from our
  server only.
- **Campaign tags** (`utm_source`, `utm_campaign`, …) are saved with every enquiry and visit request,
  consent or not (they describe the advert, not the person). The admin panel shows them in a
  **Campaign** card on each enquiry / site visit, and in the enquiries CSV.
- The admin panel needs **no extra work**: changing a status as usual is what reports results to Meta.

## One-time setup

### 1. Meta Business (owner)
1. In **Meta Business Suite → Settings**, make sure the business is *Tirupa Technologies Pvt. Ltd.*,
   with the Avanilands Facebook page, Instagram account and ad account added.
2. **Brand safety → Domains → Add** `avanilands.in` and verify it (DNS TXT record at GoDaddy is easiest).
3. **Events Manager → Connect data sources → Web → Meta Pixel**. Name it *Avanilands website*.
   Copy the **Dataset / Pixel ID** (digits only).
4. In that dataset: **Settings → Conversions API → Generate access token**. Copy it — it is shown once.
   Treat it like a password.
5. In the same settings, turn **Automatic advanced matching** and **Track events automatically
   without code** **off** (the website sends exactly what it should, already hashed).

### 2. Database (developer)
Apply the migrations `20261127100001_meta_ads.sql` and `20261127100002_privacy_policy_meta.sql`
(`supabase db push`). They use the Vault secrets already set in DEPLOY.md step 1.8.
Deploy the database **before** the admin panel (the panel reads the new tables).

### 3. Website (developer)
```bash
npx firebase-tools apphosting:secrets:set meta-capi-access-token --project avanilands
```
Then in `web/apphosting.yaml` uncomment `NEXT_PUBLIC_META_PIXEL_ID` (with the id) and
`META_CAPI_ACCESS_TOKEN`. For the first test also uncomment `META_TEST_EVENT_CODE` with the code from
**Events Manager → Test events**. Push to `main` (App Hosting rolls out automatically).

### 4. Privacy policy (Super Admin + legal advisor)
The new policy (DPDP Act, 2023; Meta advertising) is already published if the old one was never
edited, otherwise it is waiting as a **draft** in *Website content → Privacy*. Have the company's legal
advisor review it, add the Grievance Officer's name if they want it named, then publish and tick
*final* to remove the "draft text" note.

### 5. Switch it on (Super Admin)
Admin panel → **Settings → Advertising (Meta)** → switch on → **Save settings**. The banner appears
on the website within a minute.

### 6. Test (15 minutes)
1. Open avanilands.in in a private window, choose **Allow ad cookies**.
2. Events Manager → **Test events**: you should see `PageView`; open a property → `ViewContent`.
3. Send a test enquiry with your own number → `Lead` appears **twice** (Browser and Server) with the
   note *Deduplicated*. Same for a site visit → `Schedule`.
4. In the admin panel, mark that enquiry **Interested** → `QualifiedLead` (Server) within a minute.
5. Choose **Cookie choices → No thanks** and reload: nothing more arrives.
6. Delete the test enquiry's data if you like, remove `META_TEST_EVENT_CODE`, and redeploy.

## Running campaigns

- **Objective:** *Leads* → conversion location *Website* → optimise for **Lead**. When you have
  ~50 QualifiedLead a month, try a custom conversion on `QualifiedLead` instead — it finds better buyers.
- **Tag every ad link**, e.g.
  `https://avanilands.in/land/<property>?utm_source=facebook&utm_medium=paid_social&utm_campaign=vizag-plots-nov&utm_content={{ad.name}}`
  (Meta fills `{{ad.name}}` in). The admin panel then shows which campaign and ad each lead came from.
- **Housing ads:** Meta may treat land ads as a *Special Ad Category (Housing)*, especially if the
  ad targets outside India, and limit age, gender and postcode targeting. Plan for broad audiences
  in the cities you sell in; the conversion signal above is what does the targeting.
- **RERA:** if a project is RERA-registered, put the RERA number in every advert, as on the website.
- **Keep statuses up to date:** mark enquiries Interested / Converted as soon as you know — the
  sooner Meta hears, the sooner it learns. Each result is sent within a minute; if Meta can't be
  reached, the daily job retries for up to 7 days (Meta's limit), then gives up.

## Switching off
Settings → Advertising → off. The banner and pixel disappear, nothing more is sent, and queued
results are not sent. What was already sent stays with Meta (that is in the privacy policy).

## Where the code is
- Website: `web/src/components/consent/` (banner, pixel, events), `web/src/lib/consent*.ts`,
  `lib/meta-pixel.ts` (browser), `lib/meta-capi.ts`, `lib/meta-events.ts`, `lib/lead-tracking.ts`,
  `lib/meta-queue.ts`, `app/api/meta/send/route.ts`; daily retries in `api/site-visits/reminders`.
- Database: `supabase/migrations/20261127100001_meta_ads.sql`, test `tests/database/15_meta_ads.test.sql`.
- Admin: Settings → Advertising; Campaign card in `features/enquiries/enquiry_detail_page.dart`.
