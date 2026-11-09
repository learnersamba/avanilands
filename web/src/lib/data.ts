import "server-only";

import { cacheLife, cacheTag } from "next/cache";

import {
  type Banner,
  defaultContent,
  defaultFaqs,
  type Faq,
  parseContent,
  type SiteContent,
  type Testimonial,
} from "@/lib/content";

import type { AreaUnit, Availability } from "@/lib/format";
import type { SearchArgs } from "@/lib/listing";
import { createPublicClient } from "@/lib/supabase/public";

/**
 * Everything the website reads, from the public views and functions only
 * (docs/02-database.md §7). Results are cached and tagged; Phase 7 adds
 * on-demand refresh when an admin saves a change.
 */

export type PublicProperty = {
  id: string;
  code: string;
  slug: string;
  title: string;
  property_type_id: number;
  type_name: string;
  type_slug: string;
  type_seo_slug: string;
  description: string | null;
  location_id: string;
  city: string;
  district: string;
  state: string;
  location_slug: string;
  locality: string | null;
  address: string | null;
  pincode: string | null;
  latitude: number | null;
  longitude: number | null;
  show_exact_location: boolean;
  area_value: number | null;
  area_unit: AreaUnit;
  area_sqft: number | null;
  length_ft: number | null;
  width_ft: number | null;
  dimensions_text: string | null;
  price_type: "total" | "on_request";
  price: number | null;
  price_per_unit: number | null;
  price_per_unit_unit: AreaUnit | null;
  is_negotiable: boolean;
  facing: string | null;
  road_width_ft: number | null;
  is_corner: boolean;
  water_available: boolean | null;
  water_source: string | null;
  electricity_available: boolean | null;
  approval_type: string;
  approval_number: string | null;
  rera_number: string | null;
  legal_notes: string | null;
  highlights: string[];
  availability: Availability;
  is_featured: boolean;
  featured_rank: number | null;
  seo_title: string | null;
  seo_description: string | null;
  published_at: string;
  updated_at: string;
  cover_thumb: string | null;
  cover_medium: string | null;
  cover_large: string | null;
  cover_alt: string;
  image_count: number;
};

/** Card fields only (search results leave out long text). */
export type PropertyCardData = Omit<
  PublicProperty,
  "description" | "legal_notes" | "address" | "seo_title" | "seo_description"
>;

export type SiteSettings = {
  company_name: string;
  phone: string | null;
  whatsapp: string | null;
  email: string | null;
  address: string | null;
  office_hours: string | null;
  social_links: Record<string, string>;
  seo_title: string | null;
  seo_description: string | null;
  /** Site visits: ISO weekdays (1 = Monday), "HH:MM" start times, upcoming holidays, booking window. */
  visit_days: number[];
  visit_slots: string[];
  visit_closed_dates: string[];
  visit_days_ahead: number;
};

export type LocationSummary = {
  id: string;
  city: string;
  district: string;
  state: string;
  slug: string;
  description: string | null;
  cover_image_path: string | null;
  is_popular: boolean;
  count: number;
};

export type PropertyType = { id: number; name: string; slug: string; seo_slug: string };

const fallbackSettings: SiteSettings = {
  company_name: "Avanilands",
  phone: null,
  whatsapp: null,
  email: null,
  address: null,
  office_hours: null,
  social_links: {},
  seo_title: null,
  seo_description: null,
  visit_days: [1, 2, 3, 4, 5, 6],
  visit_slots: ["10:00", "12:00", "15:00"],
  visit_closed_dates: [],
  visit_days_ahead: 30,
};

function fail(what: string, message: string): never {
  throw new Error(`Could not load ${what}: ${message}`);
}

export async function getSiteSettings(): Promise<SiteSettings> {
  "use cache";
  cacheLife("hours");
  cacheTag("settings");
  const { data, error } = await createPublicClient().from("public_site_settings").select("*").maybeSingle();
  if (error) fail("settings", error.message);
  // Defaults fill any field a newer website expects but the database doesn't have yet.
  return { ...fallbackSettings, ...(data as Partial<SiteSettings> | null) };
}

