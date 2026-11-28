import { Search } from "lucide-react";

import type { LocationSummary, PropertyType } from "@/lib/data";

/** Budget choices → `max` (and `min`) in rupees for /land. */
export const budgets = [
  { value: "0-2500000", label: "Up to ₹25 L" },
  { value: "2500000-5000000", label: "₹25 L – ₹50 L" },
  { value: "5000000-10000000", label: "₹50 L – ₹1 Cr" },
  { value: "10000000-", label: "Above ₹1 Cr" },
];

/**
 * A plain GET form to /land, so it works before JavaScript loads.
 * Field names match the listing's address: ?city=…&type=…&budget=…
 */
export function HeroSearch({ locations, types }: { locations: LocationSummary[]; types: PropertyType[] }) {
  const select =
    "w-full appearance-none rounded-md border-0 bg-transparent px-0 pb-1 pt-0 text-base text-ink focus:outline-none";
  const field = "block rounded-md px-4 py-2.5 focus-within:bg-paper";
  const label = "block text-xs font-medium text-muted";
  return (
    <form
      action="/land"
      method="get"
      role="search"
      aria-label="Find land"
      className="grid gap-1 rounded-lg bg-white p-2 text-ink shadow-[0_24px_50px_-24px_rgba(0,0,0,0.55)] sm:grid-cols-2 lg:grid-cols-[1fr_1fr_1fr_auto] lg:divide-x lg:divide-line"
    >
      <label className={field}>
        <span className={label}>Location</span>
        <select name="city" defaultValue="" className={select}>
          <option value="">Any location</option>
          {locations.map((location) => (
            <option key={location.id} value={location.slug}>
              {location.city}
            </option>
          ))}
        </select>
      </label>
      <label className={field}>
        <span className={label}>Property type</span>
        <select name="type" defaultValue="" className={select}>
          <option value="">Any type</option>
          {types.map((type) => (
            <option key={type.id} value={type.seo_slug}>
              {type.name}
            </option>
          ))}
        </select>
      </label>
      <label className={field}>
        <span className={label}>Budget</span>
        <select name="budget" defaultValue="" className={select}>
          <option value="">Any budget</option>
          {budgets.map((budget) => (
            <option key={budget.value} value={budget.value}>
              {budget.label}
            </option>
          ))}
        </select>
      </label>
      <button
        type="submit"
        className="inline-flex items-center justify-center gap-2 rounded-md bg-forest-dark px-7 py-3.5 text-base font-medium text-white hover:bg-forest sm:col-span-2 lg:col-span-1 lg:!border-l-0"
      >
        <Search className="h-4 w-4" aria-hidden /> Search land
      </button>
    </form>
  );
}
