/**
 * Which cached data to refresh when a database table changes
 * (the database sends {"table": "<name>"} to /api/revalidate).
 * Tag names match the cacheTag(...) calls in src/lib/data.ts.
 */
const tagsByTable: Record<string, string[]> = {
  properties: ["properties"],
  property_images: ["properties"],
  property_videos: ["properties"],
  property_documents: ["properties"],
  property_amenities: ["properties"],
  property_nearby_places: ["properties"],
  locations: ["locations", "properties"],
  property_types: ["property-types", "properties"],
  amenities: ["amenities", "properties"],
  site_settings: ["settings"],
  content_blocks: ["content"],
  faqs: ["faqs"],
  testimonials: ["testimonials"],
  banners: ["banners"],
};

/** Tags to refresh for a table, or null for a table the website doesn't use. */
export function tagsForTable(table: unknown): string[] | null {
  return typeof table === "string" && Object.hasOwn(tagsByTable, table) ? tagsByTable[table] : null;
}
