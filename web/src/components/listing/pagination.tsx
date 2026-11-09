import { ChevronLeft, ChevronRight } from "lucide-react";
import Link from "next/link";

import { type ListingFilters, listingHref, PAGE_SIZE } from "@/lib/listing";

/** Page links: previous, a window of numbers, next. */
export function Pagination({ filters, total }: { filters: ListingFilters; total: number }) {
  const pages = Math.ceil(total / PAGE_SIZE);
  if (pages <= 1) return null;
  const current = Math.min(filters.page, pages);
  const window = new Set([1, pages, current - 1, current, current + 1].filter((p) => p >= 1 && p <= pages));
  const numbers = [...window].sort((a, b) => a - b);
  const href = (page: number) => listingHref({ ...filters, page });
  const box = "inline-flex h-10 min-w-10 items-center justify-center rounded-lg px-3 text-sm font-medium";

  return (
    <nav aria-label="Pages" className="mt-10 flex flex-wrap items-center justify-center gap-2">
      {current > 1 ? (
        <Link href={href(current - 1)} rel="prev" className={`${box} border border-line bg-white hover:border-forest`}>
          <ChevronLeft className="h-4 w-4" aria-hidden /> Previous
        </Link>
      ) : null}
      {numbers.map((page, index) => (
        <span key={page} className="flex items-center gap-2">
          {index > 0 && page - numbers[index - 1] > 1 && <span aria-hidden className="text-muted">…</span>}
          {page === current ? (
            <span aria-current="page" className={`${box} bg-forest text-white`}>
              {page}
            </span>
          ) : (
            <Link href={href(page)} className={`${box} border border-line bg-white hover:border-forest`} aria-label={`Page ${page}`}>
              {page}
            </Link>
          )}
        </span>
      ))}
      {current < pages ? (
        <Link href={href(current + 1)} rel="next" className={`${box} border border-line bg-white hover:border-forest`}>
          Next <ChevronRight className="h-4 w-4" aria-hidden />
        </Link>
      ) : null}
    </nav>
  );
}
