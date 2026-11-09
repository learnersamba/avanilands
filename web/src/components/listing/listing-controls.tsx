"use client";

import { Loader2, SlidersHorizontal, X } from "lucide-react";
import { useRouter } from "next/navigation";
import { useEffect, useRef, useState, useTransition } from "react";

import { countListing } from "@/app/land/actions";
import { FilterForm } from "@/components/listing/filter-form";
import type { FilterOptions } from "@/components/listing/filter-labels";
import { type ListingFilters, listingHref, type Sort, sorts, toQueryString } from "@/lib/listing";

/** Desktop: filters apply as soon as they change. */
export function FilterSidebar({ filters, options }: { filters: ListingFilters; options: FilterOptions }) {
  const router = useRouter();
  const [pending, startTransition] = useTransition();
  const current = toQueryString(filters);
  return (
    <div className="rounded-2xl border border-line bg-white p-5">
      <div className="mb-5 flex items-center justify-between">
        <h2 className="font-serif text-xl text-forest">Filters</h2>
        {pending && (
          <span className="flex items-center gap-1.5 text-xs text-muted" role="status">
            <Loader2 className="h-3.5 w-3.5 animate-spin" aria-hidden /> Updating…
          </span>
        )}
      </div>
      <FilterForm
        // Re-create the form when the address changes (e.g. a chip was removed).
        key={current}
        filters={filters}
        options={options}
        idPrefix="side"
        onChange={(next) => {
          if (toQueryString(next) === current) return;
          startTransition(() => router.push(listingHref(next), { scroll: false }));
        }}
      />
    </div>
  );
}

/** Phones: a full-screen sheet with a live "Show N results" button. */
export function MobileFilters({
  filters,
  options,
  total,
  activeCount,
}: {
  filters: ListingFilters;
  options: FilterOptions;
  total: number;
  activeCount: number;
}) {
  const router = useRouter();
  const dialogRef = useRef<HTMLDialogElement>(null);
  const [draft, setDraft] = useState(filters);
  // The sheet's form is only built once it is first opened (keeps the page small).
  const [opened, setOpened] = useState(false);
  const [count, setCount] = useState<number | null>(total);
  const [counting, startCounting] = useTransition();
  const [applying, startApplying] = useTransition();
  const timer = useRef<ReturnType<typeof setTimeout>>(undefined);

  useEffect(() => () => clearTimeout(timer.current), []);

  const open = () => {
    setDraft(filters);
    setCount(total);
    setOpened(true);
    dialogRef.current?.showModal();
  };

  const onDraft = (next: ListingFilters) => {
    setDraft(next);
    clearTimeout(timer.current);
    timer.current = setTimeout(() => {
      startCounting(async () => {
        try {
          setCount(await countListing(toQueryString(next)));
        } catch {
          setCount(null);
        }
      });
    }, 350);
  };

  const apply = () => {
    startApplying(() => router.push(listingHref(draft), { scroll: true }));
    dialogRef.current?.close();
  };

  return (
    <>
      <button
        type="button"
        onClick={open}
        className="inline-flex items-center gap-2 rounded-lg border border-line bg-white px-4 py-2.5 text-sm font-medium lg:hidden"
      >
        <SlidersHorizontal className="h-4 w-4" aria-hidden />
        Filters
        {activeCount > 0 && (
          <span className="rounded-full bg-forest px-2 py-0.5 text-xs font-semibold text-white">{activeCount}</span>
        )}
        {applying && <Loader2 className="h-4 w-4 animate-spin" aria-hidden />}
      </button>
      <dialog
        ref={dialogRef}
        aria-label="Filters"
        className="m-0 h-full max-h-none w-full max-w-none bg-paper p-0 backdrop:bg-black/40"
      >
        <div className="flex h-full flex-col">
          <div className="flex items-center justify-between border-b border-line bg-white px-4 py-3">
            <h2 className="font-serif text-xl text-forest">Filters</h2>
            <button
              type="button"
              onClick={() => dialogRef.current?.close()}
              className="inline-flex h-10 w-10 items-center justify-center rounded-lg"
              aria-label="Close filters"
            >
              <X className="h-5 w-5" aria-hidden />
            </button>
          </div>
          <div className="flex-1 overflow-y-auto px-4 py-5">
            {opened && (
              <FilterForm key={toQueryString(filters)} filters={filters} options={options} idPrefix="sheet" onChange={onDraft} />
            )}
          </div>
          <div className="border-t border-line bg-white p-4">
            <button
              type="button"
              onClick={apply}
              disabled={count === 0}
              className="flex w-full items-center justify-center gap-2 rounded-lg bg-forest px-4 py-3.5 font-semibold text-white disabled:opacity-50"
            >
              {counting && <Loader2 className="h-4 w-4 animate-spin" aria-hidden />}
              {count === null ? "Show results" : count === 0 ? "No matching land" : `Show ${count} ${count === 1 ? "result" : "results"}`}
            </button>
          </div>
        </div>
      </dialog>
    </>
  );
}

export function SortSelect({ filters }: { filters: ListingFilters }) {
  const router = useRouter();
  const [, startTransition] = useTransition();
  return (
    <label className="flex items-center gap-2 text-sm">
      <span className="hidden text-muted sm:inline">Sort</span>
      <select
        value={filters.sort}
        onChange={(event) =>
          startTransition(() =>
            router.push(listingHref({ ...filters, sort: event.target.value as Sort, page: 1 }), { scroll: false }),
          )
        }
        aria-label="Sort results"
        className="rounded-lg border border-line bg-white px-3 py-2.5 text-sm"
      >
        {Object.entries(sorts).map(([value, label]) => (
          <option key={value} value={value}>
            {label}
          </option>
        ))}
      </select>
    </label>
  );
}
