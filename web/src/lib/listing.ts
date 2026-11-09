/**
 * The /land page keeps every filter in the address so results can be
 * shared, bookmarked and indexed (decision 49):
 *
 *   /land?q=beach&type=plots,farm-land&city=visakhapatnam&min=2500000&max=5000000
 *        &area_min=200&area_max=500&unit=sq_yd&road=30&facing=east,north
 *        &avail=sold&amenity=1,3&approved=1&sort=price_asc&page=2
 *
 * Lists may also arrive as repeated keys (a plain form submit without
 * JavaScript sends type=a&type=b); both forms are accepted. The home page
 * search sends `budget=min-max`, which is read as min/max.
 * This file has no server or browser code so it can be unit-tested.
 */

import type { AreaUnit } from "@/lib/format";

export const sorts = {
  newest: "Newest first",
  featured: "Recommended",
  price_asc: "Price: low to high",
  price_desc: "Price: high to low",
  area_asc: "Area: small to large",
  area_desc: "Area: large to small",
} as const;
export type Sort = keyof typeof sorts;

export const facings = [
  "north",
  "south",
  "east",
  "west",
  "north_east",
  "north_west",
  "south_east",
  "south_west",
] as const;
export type Facing = (typeof facings)[number];

export const availabilities = ["available", "reserved", "sold"] as const;
export type AvailabilityFilter = (typeof availabilities)[number];

export const areaUnits: Record<AreaUnit, number> = {
  sq_ft: 1,
  sq_yd: 9,
  sq_m: 10.7639,
  cent: 435.6,
  gunta: 1089,
  acre: 43560,
};

export const PAGE_SIZE = 12;

export type ListingFilters = {
  q: string;
  types: string[]; // property type seo slugs, e.g. "plots"
  cities: string[]; // location slugs
  min: number | null; // rupees
  max: number | null;
  areaMin: number | null; // in `unit`
  areaMax: number | null;
  unit: AreaUnit;
  road: number | null; // minimum road width, ft
  facings: Facing[];
  availability: AvailabilityFilter[]; // empty = available + reserved
  amenities: number[];
  approved: boolean;
  sort: Sort;
  page: number;
};

export const emptyFilters: ListingFilters = {
  q: "",
  types: [],
  cities: [],
  min: null,
  max: null,
  areaMin: null,
  areaMax: null,
  unit: "sq_yd",
  road: null,
  facings: [],
  availability: [],
  amenities: [],
  approved: false,
  sort: "newest",
  page: 1,
};

type Params = Record<string, string | string[] | undefined> | URLSearchParams;

function all(params: Params, key: string): string[] {
  const raw = params instanceof URLSearchParams ? params.getAll(key) : [params[key]].flat();
  return raw
    .filter((value): value is string => typeof value === "string")
    .flatMap((value) => value.split(","))
    .map((value) => value.trim())
    .filter(Boolean);
}

function one(params: Params, key: string): string | undefined {
  return all(params, key)[0];
}

const slug = /^[a-z0-9]+(-[a-z0-9]+)*$/;

/** A positive number, or null for anything else (including "0" and "abc"). */
function positive(value: string | undefined, maxValue = 1e12): number | null {
  if (value == null || value === "") return null;
  const number = Number(value.replace(/,/g, ""));
  return Number.isFinite(number) && number > 0 && number <= maxValue ? number : null;
}

function unique<T>(items: T[]): T[] {
  return [...new Set(items)];
}

/** Reads the address into filters. Unknown or malformed values are dropped. */
export function parseListingParams(params: Params): ListingFilters {
  let min = positive(one(params, "min"));
  let max = positive(one(params, "max"));
  const budget = one(params, "budget");
  if (budget && min == null && max == null) {
    const [from, to] = budget.split("-");
    min = positive(from);
    max = positive(to);
  }
  if (min != null && max != null && min > max) [min, max] = [max, min];

  let areaMin = positive(one(params, "area_min"), 1e9);
  let areaMax = positive(one(params, "area_max"), 1e9);
  if (areaMin != null && areaMax != null && areaMin > areaMax) [areaMin, areaMax] = [areaMax, areaMin];

  const unit = one(params, "unit");
  const sort = one(params, "sort");
  const page = Math.floor(Number(one(params, "page")));

  return {
    q: (one(params, "q") ?? "").slice(0, 100),
    types: unique(all(params, "type").filter((value) => slug.test(value))).slice(0, 10),
    cities: unique(all(params, "city").filter((value) => slug.test(value))).slice(0, 20),
    min,
    max,
    areaMin,
    areaMax,
    unit: unit && unit in areaUnits ? (unit as AreaUnit) : "sq_yd",
    road: positive(one(params, "road"), 1000),
    facings: unique(all(params, "facing").filter((value): value is Facing => (facings as readonly string[]).includes(value))),
    availability: unique(
      all(params, "avail").filter((value): value is AvailabilityFilter =>
        (availabilities as readonly string[]).includes(value),
      ),
    ),
    amenities: unique(all(params, "amenity").map(Number).filter((id) => Number.isInteger(id) && id > 0)).slice(0, 20),
    approved: one(params, "approved") === "1",
    sort: sort && sort in sorts ? (sort as Sort) : "newest",
    page: Number.isFinite(page) && page > 1 ? Math.min(page, 1000) : 1,
  };
}