export async function getFeaturedProperties(limit = 6): Promise<PropertyCardData[]> {
  "use cache";
  cacheLife("hours");
  cacheTag("properties");
  const { data, error } = await createPublicClient().rpc("search_properties", {
    p_featured_only: true,
    p_sort: "featured",
    p_page_size: limit,
  });
  if (error) fail("featured properties", error.message);
  return (data as { items: PropertyCardData[] }).items;
}

export async function getRecentProperties(limit = 6): Promise<PropertyCardData[]> {
  "use cache";
  cacheLife("hours");
  cacheTag("properties");
  const { data, error } = await createPublicClient().rpc("search_properties", {
    p_sort: "newest",
    p_page_size: limit,
  });
  if (error) fail("recent properties", error.message);
  return (data as { items: PropertyCardData[] }).items;
}

/** One page of search results (the database does the filtering, decision 35). */
export async function searchListing(args: SearchArgs): Promise<{ total: number; items: PropertyCardData[] }> {
  "use cache";
  cacheLife("hours");
  cacheTag("properties");
  const { data, error } = await createPublicClient().rpc("search_properties", args);
  if (error) fail("properties", error.message);
  return data as { total: number; items: PropertyCardData[] };
}

export type Amenity = { id: number; name: string };

export async function getAmenities(): Promise<Amenity[]> {
  "use cache";
  cacheLife("hours");
  cacheTag("amenities");
  const { data, error } = await createPublicClient()
    .from("amenities")
    .select("id, name")
    .order("sort_order", { ascending: true });
  if (error) fail("amenities", error.message);
  return data;
}

/** Active locations with how many properties are on sale in each. */
export async function getLocations(): Promise<LocationSummary[]> {
  "use cache";
  cacheLife("hours");
  cacheTag("locations", "properties");
  const client = createPublicClient();
  const [locations, properties] = await Promise.all([
    client
      .from("locations")
      .select("id, city, district, state, slug, description, cover_image_path, is_popular")
      .order("sort_order", { ascending: true }),
    client.from("public_properties").select("location_id").neq("availability", "sold"),
  ]);
  if (locations.error) fail("locations", locations.error.message);
  if (properties.error) fail("location counts", properties.error.message);
  const counts = new Map<string, number>();
  for (const row of properties.data) counts.set(row.location_id, (counts.get(row.location_id) ?? 0) + 1);
  return locations.data.map((location) => ({ ...location, count: counts.get(location.id) ?? 0 }));
}

export async function getPropertyTypes(): Promise<PropertyType[]> {
  "use cache";
  cacheLife("hours");
  cacheTag("property-types");
  const { data, error } = await createPublicClient()
    .from("property_types")
    .select("id, name, slug, seo_slug")
    .order("sort_order", { ascending: true });
  if (error) fail("property types", error.message);
  return data;
}

/** Place and type combinations that have land on sale, for landing pages. */
export async function getLandingCombos(): Promise<{ type_seo_slug: string; location_slug: string }[]> {
  "use cache";
  cacheLife("hours");
  cacheTag("properties");
  const { data, error } = await createPublicClient()
    .from("public_properties")
    .select("type_seo_slug, location_slug")
    .neq("availability", "sold");
  if (error) fail("landing pages", error.message);
  const seen = new Set<string>();
  return data.filter((row) => {
    const key = `${row.type_seo_slug}/${row.location_slug}`;
    if (seen.has(key)) return false;
    seen.add(key);
    return true;
  });
}

/**
 * The newest published slugs, to pre-build at deploy time. Others are built
 * on their first visit and then cached, so builds stay fast with many properties.
 */
/** Every published property, for the sitemap. */
export async function getSitemapProperties(): Promise<{ slug: string; updated_at: string }[]> {
  "use cache";
  cacheLife("hours");
  cacheTag("properties");
  const { data, error } = await createPublicClient()
    .from("public_properties")
    .select("slug, updated_at")
    .order("published_at", { ascending: false })
    .limit(50000);
  if (error) fail("the sitemap", error.message);
  return data;
}

export async function getPublishedSlugs(limit = 50): Promise<string[]> {
  "use cache";
  cacheLife("hours");
  cacheTag("properties");
  const { data, error } = await createPublicClient()
    .from("public_properties")
    .select("slug")
    .order("published_at", { ascending: false })
    .limit(limit);
  if (error) fail("property links", error.message);
  return data.map((row) => row.slug);
}

