import type { MetadataRoute } from "next";

import { getLandingCombos, getSitemapProperties } from "@/lib/data";
import { env } from "@/lib/env";

/** /sitemap.xml: main pages, every published property and every landing page with land on sale. */
export default async function sitemap(): Promise<MetadataRoute.Sitemap> {
  const [properties, combos] = await Promise.all([getSitemapProperties(), getLandingCombos()]);
  const url = (path: string) => `${env.siteUrl}${path}`;
  const cities = [...new Set(combos.map((combo) => combo.location_slug))];
  return [
    { url: url("/"), changeFrequency: "daily", priority: 1 },
    { url: url("/land"), changeFrequency: "daily", priority: 0.9 },
    ...cities.map((city) => ({ url: url(`/land-for-sale/${city}`), changeFrequency: "daily" as const, priority: 0.8 })),
    ...combos.map((combo) => ({
      url: url(`/${combo.type_seo_slug}-for-sale/${combo.location_slug}`),
      changeFrequency: "daily" as const,
      priority: 0.7,
    })),
    ...properties.map((property) => ({
      url: url(`/land/${property.slug}`),
      lastModified: property.updated_at,
      changeFrequency: "weekly" as const,
      priority: 0.8,
    })),
    ...["/locations", "/about", "/contact", "/faq"].map((path) => ({ url: url(path), changeFrequency: "monthly" as const, priority: 0.5 })),
    ...["/terms", "/privacy", "/disclaimer"].map((path) => ({ url: url(path), changeFrequency: "yearly" as const, priority: 0.2 })),
  ];
}
