import type { Metadata } from "next";
import { connection } from "next/server";
import { Suspense } from "react";

import { LegalPage } from "@/components/legal-page";
import { AboutView } from "@/components/views/about-view";
import { FaqView } from "@/components/views/faq-view";
import { HomeView } from "@/components/views/home-view";
import { Container } from "@/components/ui";
import {
  type Banner,
  type Faq,
  parseContent,
  type Testimonial,
} from "@/lib/content";
import {
  getFeaturedProperties,
  getLocations,
  getPropertyTypes,
  getRecentProperties,
} from "@/lib/data";
import { createAdminClient } from "@/lib/supabase/admin";

export const metadata: Metadata = {
  title: "Preview",
  robots: { index: false, follow: false },
};

const pages = [
  "home",
  "about",
  "faq",
  "terms",
  "privacy",
  "disclaimer",
] as const;

/**
 * Private preview of unpublished website content (drafts, hidden FAQs,
 * scheduled banners), opened from the admin panel with a one-hour link.
 */
export default function PreviewPage(props: PageProps<"/preview/[page]">) {
  return (
    <Suspense
      fallback={
        <Container className="py-20 text-muted">Loading preview…</Container>
      }
    >
      <Preview params={props.params} searchParams={props.searchParams} />
    </Suspense>
  );
}

async function Preview({
  params,
  searchParams,
}: {
  params: PageProps<"/preview/[page]">["params"];
  searchParams: PageProps<"/preview/[page]">["searchParams"];
}) {
  // Always a fresh, per-request page (checks the clock and the database).
  await connection();
  const requested = (await params).page;
  const page = pages.find((p) => p === requested);
  const token = (await searchParams).token;
  const admin = createAdminClient();
  const valid =
    page &&
    typeof token === "string" &&
    /^[0-9a-f-]{36}$/i.test(token) &&
    (
      await admin
        .from("content_previews")
        .select("token")
        .eq("token", token)
        .gt("expires_at", new Date().toISOString())
        .maybeSingle()
    ).data;
  if (!valid) {
    return (
      <Container className="max-w-xl py-20">
        <h1 className="font-serif text-3xl text-forest">
          This preview link has expired
        </h1>
        <p className="mt-2 text-ink/75">
          Preview links work for one hour. Open a new one from the admin panel.
        </p>
      </Container>
    );
  }

  // Drafts where there are any, published text elsewhere.
  const [
    { data: blocks },
    { data: faqs },
    { data: testimonials },
    { data: banners },
  ] = await Promise.all([
    admin.from("content_blocks").select("key, published, draft"),
    admin
      .from("faqs")
      .select("id, question, answer, show_on_home, is_published")
      .order("sort_order"),
    admin
      .from("testimonials")
      .select("id, name, place, quote, rating, photo_path, is_published")
      .eq("has_consent", true)
      .order("sort_order")
      .limit(6),
    admin
      .from("banners")
      .select("id, title, text, link_url, link_label, image_path, starts_at")
      .eq("is_active", true)
      .or(`ends_at.is.null,ends_at.gt.${new Date().toISOString()}`)
      .order("sort_order")
      .limit(3),
  ]);
  const content = parseContent(
    (blocks ?? []).map((b) => ({ key: b.key, value: b.draft ?? b.published })),
  );
  const drafts = (blocks ?? []).filter((b) => b.draft).length;

  return (
    <>
      <div className="sticky top-16 z-30 bg-reserved px-4 py-2 text-center text-sm font-semibold text-white">
        Preview —{" "}
        {drafts === 0
          ? "no unpublished page changes"
          : `${drafts} unpublished ${drafts === 1 ? "change" : "changes"} shown`}
        . Hidden FAQs, unpublished testimonials and scheduled banners are shown
        too. Visitors don&apos;t see this.
      </div>
      {page === "home" && (
        <HomeView
          content={content}
          faqs={(faqs ?? []) as Faq[]}
          testimonials={(testimonials ?? []) as Testimonial[]}
          banners={(banners ?? []) as Banner[]}
          featured={await getFeaturedProperties(6)}
          recent={await getRecentProperties(6)}
          locations={await getLocations()}
          types={await getPropertyTypes()}
        />
      )}
      {page === "about" && <AboutView content={content} />}
      {page === "faq" && <FaqView faqs={(faqs ?? []) as Faq[]} />}
      {(page === "terms" || page === "privacy" || page === "disclaimer") && (
        <LegalPage content={content.legal[page]} path={`/${page}`} />
      )}
    </>
  );
}
