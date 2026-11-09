import { X } from "lucide-react";
import Link from "next/link";

import { type FilterOptions, filterChips } from "@/components/listing/filter-labels";
import { emptyFilters, type ListingFilters, listingHref } from "@/lib/listing";

/** Removable chips for each active filter. Plain links, so they work without JavaScript. */
export function ActiveFilters({ filters, options }: { filters: ListingFilters; options: FilterOptions }) {
  const chips = filterChips(filters, options);
  if (chips.length === 0) return null;
  return (
    <ul className="mb-6 flex flex-wrap items-center gap-2" aria-label="Active filters">
      {chips.map((chip) => (
        <li key={chip.label}>
          <Link
            href={listingHref(chip.without)}
            scroll={false}
            className="inline-flex items-center gap-1.5 rounded-full border border-forest/20 bg-white px-3 py-1.5 text-sm text-forest hover:border-forest"
            aria-label={`Remove filter: ${chip.label}`}
          >
            {chip.label}
            <X className="h-3.5 w-3.5" aria-hidden />
          </Link>
        </li>
      ))}
      <li>
        <Link
          href={listingHref({ ...emptyFilters, sort: filters.sort })}
          scroll={false}
          className="px-2 py-1.5 text-sm font-semibold text-sand-dark hover:text-forest"
        >
          Clear all
        </Link>
      </li>
    </ul>
  );
}
