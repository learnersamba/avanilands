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
    "w-full appearance-none rounded-lg border border-line bg-white px-4 py-3 text-sm text-ink focus:border-forest focus:outline-none";
  return (
    <form
      action="/land"
      method="get"
      role="search"
      aria-label="Find land"
      className="grid gap-3 rounded-2xl bg-white/95 p-3 shadow-2xl ring-1 ring-black/5 sm:grid-cols-2 lg:grid-cols-[1fr_1fr_1fr_auto]"
    >
      <label className="block">
        <span className="sr-only">Location</span>
        <select name="city" defaultValue="" className={select}>
          <option value="">Any location</option>
          {locations.map((location) => (
            <option key={location.id} value={location.slug}>
              {location.city}
            </option>
          ))}
        </select>
      </label>
      <label className="block">
        <span className="sr-only">Property type</span>
        <select name="type" defaultValue="" className={select}>
          <option value="">Any type</option>
          {types.map((type) => (
            <option key={type.id} value={type.seo_slug}>
              {type.name}
            </option>
          ))}
        </select>
      </label>
      <label className="block">
        <span className="sr-only">Budget</span>
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
        className="inline-flex items-center justify-center gap-2 rounded-lg bg-forest px-6 py-3 text-sm font-semibold text-white hover:bg-forest-dark sm:col-span-2 lg:col-span-1"
      >
        <Search className="h-4 w-4" aria-hidden /> Search land
      </button>
    </form>
  );
}
