import type { Amenity, LocationSummary, PropertyType } from "@/lib/data";
import { facingLabels, formatNumber, formatRupeesShort, unitLabel } from "@/lib/format";
import { type ListingFilters, withChanges } from "@/lib/listing";

export type FilterOptions = {
  types: PropertyType[];
  locations: LocationSummary[];
  amenities: Amenity[];
};

export type Chip = { label: string; without: ListingFilters };

/** One removable chip per active filter, each with the filters it leaves. */
export function filterChips(filters: ListingFilters, options: FilterOptions): Chip[] {
  const chips: Chip[] = [];
  if (filters.q) chips.push({ label: `“${filters.q}”`, without: withChanges(filters, { q: "" }) });
  for (const slug of filters.types) {
    const name = options.types.find((t) => t.seo_slug === slug)?.name ?? slug;
    chips.push({ label: name, without: withChanges(filters, { types: filters.types.filter((t) => t !== slug) }) });
  }
  for (const slug of filters.cities) {
    const name = options.locations.find((l) => l.slug === slug)?.city ?? slug;
    chips.push({ label: name, without: withChanges(filters, { cities: filters.cities.filter((c) => c !== slug) }) });
  }
  if (filters.min != null || filters.max != null) {
    const label =
      filters.min != null && filters.max != null
        ? `${formatRupeesShort(filters.min)} – ${formatRupeesShort(filters.max)}`
        : filters.min != null
          ? `From ${formatRupeesShort(filters.min)}`
          : `Up to ${formatRupeesShort(filters.max!)}`;
    chips.push({ label, without: withChanges(filters, { min: null, max: null }) });
  }
  if (filters.areaMin != null || filters.areaMax != null) {
    const unit = unitLabel(filters.unit);
    const label =
      filters.areaMin != null && filters.areaMax != null
        ? `${formatNumber(filters.areaMin)}–${formatNumber(filters.areaMax)} ${unit}`
        : filters.areaMin != null
          ? `${formatNumber(filters.areaMin)}+ ${unit}`
          : `Up to ${formatNumber(filters.areaMax!)} ${unit}`;
    chips.push({ label, without: withChanges(filters, { areaMin: null, areaMax: null }) });
  }
  if (filters.road != null) {
    chips.push({ label: `Road ${formatNumber(filters.road)} ft+`, without: withChanges(filters, { road: null }) });
  }
  for (const facing of filters.facings) {
    chips.push({
      label: `${facingLabels[facing]} facing`,
      without: withChanges(filters, { facings: filters.facings.filter((f) => f !== facing) }),
    });
  }
  for (const availability of filters.availability) {
    chips.push({
      label: availability[0].toUpperCase() + availability.slice(1),
      without: withChanges(filters, { availability: filters.availability.filter((a) => a !== availability) }),
    });
  }
  for (const id of filters.amenities) {
    const name = options.amenities.find((a) => a.id === id)?.name ?? `Amenity ${id}`;
    chips.push({ label: name, without: withChanges(filters, { amenities: filters.amenities.filter((a) => a !== id) }) });
  }
  if (filters.approved) chips.push({ label: "Approved only", without: withChanges(filters, { approved: false }) });
  return chips;
}

/** "Plots for sale in Anakapalli" style heading for the current filters. */
export function listingTitle(filters: ListingFilters, options: FilterOptions): string {
  const type =
    filters.types.length === 1 ? options.types.find((t) => t.seo_slug === filters.types[0])?.name : undefined;
  const city =
    filters.cities.length === 1 ? options.locations.find((l) => l.slug === filters.cities[0])?.city : undefined;
  const what = type ? `${type.replace(/ Plot$/, " plots").replace(/ Land$/, " land")}` : "Land";
  return city ? `${what} for sale in ${city}` : `${what} for sale`;
}
