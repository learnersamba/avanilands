# Phase 14 — Website content (CMS)

**Goal:** the team edits the website's words and pictures in the admin panel — no code changes, no developer. From the owner's plan: homepage (hero title, description, image, promotional sections, featured properties), About (description, images, mission, vision, values), FAQ (add / edit / delete / reorder), testimonials (add / edit / remove), banners (add / remove / replace / reorder), plus the legal pages, with a **preview before publishing**.

## Rules (decisions 103–110)
- **Super admins** edit website content (it speaks for the company); other admins can read it.
- Page texts (home sections, About, legal pages) have a **draft** and a **published** version. Edit the draft → **Preview** (a private link that works for one hour, never indexed) → **Publish**. **Discard** throws the draft away.
- FAQs, testimonials and banners are published one by one (a switch on each) and ordered by dragging.
- **Testimonials only from real customers, with their permission** (India's Consumer Protection guidelines on fake reviews): a testimonial can't be published until "the customer agreed to this being shown" is ticked.
- Banners: image, short text, optional link (a page on this website or an `https://` address), shown **from / until** dates; the website follows the schedule within about a minute.
- Text only (no HTML): line breaks become paragraphs. Nothing typed can run as code on the website.
- Hero: one image (no video — it would slow phones down).
- Featured properties already have their order in the property editor (Phase 3); the homepage section links there.
- The migration starts with **today's website text** (PLACEHOLDER lines still marked), so the website looks the same until someone edits it. If content ever fails to load, the website falls back to that text.

## Checklist
### Database
- [x] `content_blocks` (key, draft, published) with shape and length checks; public view of published values only
- [x] `faqs`, `testimonials` (consent rule), `banners` (schedule, safe links); public rows only when published / in schedule
- [x] Writes for super admins only; publish / discard functions; preview tokens (1 hour); activity log; website cache refresh
- [x] Initial content from the current website; pgTAP tests

### Website
- [x] Home, About, FAQ and legal pages read the content (cached, refreshed on publish), with the built-in text as fallback
- [x] Testimonials section and banners on the home page (only when there are any)
- [x] `/preview/[page]?token=…` shows drafts (and hidden FAQs) with a "Preview" bar; refused without a valid token

### Admin
- [x] **Website content** page (super admins): Home, About, FAQs, Testimonials, Banners, Legal pages
- [x] Page texts: forms for each section, Save draft / Preview / Publish / Discard, "unpublished changes" marker
- [x] Lists: add / edit / delete / reorder / publish switch; images uploaded and shrunk in the browser

## Done when
A super admin changes the hero title and image → previews it → publishes → the home page shows it within seconds; adds an FAQ, reorders it to the top, unpublishes another; adds a testimonial (refused until consent is ticked); schedules a banner for tomorrow (not shown today); marks the Terms as final (the "draft text" note disappears). A plain admin can't change any of it.

## Notes (2026-11-09)
- **Database:** `20261109130001_website_content.sql` — `content_blocks` (9 page texts: published + draft, checked by `private.content_problem`: text only, length and list limits, known icons, own-upload image paths, required fields), view `public_content` (published only), `faqs`, `testimonials` (`published_needs_consent`), `banners` (safe links, schedule), `content_previews` (1-hour tokens), `publish_content`, `discard_content_draft`, `create_content_preview`, `reorder_content`, audit and website-refresh triggers; starting content = today's website text. Tests: `10_website_content.test.sql` (29); the exposure scan covers the new tables.
- **Found by the tests:** a valid draft couldn't be saved because the table's check runs with the editor's permissions and they couldn't call the check function — fixed (it's a pure text check, now callable by signed-in users).
- **Website:** `lib/content.ts` (defensive parsing with fallback to `content/site.ts`), `getSiteContent` / `getFaqs` / `getTestimonials` / `getBanners` (cached; banners on the "minutes" profile so dates take effect within about a minute), views (`components/views/*`) shared by the real pages and `/preview/[page]` (token-checked, noindex, always live); home gets banners, testimonials and an optional hero photo. Also fixed two dev-mode warnings that could slow pre-rendering: the compare tray now sits in a Suspense boundary and the Save heart reads the address only when tapped; the preview page declares itself live (`connection()`). Production build clean.
- **Admin:** Website content page (super admins; also guarded by the router): generic section editor driven by `content_models.dart` (fields, lists, move up/down, icons, photo upload), draft / preview / publish / discard; FAQs, testimonials and banners lists with drag-to-reorder and edit dialogs; activity lines.
- **Checked:** 269 database, 68 website, 87 admin tests; security check; enquiry, listing, comparison and account flows. Journey: hero draft (website unchanged) → preview shows it → publish with a new photo (home shows both) → FAQ added, dragged to the top, another hidden (FAQ page follows) → testimonial locked until consent, then shown → unsafe banner link refused, banner shown, a tomorrow banner not shown → Terms marked final (draft note gone, Privacy still draft) → plain admin has no menu item and is sent away from /content.
- **Owner to do:** replace the PLACEHOLDER texts (About; two FAQs) and have the legal pages checked.
