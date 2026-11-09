import { describe, expect, it } from "vitest";

import { tagsForTable } from "@/lib/revalidate-tags";
import { breadcrumbJsonLd, jsonLdString, listingJsonLd, organizationJsonLd } from "@/lib/structured-data";

const base = {
  title: "200 Sq Yd Plot",
  description: "A plot.",
  url: "https://example.in/land/plot",
  images: ["https://cdn/1.webp"],
  published_at: "2026-11-01T00:00:00Z",
  price_type: "total" as const,
  price: 3600000,
  availability: "available" as const,
  locality: "Anandapuram",
  city: "Visakhapatnam",
  state: "Andhra Pradesh",
  pincode: "531163",
  address: null,
  latitude: 17.87,
  longitude: 83.37,
  show_exact_location: false,
  area_sqft: 1800,
  type_name: "Residential Plot",
};

describe("property structured data", () => {
  it("describes the offer in rupees", () => {
    const data = listingJsonLd(base);
    expect(data["@type"]).toBe("RealEstateListing");
    expect(data.offers).toMatchObject({ price: 3600000, priceCurrency: "INR", availability: "https://schema.org/InStock" });
  });

  it("never publishes the exact position unless allowed", () => {
    expect(listingJsonLd(base).contentLocation).not.toHaveProperty("geo");
    expect(listingJsonLd({ ...base, show_exact_location: true }).contentLocation).toHaveProperty("geo");
  });

  it("leaves out the price when it is on request", () => {
    expect(listingJsonLd({ ...base, price_type: "on_request", price: null }).offers).not.toHaveProperty("price");
  });

  it("maps reserved and sold", () => {
    expect(listingJsonLd({ ...base, availability: "sold" }).offers.availability).toBe("https://schema.org/SoldOut");
    expect(listingJsonLd({ ...base, availability: "reserved" }).offers.availability).toBe(
      "https://schema.org/LimitedAvailability",
    );
  });

  it("breadcrumbs are numbered", () => {
    const data = breadcrumbJsonLd([
      { name: "Home", url: "https://x/" },
      { name: "Land", url: "https://x/land" },
    ]);
    expect(data.itemListElement.map((item) => item.position)).toEqual([1, 2]);
  });

  it("organisation skips empty contact details", () => {
    const data = organizationJsonLd(
      { company_name: "Avanilands", phone: null, email: null, address: null, social_links: {} },
      "https://x",
    );
    expect(data).not.toHaveProperty("telephone");
    expect(data).not.toHaveProperty("sameAs");
  });

  it("text cannot close the script tag", () => {
    expect(jsonLdString({ name: "</script><script>alert(1)</script>" })).not.toContain("</script>");
  });
});

describe("cache refresh", () => {
  it("knows which data each table affects", () => {
    expect(tagsForTable("property_images")).toEqual(["properties"]);
    expect(tagsForTable("locations")).toEqual(["locations", "properties"]);
    expect(tagsForTable("site_settings")).toEqual(["settings"]);
  });

  it("ignores tables the website doesn't use", () => {
    expect(tagsForTable("admin_users")).toBeNull();
    expect(tagsForTable("toString")).toBeNull();
    expect(tagsForTable(42)).toBeNull();
  });
});
