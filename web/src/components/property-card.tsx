import { ArrowRight, BadgeCheck, MapPin, Ruler, Star } from "lucide-react";
import Link from "next/link";

import { SaveButton } from "@/components/account/save-button";
import { features } from "@/lib/features";
import { CompareButton } from "@/components/compare/compare-button";
import { StatusBadge, StatusRibbon } from "@/components/ui";
import type { PropertyCardData } from "@/lib/data";
import { approvalLabels, formatArea, formatRupees, formatRupeesShort, formatSqft, unitLabel } from "@/lib/format";
import { mediaUrl } from "@/lib/media";

/** The listing card (redesign Nov 2026): photo, approval, title, place, price with rate. */
export function PropertyCard({
  property,
  priority = false,
}: {
  property: PropertyCardData;
  priority?: boolean;
}) {
  const place = [property.locality, property.city].filter(Boolean).join(", ");
  const sqft = property.area_unit === "sq_ft" ? null : formatSqft(property.area_sqft);
  const approved = property.approval_type && property.approval_type !== "not_applicable";
  const onRequest = property.price_type === "on_request" || property.price == null;
  const rate =
    property.price_per_unit != null && property.price_per_unit_unit
      ? `${formatRupees(property.price_per_unit)} / ${unitLabel(property.price_per_unit_unit)}`
      : null;
  return (
    <article
      className={`group flex flex-col overflow-hidden rounded-xl border bg-white transition-[border-color,box-shadow,transform] hover:-translate-y-0.5 hover:shadow-[0_18px_40px_-24px_rgba(11,59,46,0.45)] ${
        property.availability === "sold"
          ? "border-sold/50 ring-1 ring-sold/30"
          : property.availability === "reserved"
            ? "border-reserved/50 ring-1 ring-reserved/30"
            : "border-line hover:border-forest-dark/20"
      }`}
    >
      <div className="relative">
        <Link href={`/land/${property.slug}`} className="relative block aspect-[4/3] overflow-hidden bg-line">
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
              className="h-full w-full object-cover transition-transform duration-700 group-hover:scale-[1.04]"
            />
          ) : (
            <div className="bg-contours flex h-full items-center justify-center bg-forest-dark text-sm text-sand-light/80">
              No photo yet
            </div>
          )}
          <StatusRibbon status={property.availability} size="sm" />
          <div className={`absolute top-3 flex gap-2 ${property.availability === "available" ? "left-3" : "left-24"}`}>
            {property.is_featured && (
              <span className="inline-flex items-center gap-1 rounded-full bg-forest-dark/90 px-2.5 py-1 font-heading text-[11px] font-semibold text-sand">
                <Star className="h-3 w-3 fill-sand text-sand" aria-hidden /> Featured
              </span>
            )}
          </div>
          {approved && (
            <span className="absolute bottom-3 left-3 inline-flex items-center gap-1 rounded-full bg-white/95 px-2.5 py-1 text-xs font-semibold text-forest-dark shadow-sm">
              <BadgeCheck className="h-3.5 w-3.5 text-forest-light" aria-hidden />
              {approvalLabels[property.approval_type] ?? property.approval_type}
            </span>
          )}
        </Link>
        <div className="absolute right-3 top-3 flex items-center gap-2">
          {features.customerAccounts && <SaveButton propertyId={property.id} code={property.code} />}
        </div>
      </div>

      <div className="flex flex-1 flex-col p-5">
        <p className="flex items-center justify-between gap-3 text-xs text-muted">
          <span className="font-heading font-semibold uppercase tracking-[0.08em] text-sand-dark">{property.type_name}</span>
          <StatusBadge status={property.availability} />
        </p>
        <h3 className="mt-2 font-heading text-[1.1rem] font-bold leading-snug text-forest-dark">
          <Link href={`/land/${property.slug}`} className="hover:text-forest-light">
            {property.title}
          </Link>
        </h3>
        <p className="mt-2 flex items-center gap-1.5 text-sm text-ink/80">
          <MapPin className="h-4 w-4 shrink-0 text-sand-dark" strokeWidth={1.75} aria-hidden />
          {place}
        </p>
        <p className="mt-1 flex items-center gap-1.5 text-sm text-ink/80">
          <Ruler className="h-4 w-4 shrink-0 text-sand-dark" strokeWidth={1.75} aria-hidden />
          {formatArea(property.area_value, property.area_unit)}
          {sqft && <span className="text-muted">({sqft})</span>}
        </p>

        <div className="min-h-5 flex-1" aria-hidden />
        <div className="flex items-end justify-between gap-3 border-t border-line pt-4">
          <div className="min-w-0">
            {onRequest ? (
              <p className="font-heading text-lg font-bold text-forest-dark">Price on request</p>
            ) : (
              <p className="font-heading text-[1.35rem] font-bold leading-none text-forest-dark tabular-nums">
                {formatRupeesShort(property.price!)}
                {property.is_negotiable && (
                  <span className="ml-2 align-middle font-sans text-xs font-medium text-muted">Negotiable</span>
                )}
              </p>
            )}
            {rate && <p className="mt-1.5 text-sm font-medium text-forest-light tabular-nums">{rate}</p>}
          </div>
          <div className="flex shrink-0 items-center gap-2">
            <span className="rounded-full border border-line">
              <CompareButton pick={{ code: property.code, title: property.title, thumb: property.cover_thumb }} />
            </span>
            <Link
              href={`/land/${property.slug}`}
              className="inline-flex h-10 w-10 items-center justify-center rounded-full bg-forest-dark text-white transition-colors hover:bg-forest-light"
              aria-label={`View details of ${property.title}`}
            >
              <ArrowRight className="h-4 w-4" aria-hidden />
            </Link>
          </div>
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
    <div className="grid gap-x-6 gap-y-8 sm:grid-cols-2 lg:grid-cols-3">
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
