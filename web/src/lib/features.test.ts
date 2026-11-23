import { describe, expect, it } from "vitest";

import { features } from "@/lib/features";

describe("feature switches", () => {
  it("bookings need customer accounts (booking requests are made signed in)", () => {
    expect(!features.bookings || features.customerAccounts).toBe(true);
  });
});