export type PropertyPhoto = { id: string; thumb: string; medium: string; large: string; alt: string };
export type PropertyVideo = { id: string; kind: "youtube" | "upload"; youtube_id: string | null; storage_path: string | null; title: string | null };
export type NearbyPlace = { id: string; name: string; category: string; distance_km: number | null };
export type PublicDocument = { id: string; doc_type: string; title: string; mime_type: string; size_bytes: number };

export type PropertyPage = {
  property: PublicProperty;
  photos: PropertyPhoto[];
  videos: PropertyVideo[];
  amenities: string[];
  nearby: NearbyPlace[];
  documents: PublicDocument[];
};

export type PropertyRoute = {
  slug: string;
  state: "published" | "archived";
  title: string;
  city: string;
  property_type_id: number;
  location_id: string;
};

/** Where /land/<slug> should go (see property_route in the database). Null = not found. */
export async function getPropertyRoute(slug: string): Promise<PropertyRoute | null> {
  "use cache";
  cacheLife("minutes");
  cacheTag("properties");
  const { data, error } = await createPublicClient().rpc("property_route", { p_slug: slug });
  if (error) fail("the property link", error.message);
  return (data as PropertyRoute | null) ?? null;
}

/** Everything for one property page, or null when it isn't published. */
export async function getPropertyPage(slug: string): Promise<PropertyPage | null> {
  "use cache";
  cacheLife("hours");
  cacheTag("properties", `property:${slug}`);
  const client = createPublicClient();
  const { data: property, error } = await client.from("public_properties").select("*").eq("slug", slug).maybeSingle();
  if (error) fail("the property", error.message);
  if (!property) return null;

  const id = (property as PublicProperty).id;
  const [photos, videos, amenities, nearby, documents] = await Promise.all([
    client
      .from("property_images")
      .select("id, path_thumb, path_medium, path_large, alt_text, is_cover, sort_order")
      .eq("property_id", id)
      .order("sort_order", { ascending: true }),
    client
      .from("property_videos")
      .select("id, kind, youtube_id, storage_path, title, is_primary, sort_order")
      .eq("property_id", id)
      .order("is_primary", { ascending: false })
      .order("sort_order", { ascending: true }),
    client.from("property_amenities").select("amenities(name, sort_order)").eq("property_id", id),
    client
      .from("property_nearby_places")
      .select("id, name, category, distance_km")
      .eq("property_id", id)
      .order("sort_order", { ascending: true }),
    client
      .from("public_property_documents")
      .select("id, doc_type, title, mime_type, size_bytes")
      .eq("property_id", id)
      .order("sort_order", { ascending: true }),
  ]);
  for (const result of [photos, videos, amenities, nearby, documents]) {
    if (result.error) fail("property details", result.error.message);
  }

  const title = (property as PublicProperty).title;
  const sortedPhotos = [...(photos.data ?? [])].sort((a, b) => Number(b.is_cover) - Number(a.is_cover));
  type AmenityRow = { amenities: { name: string; sort_order: number } | null };
  return {
    property: property as PublicProperty,
    photos: sortedPhotos.map((p) => ({
      id: p.id,
      thumb: p.path_thumb,
      medium: p.path_medium,
      large: p.path_large,
      alt: p.alt_text ?? title,
    })),
    videos: (videos.data ?? []) as PropertyVideo[],
    amenities: ((amenities.data ?? []) as unknown as AmenityRow[])
      .map((row) => row.amenities)
      .filter((a): a is { name: string; sort_order: number } => a != null)
      .sort((a, b) => a.sort_order - b.sort_order)
      .map((a) => a.name),
    nearby: (nearby.data ?? []) as NearbyPlace[],
    documents: (documents.data ?? []) as PublicDocument[],
  };
}

