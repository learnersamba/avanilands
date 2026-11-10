/**
 * schema.org data for search engines (docs/01-architecture.md §5).
 * Plain functions so they can be unit-tested; rendered by <JsonLd>.
 */

type Settings = {
  company_name: string;
  legal_name?: string;
  tagline?: string;
  gst_number?: string | null;
  phone: string | null;
  email: string | null;
  address: string | null;
  social_links: Record<string, string>;
};

export function organizationJsonLd(settings: Settings, siteUrl: string) {
  return {
    "@context": "https://schema.org",
    "@type": "RealEstateAgent",
    name: settings.company_name,
    ...(settings.legal_name && { legalName: settings.legal_name }),
    ...(settings.tagline && { slogan: settings.tagline }),
    ...(settings.gst_number && { taxID: settings.gst_number }),
    url: siteUrl,
    ...(settings.phone && { telephone: settings.phone }),
    ...(settings.email && { email: settings.email }),
    ...(settings.address && { address: { "@type": "PostalAddress", streetAddress: settings.address, addressCountry: "IN" } }),
    areaServed: { "@type": "State", name: "Andhra Pradesh" },
    ...(Object.keys(settings.social_links).length > 0 && { sameAs: Object.values(settings.social_links) }),
  };
}

type ListingInput = {
  title: string;
  description: string | null;
  url: string;
  images: string[];
  published_at: string;
  price_type: "total" | "on_request";
  price: number | null;
  availability: "available" | "reserved" | "sold";
  locality: string | null;
  city: string;
  state: string;
  pincode: string | null;
  address: string | null;
  latitude: number | null;
  longitude: number | null;
  show_exact_location: boolean;
  area_sqft: number | null;
  type_name: string;
};

const availabilityUrl = {
  available: "https://schema.org/InStock",
  reserved: "https://schema.org/LimitedAvailability",
  sold: "https://schema.org/SoldOut",
} as const;

export function listingJsonLd(p: ListingInput) {
  const place = {
    "@type": "Place",
    name: [p.locality, p.city].filter(Boolean).join(", "),
    address: {
      "@type": "PostalAddress",
      ...(p.address && { streetAddress: p.address }),
      addressLocality: p.locality ?? p.city,
      addressRegion: p.state,
      ...(p.pincode && { postalCode: p.pincode }),
      addressCountry: "IN",
    },
    // Exact position only when the owner allows it (decision 18).
    ...(p.show_exact_location &&
      p.latitude != null &&
      p.longitude != null && { geo: { "@type": "GeoCoordinates", latitude: p.latitude, longitude: p.longitude } }),
  };
  return {
    "@context": "https://schema.org",
    "@type": "RealEstateListing",
    name: p.title,
    url: p.url,
    ...(p.description && { description: p.description.slice(0, 5000) }),
    ...(p.images.length > 0 && { image: p.images }),
    datePosted: p.published_at,
    category: p.type_name,
    contentLocation: place,
    ...(p.area_sqft != null && {
      floorSize: { "@type": "QuantitativeValue", value: Math.round(p.area_sqft), unitCode: "FTK" },
    }),
    offers: {
      "@type": "Offer",
      availability: availabilityUrl[p.availability],
      priceCurrency: "INR",
      ...(p.price_type === "total" && p.price != null && { price: p.price }),
      url: p.url,
    },
  };
}

export function breadcrumbJsonLd(items: { name: string; url: string }[]) {
  return {
    "@context": "https://schema.org",
    "@type": "BreadcrumbList",
    itemListElement: items.map((item, index) => ({
      "@type": "ListItem",
      position: index + 1,
      name: item.name,
      item: item.url,
    })),
  };
}

/** JSON for a <script type="application/ld+json">, safe against "</script>" in text. */
export function jsonLdString(data: unknown): string {
  return JSON.stringify(data).replace(/</g, "\\u003c");
}
