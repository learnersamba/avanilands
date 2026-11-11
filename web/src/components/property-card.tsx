import { ArrowRight, MapPin, Ruler, Sparkles, Star } from "lucide-react";
import Link from "next/link";

import { SaveButton } from "@/components/account/save-button";
import { CompareButton } from "@/components/compare/compare-button";
import { StatusBadge, StatusRibbon } from "@/components/ui";
import type { PropertyCardData } from "@/lib/data";
import { formatArea, formatRupeesShort, formatSqft } from "@/lib/format";
import { mediaUrl } from "@/lib/media";

/** The listing card (docs/03-design.md §3). */
export function PropertyCard({
  property,
  priority = false,
}: {
  property: PropertyCardData;
  priority?: boolean;
}) {
  const place = [property.locality, property.city].filter(Boolean).join(", ");
  const sqft =
    property.area_unit === "sq_ft" ? null : formatSqft(property.area_sqft);
  const highlight = property.highlights[0];
  return (
    <article
      className={`group flex flex-col overflow-hidden rounded-2xl border bg-white shadow-sm transition-shadow hover:shadow-lg ${
        property.availability === "sold"
          ? "border-sold/50 ring-1 ring-sold/30"
          : property.availability === "reserved"
            ? "border-reserved/50 ring-1 ring-reserved/30"
            : "border-line"
      }`}
    >
      <div className="relative">
        <Link
          href={`/land/${property.slug}`}
          className="relative block aspect-[4/3] overflow-hidden bg-line"
        >
          {property.cover_thumb && property.cover_medium ? (
            // Photos are already sized (400 / 1200 px WebP), so a plain <img> with srcset is enough.
            // eslint-disable-next-line @next/next/no-img-element
            <img
              src={mediaUrl(property.cover_medium)}
              srcSet={`${mediaUrl(property.cover_thumb)} 400w, ${mediaUrl(property.cover_medium)} 1200w`}
              sizes="(min-width: 1024px) 400px, (min-width: 640px) 50vw, 100vw"
              alt={property.cover_alt}
              loading={priority ? "eager" : "lazy"}
              fetchPriority={priority ? "high" : "auto"}
              width={400}
              height={300}
              className="h-full w-full object-cover transition-transform duration-500 group-hover:scale-105"
            />
          ) : (
            <div className="bg-contours flex h-full items-center justify-center bg-forest text-sand-light">
              No photo yet
            </div>
          )}
          <StatusRibbon status={property.availability} size="sm" />
          <div className={`absolute top-3 flex gap-2 ${property.availability === "available" ? "left-3" : "left-24"}`}>
            {property.is_featured && (
              <span className="inline-flex items-center gap-1 rounded-full bg-sand px-2.5 py-1 text-[11px] font-semibold uppercase tracking-wide text-forest-dark">
                <Star className="h-3 w-3 fill-current" aria-hidden /> Featured
              </span>
            )}
          </div>
          <div className="absolute right-3 top-3">
            <StatusBadge status={property.availability} />
          </div>
        </Link>
        <div className="absolute bottom-3 right-3 flex items-center gap-2">
          <span className="rounded-full bg-white/95 shadow-sm">
            <CompareButton pick={{ code: property.code, title: property.title, thumb: property.cover_thumb }} />
          </span>
          <SaveButton propertyId={property.id} code={property.code} />
        </div>
      </div>

      <div className="flex flex-1 flex-col p-5">
        <p className="text-xs font-medium uppercase tracking-wide text-muted">
          {property.type_name} · {property.code}
        </p>
        <h3 className="mt-1.5 font-serif text-xl leading-snug text-ink">
          <Link href={`/land/${property.slug}`} className="hover:text-forest">
            {property.title}
          </Link>
        </h3>
        <p className="mt-2 flex items-center gap-1.5 text-sm text-ink/75">
          <MapPin className="h-4 w-4 shrink-0 text-sand" aria-hidden />
          {place}
        </p>
        <p className="mt-1 flex items-center gap-1.5 text-sm text-ink/75">
          <Ruler className="h-4 w-4 shrink-0 text-sand" aria-hidden />
          {formatArea(property.area_value, property.area_unit)}
          {sqft && <span className="text-muted">({sqft})</span>}
        </p>
        {highlight && (
          <p className="mt-1 flex items-center gap-1.5 text-sm text-ink/75">
            <Sparkles className="h-4 w-4 shrink-0 text-sand" aria-hidden />
            {highlight}
          </p>
        )}
        <div className="mt-auto flex items-end justify-between gap-3 pt-5">
          <div>
            {property.price_type === "on_request" || property.price == null ? (
              <>
                <p className="text-xs font-medium text-muted">Price</p>
                <p className="whitespace-nowrap font-serif text-xl text-forest">
                  On request
                </p>
              </>
            ) : (
              <p className="font-serif text-2xl text-forest">
                {formatRupeesShort(property.price)}
              </p>
            )}
            {property.is_negotiable && (
              <p className="text-xs font-medium text-muted">Negotiable</p>
            )}
          </div>
          <Link
            href={`/land/${property.slug}`}
            className="inline-flex shrink-0 items-center gap-1 whitespace-nowrap text-sm font-semibold text-forest hover:gap-2 hover:text-forest-dark"
            aria-label={`View details of ${property.title}`}
          >
            View details <ArrowRight className="h-4 w-4" aria-hidden />
          </Link>
        </div>
      </div>
    </article>
  );
}

export function PropertyGrid({
  properties,
  priorityCount = 0,
}: {
  properties: PropertyCardData[];
  priorityCount?: number;
}) {
  return (
    <div className="grid gap-6 sm:grid-cols-2 lg:grid-cols-3">
      {properties.map((property, index) => (
        <PropertyCard
          key={property.id}
          property={property}
          priority={index < priorityCount}
        />
      ))}
    </div>
  );
}