/** The canonical query string (stable order, comma lists, defaults left out). */
export function toQueryString(filters: ListingFilters, options: { page?: boolean; sort?: boolean } = {}): string {
  const { page = true, sort = true } = options;
  const out = new URLSearchParams();
  if (filters.q) out.set("q", filters.q);
  if (filters.types.length) out.set("type", filters.types.join(","));
  if (filters.cities.length) out.set("city", filters.cities.join(","));
  if (filters.min != null) out.set("min", String(filters.min));
  if (filters.max != null) out.set("max", String(filters.max));
  if (filters.areaMin != null) out.set("area_min", String(filters.areaMin));
  if (filters.areaMax != null) out.set("area_max", String(filters.areaMax));
  if ((filters.areaMin != null || filters.areaMax != null) && filters.unit !== "sq_yd") out.set("unit", filters.unit);
  if (filters.road != null) out.set("road", String(filters.road));
  if (filters.facings.length) out.set("facing", filters.facings.join(","));
  if (filters.availability.length) out.set("avail", filters.availability.join(","));
  if (filters.amenities.length) out.set("amenity", filters.amenities.join(","));
  if (filters.approved) out.set("approved", "1");
  if (sort && filters.sort !== "newest") out.set("sort", filters.sort);
  if (page && filters.page > 1) out.set("page", String(filters.page));
  return out.toString().replace(/%2C/g, ",");
}

export function listingHref(filters: ListingFilters, options?: { page?: boolean; sort?: boolean }): string {
  const query = toQueryString(filters, options);
  return query ? `/land?${query}` : "/land";
}

/** True when anything narrows the results (sort and page don't count). */
export function hasFilters(filters: ListingFilters): boolean {
  return toQueryString({ ...filters, sort: "newest", page: 1 }) !== "";
}

/** A changed copy; any filter change goes back to page 1. */
export function withChanges(filters: ListingFilters, changes: Partial<ListingFilters>): ListingFilters {
  return { ...filters, page: 1, ...changes };
}

export type Lookups = {
  types: { id: number; seo_slug: string }[];
  locations: { id: string; slug: string }[];
};

export type SearchArgs = {
  p_q: string | null;
  p_type_ids: number[] | null;
  p_location_ids: string[] | null;
  p_price_min: number | null;
  p_price_max: number | null;
  p_area_min_sqft: number | null;
  p_area_max_sqft: number | null;
  p_road_width_min: number | null;
  p_facings: Facing[] | null;
  p_availability: AvailabilityFilter[] | null;
  p_amenity_ids: number[] | null;
  p_approved_only: boolean;
  p_sort: Sort;
  p_page: number;
  p_page_size: number;
};

/**
 * Arguments for the database's search_properties. Slugs that match no type
 * or place are kept as "matches nothing" (an impossible id) rather than
 * silently widening the search.
 */
export function toSearchArgs(filters: ListingFilters, lookups: Lookups, pageSize = PAGE_SIZE): SearchArgs {
  const typeIds = filters.types.map((s) => lookups.types.find((t) => t.seo_slug === s)?.id ?? -1);
  const locationIds = filters.cities.map(
    (s) => lookups.locations.find((l) => l.slug === s)?.id ?? "00000000-0000-0000-0000-000000000000",
  );
  const factor = areaUnits[filters.unit];
  return {
    p_q: filters.q || null,
    p_type_ids: typeIds.length ? typeIds : null,
    p_location_ids: locationIds.length ? locationIds : null,
    p_price_min: filters.min,
    p_price_max: filters.max,
    p_area_min_sqft: filters.areaMin == null ? null : Math.floor(filters.areaMin * factor),
    p_area_max_sqft: filters.areaMax == null ? null : Math.ceil(filters.areaMax * factor),
    p_road_width_min: filters.road,
    p_facings: filters.facings.length ? filters.facings : null,
    p_availability: filters.availability.length ? filters.availability : null,
    p_amenity_ids: filters.amenities.length ? filters.amenities : null,
    p_approved_only: filters.approved,
    p_sort: filters.sort,
    p_page: filters.page,
    p_page_size: pageSize,
  };
}
