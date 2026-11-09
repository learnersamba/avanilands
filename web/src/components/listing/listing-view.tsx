import { SearchX } from "lucide-react";

import { ActiveFilters } from "@/components/listing/active-filters";
import { type FilterOptions, filterChips } from "@/components/listing/filter-labels";
import { FilterSidebar, MobileFilters, SortSelect } from "@/components/listing/listing-controls";
import { Pagination } from "@/components/listing/pagination";
import { PropertyGrid } from "@/components/property-card";
import { ButtonLink, Container } from "@/components/ui";
import { getAmenities, getLocations, getPropertyTypes, searchListing } from "@/lib/data";
import { emptyFilters, type ListingFilters, listingHref, PAGE_SIZE, toSearchArgs } from "@/lib/listing";

export async function getFilterOptions(): Promise<FilterOptions> {
  const [types, locations, amenities] = await Promise.all([getPropertyTypes(), getLocations(), getAmenities()]);
  return { types, locations, amenities };
}

/** Filters, result count, sort, results and pages for a set of filters. */
export async function ListingView({ filters }: { filters: ListingFilters }) {
  const options = await getFilterOptions();
  const result = await searchListing(toSearchArgs(filters, options));
  const chips = filterChips(filters, options);
  const pages = Math.ceil(result.total / PAGE_SIZE);
  const first = (filters.page - 1) * PAGE_SIZE + 1;
  const last = Math.min(filters.page * PAGE_SIZE, result.total);

  return (
    <Container className="grid gap-8 py-10 lg:grid-cols-[290px_1fr]">
      <aside aria-label="Filters" className="hidden lg:block">
        <FilterSidebar filters={filters} options={options} />
      </aside>

      <div>
        <h2 className="sr-only">Results</h2>
        <div className="mb-5 flex flex-wrap items-center justify-between gap-3">
          <p className="text-sm text-muted" role="status">
            {result.total === 0 ? (
              "No properties match"
            ) : (
              <>
                {pages > 1 ? `${first}–${last} of ` : ""}
                <span className="font-semibold text-ink">{result.total}</span>{" "}
                {result.total === 1 ? "property" : "properties"}
              </>
            )}
          </p>
          <div className="flex items-center gap-3">
            <MobileFilters filters={filters} options={options} total={result.total} activeCount={chips.length} />
            <SortSelect filters={filters} />
          </div>
        </div>

        <ActiveFilters filters={filters} options={options} />

        {result.items.length > 0 ? (
          <>
            <PropertyGrid properties={result.items} priorityCount={1} />
            <Pagination filters={filters} total={result.total} />
          </>
        ) : (
          <EmptyResults filters={filters} pageTooFar={result.total > 0} />
        )}
      </div>
    </Container>
  );
}

function EmptyResults({ filters, pageTooFar }: { filters: ListingFilters; pageTooFar: boolean }) {
  return (
    <div className="rounded-2xl border border-dashed border-line bg-white px-6 py-16 text-center">
      <SearchX className="mx-auto h-10 w-10 text-sand" aria-hidden />
      <h3 className="mt-4 font-serif text-2xl text-forest">
        {pageTooFar ? "There are no more results" : "No land matches these filters"}
      </h3>
      <p className="mx-auto mt-2 max-w-md text-ink/75">
        {pageTooFar
          ? "This page is past the end of the results."
          : "Try removing a filter, or tell us what you're looking for — new land is added often and not everything is listed yet."}
      </p>
      <div className="mt-6 flex flex-wrap justify-center gap-3">
        {pageTooFar ? (
          <ButtonLink href={listingHref({ ...filters, page: 1 })}>Go to page 1</ButtonLink>
        ) : (
          <ButtonLink href={listingHref({ ...emptyFilters, sort: filters.sort })}>Clear all filters</ButtonLink>
        )}
        <ButtonLink href="/contact" variant="outline">
          Tell us what you need
        </ButtonLink>
      </div>
    </div>
  );
}

export function ListingSkeleton() {
  return (
    <Container className="grid gap-8 py-10 lg:grid-cols-[290px_1fr]" aria-busy="true">
      <div className="hidden h-[600px] animate-pulse rounded-2xl bg-white lg:block" />
      <div>
        <div className="mb-6 h-6 w-40 animate-pulse rounded bg-line" />
        <div className="grid gap-6 sm:grid-cols-2 lg:grid-cols-3">
          {Array.from({ length: 6 }, (_, index) => (
            <div key={index} className="h-[420px] animate-pulse rounded-2xl bg-white ring-1 ring-line" />
          ))}
        </div>
      </div>
    </Container>
  );
}
