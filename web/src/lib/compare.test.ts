import { describe, expect, it } from "vitest";

import {
  allSame,
  bestIndexes,
  compareHref,
  distanceKm,
  formatDistance,
  parseCodes,
  pricePerSqft,
} from "@/lib/compare";

describe("reading the comparison link", () => {
  it("keeps up to 3 valid codes, once each, in order", () => {
    expect(parseCodes("al-0001, AL-0003,junk,AL-0001,AL-0004,AL-0005")).toEqual(
      ["AL-0001", "AL-0003", "AL-0004"],
    );
    expect(parseCodes(["AL-0002", "AL-0009"])).toEqual(["AL-0002", "AL-0009"]);
    expect(parseCodes(undefined)).toEqual([]);
    expect(parseCodes("'; drop table--")).toEqual([]);
    expect(compareHref(["AL-0001", "AL-0003"])).toBe(
      "/compare?codes=AL-0001,AL-0003",
    );
  });
});

describe("comparing", () => {
  it("price per sq ft makes different units comparable", () => {
    // 25 cents = 10,890 sq ft for ₹45 L; 200 sq yd = 1,800 sq ft for ₹36 L
    expect(
      pricePerSqft({
        price_type: "total",
        price: 4_500_000,
        area_sqft: 10_890,
      }),
    ).toBeCloseTo(413.2, 1);
    expect(
      pricePerSqft({ price_type: "total", price: 3_600_000, area_sqft: 1_800 }),
    ).toBe(2000);
    expect(
      pricePerSqft({ price_type: "on_request", price: null, area_sqft: 1_800 }),
    ).toBeNull();
    expect(
      pricePerSqft({ price_type: "total", price: 100, area_sqft: 0 }),
    ).toBeNull();
  });

  it("marks the best value only when there is a real difference", () => {
    expect([...bestIndexes([413, 2000, null], "min")]).toEqual([0]);
    expect([...bestIndexes([30, 40, 40], "max")]).toEqual([1, 2]);
    expect(bestIndexes([30, 30], "max").size).toBe(0);
    expect(bestIndexes([30, null, null], "max").size).toBe(0);
    expect(allSame(["East", "East"])).toBe(true);
    expect(allSame(["East", "West"])).toBe(false);
  });

  it("distance between properties", () => {
    // Visakhapatnam to Anakapalli is roughly 30 km in a straight line.
    const km = distanceKm(
      { latitude: 17.6868, longitude: 83.2185 },
      { latitude: 17.6913, longitude: 83.0037 },
    )!;
    expect(km).toBeGreaterThan(20);
    expect(km).toBeLessThan(25);
    expect(
      distanceKm(
        { latitude: null, longitude: null },
        { latitude: 1, longitude: 2 },
      ),
    ).toBeNull();
    expect(formatDistance(0.4)).toBe("under 1 km");
    expect(formatDistance(3.04)).toBe("about 3 km");
    expect(formatDistance(3.46)).toBe("about 3.5 km");
    expect(formatDistance(22.7)).toBe("about 23 km");
  });
});
