import type { Metadata } from "next";
import { notFound } from "next/navigation";
import { Suspense } from "react";

import { getFilterOptions, ListingSkeleton, ListingView } from "@/components/listing/listing-view";
import { PageHero } from "@/components/page-hero";
import { getLandingCombos, searchListing } from "@/lib/data";
import { emptyFilters, type ListingFilters, toSearchArgs } from "@/lib/listing";

/**
 * Landing pages for search engines and sharing:
 *   /land-for-sale/<city>            every type in a place
 *   /<type seo slug>-for-sale/<city> e.g. /plots-for-sale/visakhapatnam
 * Anything else under /<something>/<something> is "not found".
 */

const ALL = "land";

export async function generateStaticParams() {
  const combos = await getLandingCombos();
  const cities = [...new Set(combos.map((c) => c.location_slug))];
  return [
    ...cities.map((city) => ({ landing: `${ALL}-for-sale`, city })),
    ...combos.map((c) => ({ landing: `${c.type_seo_slug}-for-sale`, city: c.location_slug })),
  ];
}

type Landing = {
  filters: ListingFilters;
  title: string;
  intro: string;
  city: string;
};

async function resolveLanding(landing: string, citySlug: string): Promise<Landing | null> {
  const match = /^([a-z0-9-]+)-for-sale$/.exec(landing);
  if (!match) return null;
  const options = await getFilterOptions();
  const location = options.locations.find((l) => l.slug === citySlug);
  const type = match[1] === ALL ? null : options.types.find((t) => t.seo_slug === match[1]);
  if (!location || type === undefined) return null;

  const what = type ? type.name.replace(/ Plot$/, " plots").replace(/ Land$/, " land") : "Land";
  return {
    filters: { ...emptyFilters, cities: [location.slug], types: type ? [type.seo_slug] : [] },
    title: `${what} for sale in ${location.city}`,
    intro:
      location.description ??
      `${what} in ${location.city}, ${location.district} district — owned and verified by us, sold directly with no brokers.`,
    city: location.city,
  };
}

export async function generateMetadata(props: PageProps<"/[landing]/[city]">): Promise<Metadata> {
  const { landing, city } = await props.params;
  const page = await resolveLanding(landing, city);
  if (!page) return { title: "Page not found", robots: { index: false } };
  const options = await getFilterOptions();
  const { total } = await searchListing(toSearchArgs(page.filters, options, 1));
  return {
    title: page.title,
    description: `${total} ${total === 1 ? "property" : "properties"}: ${page.title.toLowerCase()}. Approved, verified and sold directly — no brokers.`,
    alternates: { canonical: `/${landing}/${city}` },
    // Keep empty landing pages out of search results until land is listed there.
    robots: total === 0 ? { index: false, follow: true } : undefined,
  };
}

export default function LandingPage(props: PageProps<"/[landing]/[city]">) {
  return (
    <Suspense fallback={<ListingSkeleton />}>
      <LandingContent params={props.params} />
    </Suspense>
  );
}

async function LandingContent({ params }: { params: Promise<{ landing: string; city: string }> }) {
  const { landing, city } = await params;
  const page = await resolveLanding(landing, city);
  if (!page) notFound();
  return (
    <>
      <PageHero
        title={page.title}
        subtitle={page.intro}
        crumbs={[
          { href: "/land", label: "Land for sale" },
          { href: `/land-for-sale/${city}`, label: page.city },
        ]}
      />
      <ListingView filters={page.filters} />
    </>
  );
}
