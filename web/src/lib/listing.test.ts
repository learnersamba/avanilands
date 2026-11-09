import { describe, expect, it } from "vitest";

import {
  emptyFilters,
  hasFilters,
  listingHref,
  parseListingParams,
  toQueryString,
  toSearchArgs,
  withChanges,
} from "@/lib/listing";

const lookups = {
  types: [
    { id: 1, seo_slug: "plots" },
    { id: 4, seo_slug: "farm-land" },
  ],
  locations: [
    { id: "loc-vsp", slug: "visakhapatnam" },
    { id: "loc-akp", slug: "anakapalli" },
  ],
};

describe("reading the address", () => {
  it("returns defaults for an empty address", () => {
    expect(parseListingParams({})).toEqual(emptyFilters);
  });

  it("reads every filter", () => {
    const filters = parseListingParams(
      new URLSearchParams(
        "q=beach&type=plots,farm-land&city=anakapalli&min=2500000&max=5000000&area_min=1&area_max=3&unit=acre" +
          "&road=30&facing=east,north&avail=sold&amenity=1,3&approved=1&sort=price_asc&page=2",
      ),
    );
    expect(filters).toEqual({
      q: "beach",
      types: ["plots", "farm-land"],
      cities: ["anakapalli"],
      min: 2500000,
      max: 5000000,
      areaMin: 1,
      areaMax: 3,
      unit: "acre",
      road: 30,
      facings: ["east", "north"],
      availability: ["sold"],
      amenities: [1, 3],
      approved: true,
      sort: "price_asc",
      page: 2,
    });
  });

  it("accepts repeated keys from a plain form submit", () => {
    const filters = parseListingParams(new URLSearchParams("type=plots&type=farm-land&city=anakapalli"));
    expect(filters.types).toEqual(["plots", "farm-land"]);
  });

  it("accepts Next.js searchParams objects", () => {
    expect(parseListingParams({ type: ["plots", "farm-land"], page: "3" })).toMatchObject({
      types: ["plots", "farm-land"],
      page: 3,
    });
  });

  it("reads the home page budget", () => {
    expect(parseListingParams({ budget: "2500000-5000000" })).toMatchObject({ min: 2500000, max: 5000000 });
    expect(parseListingParams({ budget: "10000000-" })).toMatchObject({ min: 10000000, max: null });
    expect(parseListingParams({ budget: "0-2500000" })).toMatchObject({ min: null, max: 2500000 });
  });

  it("drops junk instead of failing", () => {
    const filters = parseListingParams({
      type: "Plots!,<script>",
      min: "abc",
      max: "-5",
      unit: "furlong",
      facing: "up",
      avail: "free",
      amenity: "x,0,2",
      sort: "random",
      page: "-4",
      approved: "yes",
    });
    expect(filters).toEqual({ ...emptyFilters, amenities: [2] });
  });

  it("swaps a reversed range", () => {
    expect(parseListingParams({ min: "900", max: "100" })).toMatchObject({ min: 100, max: 900 });
  });

  it("caps very long input", () => {
    expect(parseListingParams({ q: "x".repeat(500) }).q).toHaveLength(100);
    expect(parseListingParams({ page: "999999" }).page).toBe(1000);
  });
});

describe("writing the address", () => {
  it("round-trips", () => {
    const query = "q=beach&type=plots,farm-land&city=anakapalli&min=2500000&unit=acre&area_min=1&facing=east&sort=price_asc&page=2";
    const filters = parseListingParams(new URLSearchParams(query));
    expect(parseListingParams(new URLSearchParams(toQueryString(filters)))).toEqual(filters);
  });

  it("leaves out defaults", () => {
    expect(listingHref(emptyFilters)).toBe("/land");
    expect(toQueryString({ ...emptyFilters, areaMin: 200 })).toBe("area_min=200");
  });

  it("canonical links can ignore sort and page", () => {
    const filters = { ...emptyFilters, cities: ["anakapalli"], sort: "price_desc" as const, page: 3 };
    expect(listingHref(filters, { sort: false, page: false })).toBe("/land?city=anakapalli");
  });

  it("changing a filter goes back to page 1", () => {
    expect(withChanges({ ...emptyFilters, page: 5 }, { approved: true }).page).toBe(1);
  });

  it("sort and page alone are not filters", () => {
    expect(hasFilters({ ...emptyFilters, sort: "area_desc", page: 4 })).toBe(false);
    expect(hasFilters({ ...emptyFilters, road: 30 })).toBe(true);
  });
});

describe("database search arguments", () => {
  it("maps slugs to ids and areas to square feet", () => {
    const args = toSearchArgs(
      parseListingParams({ type: "farm-land", city: "anakapalli", area_min: "25", area_max: "50", unit: "cent" }),
      lookups,
    );
    expect(args.p_type_ids).toEqual([4]);
    expect(args.p_location_ids).toEqual(["loc-akp"]);
    expect(args.p_area_min_sqft).toBe(10890);
    expect(args.p_area_max_sqft).toBe(21780);
    expect(args.p_page_size).toBe(12);
  });

  it("an unknown place matches nothing rather than everything", () => {
    const args = toSearchArgs(parseListingParams({ city: "atlantis" }), lookups);
    expect(args.p_location_ids).toEqual(["00000000-0000-0000-0000-000000000000"]);
  });

  it("no filters means no restrictions", () => {
    expect(toSearchArgs(emptyFilters, lookups)).toMatchObject({
      p_q: null,
      p_type_ids: null,
      p_location_ids: null,
      p_availability: null,
      p_approved_only: false,
      p_sort: "newest",
      p_page: 1,
    });
  });
});