/** Up to 3 other properties of the same type or place. */
export async function getRelatedProperties(
  property: Pick<PublicProperty, "id" | "property_type_id" | "location_id">,
): Promise<PropertyCardData[]> {
  "use cache";
  cacheLife("hours");
  cacheTag("properties");
  const client = createPublicClient();
  const sameType = await client.rpc("search_properties", {
    p_type_ids: [property.property_type_id],
    p_page_size: 4,
  });
  const sameCity = await client.rpc("search_properties", {
    p_location_ids: [property.location_id],
    p_page_size: 4,
  });
  if (sameType.error) fail("related properties", sameType.error.message);
  if (sameCity.error) fail("related properties", sameCity.error.message);
  const seen = new Set([property.id]);
  const related: PropertyCardData[] = [];
  for (const item of [...sameCity.data.items, ...sameType.data.items] as PropertyCardData[]) {
    if (!seen.has(item.id)) {
      seen.add(item.id);
      related.push(item);
    }
  }
  return related.slice(0, 3);
}

export type ComparedProperty = PublicProperty & { amenities: string[] };

/**
 * The properties to compare, in the order asked, plus the codes that are no
 * longer published (left out with a note).
 */
export async function getComparison(codes: string[]): Promise<{ items: ComparedProperty[]; missing: string[] }> {
  "use cache";
  cacheLife("hours");
  cacheTag("properties", "amenities");
  if (codes.length === 0) return { items: [], missing: [] };
  const client = createPublicClient();
  const { data, error } = await client.from("public_properties").select("*").in("code", codes);
  if (error) fail("properties to compare", error.message);
  const found = (data ?? []) as PublicProperty[];
  const { data: links, error: amenityError } = await client
    .from("property_amenities")
    .select("property_id, amenities(name, sort_order)")
    .in("property_id", found.length ? found.map((p) => p.id) : ["00000000-0000-0000-0000-000000000000"]);
  if (amenityError) fail("amenities to compare", amenityError.message);
  type Link = { property_id: string; amenities: { name: string; sort_order: number } | null };
  const amenitiesOf = (id: string) =>
    ((links ?? []) as unknown as Link[])
      .filter((link) => link.property_id === id && link.amenities)
      .map((link) => link.amenities!)
      .sort((a, b) => a.sort_order - b.sort_order)
      .map((a) => a.name);
  const byCode = new Map(found.map((p) => [p.code, p]));
  return {
    items: codes.flatMap((code) => {
      const p = byCode.get(code);
      return p ? [{ ...p, amenities: amenitiesOf(p.id) }] : [];
    }),
    missing: codes.filter((code) => !byCode.has(code)),
  };
}

// ---------------------------------------------------------------------------
// Website content (Phase 14). On any loading problem: the built-in text.
// ---------------------------------------------------------------------------

export async function getSiteContent(): Promise<SiteContent> {
  "use cache";
  cacheLife("hours");
  cacheTag("content");
  const { data, error } = await createPublicClient().from("public_content").select("key, value");
  if (error) {
    console.error("Could not load website content; using the built-in text", error.message);
    return defaultContent;
  }
  return parseContent(data ?? []);
}

export async function getFaqs(): Promise<Faq[]> {
  "use cache";
  cacheLife("hours");
  cacheTag("faqs");
  const { data, error } = await createPublicClient()
    .from("faqs")
    .select("id, question, answer, show_on_home")
    .order("sort_order", { ascending: true })
    .order("created_at", { ascending: true });
  if (error) {
    console.error("Could not load FAQs; using the built-in ones", error.message);
    return defaultFaqs;
  }
  return (data ?? []) as Faq[];
}

export async function getTestimonials(): Promise<Testimonial[]> {
  "use cache";
  cacheLife("hours");
  cacheTag("testimonials");
  const { data, error } = await createPublicClient()
    .from("testimonials")
    .select("id, name, place, quote, rating, photo_path")
    .order("sort_order", { ascending: true })
    .limit(6);
  if (error) return [];
  return (data ?? []) as Testimonial[];
}

/**
 * Banners inside their dates. The "minutes" profile re-checks about every
 * minute, so schedules start and end on time while the page stays
 * pre-rendered (a shorter "stale" time would make the home page dynamic).
 */
export async function getBanners(): Promise<Banner[]> {
  "use cache";
  cacheLife("minutes");
  cacheTag("banners");
  const { data, error } = await createPublicClient()
    .from("banners")
    .select("id, title, text, link_url, link_label, image_path")
    .order("sort_order", { ascending: true })
    .limit(3);
  if (error) return [];
  return (data ?? []) as Banner[];
}

