import { describe, expect, it } from "vitest";

import {
  availableVisitDates,
  explainVisitError,
  formatSlot,
  formatVisitDate,
  googleCalendarLink,
  siteVisitSchema,
  todayInIndia,
} from "@/lib/site-visit";
import {
  customerSiteVisitEmail,
  salesSiteVisitEmail,
  type SiteVisitEmailData,
} from "@/lib/site-visit-emails";

const settings = {
  visit_days: [1, 2, 3, 4, 5, 6],
  visit_slots: ["10:00", "15:00"],
  visit_closed_dates: [],
  visit_days_ahead: 10,
};

describe("which days can be booked", () => {
  it("uses India's date, not the server's", () => {
    // 20:00 UTC on 9 Nov is already 10 Nov in India.
    expect(todayInIndia(new Date("2026-11-09T20:00:00Z"))).toBe("2026-11-10");
    expect(todayInIndia(new Date("2026-11-09T10:00:00Z"))).toBe("2026-11-09");
  });

  it("starts tomorrow, skips Sundays and stays within the window", () => {
    // 2026-11-09 is a Monday
    const dates = availableVisitDates(settings, "2026-11-09");
    expect(dates[0]).toBe("2026-11-10");
    expect(dates).not.toContain("2026-11-09");
    expect(dates).not.toContain("2026-11-15"); // Sunday
    expect(dates.at(-1)).toBe("2026-11-19");
    expect(dates).toHaveLength(9); // 10 days ahead minus one Sunday
  });

  it("skips holidays and works across months and years", () => {
    expect(
      availableVisitDates(
        { ...settings, visit_closed_dates: ["2026-11-10"] },
        "2026-11-09",
      )[0],
    ).toBe("2026-11-11");
    expect(
      availableVisitDates(
        { ...settings, visit_days: [1, 2, 3, 4, 5, 6, 7] },
        "2026-12-30",
      ).slice(0, 3),
    ).toEqual(["2026-12-31", "2027-01-01", "2027-01-02"]);
  });

  it("formats days and times the Indian way", () => {
    expect(formatVisitDate("2026-11-14")).toBe("Sat, 14 Nov");
    expect(formatVisitDate("2026-11-14", true)).toBe("Sat, 14 Nov 2026");
    expect(formatSlot("10:00")).toBe("10:00 am");
    expect(formatSlot("12:30")).toBe("12:30 pm");
    expect(formatSlot("15:00")).toBe("3:00 pm");
  });
});

describe("booking form rules", () => {
  const valid = {
    name: " Prasad Rao ",
    phone: "+91 94400 12345",
    email: "",
    visitDate: "2026-11-14",
    slot: "15:00",
    visitors: "3",
    message: "",
    propertyId: "10000000-0000-4000-a000-000000000003",
    idempotencyKey: "50000000-0000-4000-a000-000000000001",
  };

  it("cleans valid input", () => {
    expect(siteVisitSchema.parse(valid)).toMatchObject({
      name: "Prasad Rao",
      phone: "9440012345",
      email: null,
      visitors: 3,
      message: null,
    });
  });

  it("explains each problem", () => {
    const result = siteVisitSchema.safeParse({
      ...valid,
      phone: "123",
      visitDate: "",
      slot: "3pm",
      visitors: "0",
    });
    expect(result.error!.issues.map((issue) => issue.path[0])).toEqual(
      expect.arrayContaining(["phone", "visitDate", "slot", "visitors"]),
    );
    expect(
      siteVisitSchema.safeParse({ ...valid, visitors: "25" }).success,
    ).toBe(false);
  });

  it("explains database refusals", () => {
    expect(explainVisitError("closed_day").field).toBe("visitDate");
    expect(explainVisitError("invalid_slot").field).toBe("slot");
    expect(explainVisitError("rate_limited").message).toContain(
      "several visit requests",
    );
    expect(explainVisitError("property_unavailable").message).toContain("sold");
  });

  it("calendar link has the time in India", () => {
    const link = new URL(
      googleCalendarLink({
        date: "2026-11-14",
        slot: "15:00",
        title: "Visit",
        details: "SV-1",
        location: "Anakapalli",
      }),
    );
    expect(link.searchParams.get("dates")).toBe(
      "20261114T150000/20261114T170000",
    );
    expect(link.searchParams.get("ctz")).toBe("Asia/Kolkata");
  });
});

describe("visit emails", () => {
  const data: SiteVisitEmailData = {
    reference: "SV-000004",
    name: "<i>Prasad</i>",
    phone: "9440012345",
    email: "prasad@example.com",
    visitors: 2,
    visitDate: "2026-11-14",
    slot: "15:00",
    message: null,
    property: {
      code: "AL-0003",
      title: "2 Acre Land",
      url: "https://x/land/a",
      place: "Chodavaram",
      mapsUrl: null,
    },
    companyName: "Avanilands",
    companyPhone: "+91 90000 00000",
    adminUrl: "https://admin.x",
  };

  it("sales email says when and how to reach the customer", () => {
    const email = salesSiteVisitEmail(data);
    expect(email.subject).toContain(
      "SV-000004 — AL-0003 — Sat, 14 Nov 3:00 pm",
    );
    expect(email.text).toContain("2 people");
    expect(email.html).toContain("https://wa.me/919440012345");
    expect(email.html).not.toContain("<i>Prasad</i>");
  });

  it("customer emails for each step", () => {
    expect(customerSiteVisitEmail(data, "confirmed").subject).toMatch(
      /^Your site visit is confirmed — SV-000004/,
    );
    expect(customerSiteVisitEmail(data, "reminder").subject).toMatch(
      /^Reminder/,
    );
    expect(customerSiteVisitEmail(data, "confirmed").text).toContain(
      "calendar.google.com",
    );
    const cancelled = customerSiteVisitEmail(data, "cancelled");
    expect(cancelled.text).toContain("Was: Sat, 14 Nov 2026, 3:00 pm");
    expect(cancelled.text).not.toContain("calendar.google.com");
  });

  it("directions only when the location is public", () => {
    expect(customerSiteVisitEmail(data, "confirmed").html).not.toContain(
      "Get directions",
    );
    const withMap = {
      ...data,
      property: {
        ...data.property,
        mapsUrl: "https://www.google.com/maps/dir/?api=1&destination=1,2",
      },
    };
    expect(customerSiteVisitEmail(withMap, "confirmed").html).toContain(
      "Get directions",
    );
  });
});
