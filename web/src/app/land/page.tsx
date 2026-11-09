import type { Metadata } from "next";
import { Suspense } from "react";

import { listingTitle } from "@/components/listing/filter-labels";
import { getFilterOptions, ListingSkeleton, ListingView } from "@/components/listing/listing-view";
import { PageHero } from "@/components/page-hero";
import { hasFilters, listingHref, parseListingParams } from "@/lib/listing";

export async function generateMetadata(props: PageProps<"/land">): Promise<Metadata> {
  const filters = parseListingParams(await props.searchParams);
  const options = await getFilterOptions();
  const title = listingTitle(filters, options);
  const page = filters.page > 1 ? ` — page ${filters.page}` : "";
  return {
    title: `${title}${page}`,
    description: "Approved plots, agricultural land and farm land sold directly by us. Search by place, budget and size.",
    // One address per result set; sorting doesn't make a new page.
    alternates: { canonical: listingHref(filters, { sort: false }) },
    // Filter combinations are endless: Google indexes the main list and the
    // landing pages (/plots-for-sale/<city> …) and follows links from the rest.
    robots: hasFilters(filters) || filters.sort !== "newest" ? { index: false, follow: true } : undefined,
  };
}

const subtitle = "Approved plots, farm land and agricultural land — every property owned and verified by us.";
const crumbs = [{ href: "/land", label: "Land for sale" }];

export default function LandPage(props: PageProps<"/land">) {
  return (
    <Suspense
      fallback={
        <>
          <PageHero title="Land for sale" subtitle={subtitle} crumbs={crumbs} />
          <ListingSkeleton />
        </>
      }
    >
      <Results searchParams={props.searchParams} />
    </Suspense>
  );
}

async function Results({ searchParams }: { searchParams: PageProps<"/land">["searchParams"] }) {
  const filters = parseListingParams(await searchParams);
  const options = await getFilterOptions();
  return (
    <>
      <PageHero title={listingTitle(filters, options)} subtitle={subtitle} crumbs={crumbs} />
      <ListingView filters={filters} />
    </>
  );
}
