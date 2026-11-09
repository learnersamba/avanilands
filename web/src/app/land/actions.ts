"use server";

import { getLocations, getPropertyTypes, searchListing } from "@/lib/data";
import { parseListingParams, toSearchArgs } from "@/lib/listing";

/** How many results a filter combination gives (for "Show N results" on phones). */
export async function countListing(query: string): Promise<number> {
  const filters = parseListingParams(new URLSearchParams(query.slice(0, 2000)));
  const [types, locations] = await Promise.all([getPropertyTypes(), getLocations()]);
  const result = await searchListing(toSearchArgs({ ...filters, page: 1, sort: "newest" }, { types, locations }, 1));
  return result.total;
}
