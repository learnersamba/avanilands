import { CalendarDays, Mail } from "lucide-react";
import type { Metadata } from "next";
import Link from "next/link";
import { type ReactNode, Suspense } from "react";

import {
  DifferencesToggle,
  RemoveFromComparison,
  ShareComparison,
  YourPicks,
} from "@/components/compare/compare-controls";
import { PageHero } from "@/components/page-hero";
import { ButtonLink, Container, StatusBadge } from "@/components/ui";
import {
  allSame,
  bestIndexes,
  compareHref,
  distanceKm,
  formatDistance,
  maxCompare,
  parseCodes,
  pricePerSqft,
} from "@/lib/compare";
import { type ComparedProperty, getComparison } from "@/lib/data";
import { env } from "@/lib/env";
import {
  approvalLabels,
  availabilityLabels,
  facingLabels,
  formatArea,
  formatNumber,
  formatRupees,
  formatRupeesShort,
  formatSqft,
} from "@/lib/format";
import { mediaUrl } from "@/lib/media";

export const metadata: Metadata = {
  title: "Compare land",
  description:
    "Compare plots and land side by side: price per sq ft, size, road, approvals and more.",
  // Any mix of codes makes a page: never indexed, but links in it are followed.
  robots: { index: false, follow: true },
};

export default function ComparePage(props: PageProps<"/compare">) {
  return (
    <>
      <PageHero
        title="Compare land"
        subtitle={`Up to ${maxCompare} properties side by side. Share the page with family before you visit.`}
        crumbs={[{ href: "/compare", label: "Compare" }]}
      />
      <Container className="py-10">
        <Suspense
          fallback={<p className="text-muted">Loading the comparison…</p>}
        >
          <Comparison searchParams={props.searchParams} />
        </Suspense>
      </Container>
    </>
  );
}

type Row = {
  label: string;
  cells: ReactNode[];
  /** Plain text of each cell, to spot rows where everything is the same. */
  text: string[];
  best?: Set<number>;
  bestNote?: string;
};

async function Comparison({
  searchParams,
}: {
  searchParams: PageProps<"/compare">["searchParams"];
}) {
  const codes = parseCodes((await searchParams).codes);
  const { items, missing } = await getComparison(codes);
  const shownCodes = items.map((p) => p.code);

  const missingNote = missing.length > 0 && (
    <p className="mb-6 rounded-xl bg-sand-light px-4 py-3 text-sm text-ink">
      {missing.join(", ")} {missing.length === 1 ? "is" : "are"} no longer for
      sale on the website, so {missing.length === 1 ? "it was" : "they were"}{" "}
      left out.
    </p>
  );

  if (items.length < 2) {
    return (
      <div className="max-w-2xl">
        {missingNote}
        <h2 className="font-serif text-2xl text-forest">
          {items.length === 1
            ? `Add one more to compare with ${items[0].code}`
            : "Pick 2 or 3 properties to compare"}
        </h2>
        <p className="mt-2 text-ink/75">
          Tap <strong>Compare</strong> on any property, then{" "}
          <strong>Compare now</strong> at the bottom of the screen.
        </p>
        <div className="mt-6 flex flex-wrap gap-3">
          <YourPicks />
          <ButtonLink href="/land" variant="outline">
            Browse land
          </ButtonLink>
        </div>
      </div>
    );
  }

  const rows = buildRows(items);
  const url = `${env.siteUrl}${compareHref(shownCodes)}`;
  return (
    <div>
      {missingNote}
      <div className="mb-6 flex flex-wrap items-center justify-between gap-4">
        <p className="text-ink/75">
          Comparing {items.map((p) => p.code).join(", ")}.{" "}
          {items.length < maxCompare && (
            <Link href="/land" className="font-semibold text-forest underline">
              Add another
            </Link>
          )}
        </p>
        <ShareComparison url={url} />
      </div>

      <DifferencesToggle>
        <div className="overflow-x-auto rounded-2xl bg-white shadow-sm ring-1 ring-line">
          <table
            className="w-full table-fixed border-collapse text-sm"
            // Phones scroll sideways: a narrow label column + ~180 px per property.
            style={{ minWidth: `${96 + items.length * 180}px` }}
          >
            <caption className="sr-only">
              Properties compared side by side
            </caption>
            <thead>
              <tr>
                <th
                  scope="col"
                  className="sticky left-0 z-10 w-24 bg-white sm:w-36 p-4 text-left align-bottom text-xs uppercase tracking-wide text-muted"
                >
                  <span className="sr-only">Detail</span>
                </th>
                {items.map((p) => (
                  <th
                    key={p.id}
                    scope="col"
                    className="border-l border-line p-3 text-left align-top font-normal sm:p-4"
                  >
                    <Link href={`/land/${p.slug}`} className="group block">
                      <div className="relative aspect-[4/3] overflow-hidden rounded-xl bg-line">
                        {p.cover_thumb && p.cover_medium ? (
                          // eslint-disable-next-line @next/next/no-img-element
                          <img
                            src={mediaUrl(p.cover_medium)}
                            srcSet={`${mediaUrl(p.cover_thumb)} 400w, ${mediaUrl(p.cover_medium)} 1200w`}
                            sizes="300px"
                            alt={p.cover_alt}
                            width={400}
                            height={300}
                            className="h-full w-full object-cover"
                          />
                        ) : (
                          <div className="flex h-full items-center justify-center bg-forest text-sand-light">
                            No photo
                          </div>
                        )}
                        <span className="absolute right-2 top-2">
                          <StatusBadge status={p.availability} />
                        </span>
                      </div>
                      <p className="mt-3 text-xs font-medium uppercase tracking-wide text-muted">
                        {p.type_name} · {p.code}
                      </p>
                      <p className="mt-1 font-serif text-lg leading-snug text-ink group-hover:text-forest">
                        {p.title}
                      </p>
                    </Link>
                    <div className="mt-2">
                      <RemoveFromComparison code={p.code} codes={shownCodes} />
                    </div>
                  </th>
                ))}
              </tr>
            </thead>
            <tbody>
              {rows.map((row) => (
                <tr
                  key={row.label}
                  data-same={allSame(row.text)}
                  className="border-t border-line data-[same=true]:group-data-[diff-only=true]/compare:hidden"
                >
                  <th
                    scope="row"
                    className="sticky left-0 z-10 bg-white p-3 text-left sm:p-4 align-top font-medium text-ink/70"
                  >
                    {row.label}
                  </th>
                  {row.cells.map((cell, index) => (
                    <td
                      key={index}
                      className={`border-l border-line p-3 align-top sm:p-4 ${row.best?.has(index) ? "bg-available/5" : ""}`}
                    >
                      {cell}
                      {row.best?.has(index) && (
                        <span className="mt-1 block text-xs font-semibold text-available">
                          ✓ {row.bestNote}
                        </span>
                      )}
                    </td>
                  ))}
                </tr>
              ))}
              <tr className="border-t border-line">
                <th
                  scope="row"
                  className="sticky left-0 z-10 bg-white p-3 text-left sm:p-4 font-medium text-ink/70"
                >
                  Next step
                </th>
                {items.map((p) => (
                  <td key={p.id} className="border-l border-line p-4">
                    {p.availability === "sold" ? (
                      <StatusBadge status="sold" />
                    ) : (
                      <div className="flex flex-col gap-2">
                        <Link
                          href={`/land/${p.slug}#visit`}
                          className="inline-flex items-center gap-2 font-semibold text-forest hover:underline"
                        >
                          <CalendarDays className="h-4 w-4" aria-hidden /> Book
                          a site visit
                        </Link>
                        <Link
                          href={`/land/${p.slug}#enquire`}
                          className="inline-flex items-center gap-2 text-forest hover:underline"
                        >
                          <Mail className="h-4 w-4" aria-hidden /> Ask a
                          question
                        </Link>
                      </div>
                    )}
                  </td>
                ))}
              </tr>
            </tbody>
          </table>
        </div>
      </DifferencesToggle>
      <p className="mt-4 text-xs text-muted">
        Price per sq ft is worked out from the total price and area so plots in
        cents, acres and sq yards compare fairly. Distances are straight-line
        and approximate where the exact location isn&apos;t public.
      </p>
    </div>
  );
}

const yesNo = (value: boolean | null) =>
  value == null ? "Not stated" : value ? "Yes" : "No";

function buildRows(items: ComparedProperty[]): Row[] {
  const perSqft = items.map(pricePerSqft);
  const prices = items.map((p) => (p.price_type === "total" ? p.price : null));
  const rows: Row[] = [
    {
      label: "Price",
      cells: items.map((p, i) =>
        prices[i] == null ? (
          "Price on request"
        ) : (
          <span key={i}>
            <strong className="font-serif text-lg text-forest">
              {formatRupeesShort(prices[i]!)}
            </strong>
            <span className="block text-xs text-muted">
              {formatRupees(prices[i]!)}
              {p.is_negotiable ? " · negotiable" : ""}
            </span>
          </span>
        ),
      ),
      text: items.map((p, i) => `${prices[i] ?? "request"}${p.is_negotiable}`),
      best: bestIndexes(prices, "min"),
      bestNote: "Lowest price",
    },
    {
      label: "Price per sq ft",
      cells: perSqft.map((v) =>
        v == null ? "—" : `₹${formatNumber(Math.round(v))} / sq ft`,
      ),
      text: perSqft.map((v) => String(v == null ? "" : Math.round(v))),
      best: bestIndexes(
        perSqft.map((v) => (v == null ? null : Math.round(v))),
        "min",
      ),
      bestNote: "Best value",
    },
    {
      label: "Area",
      cells: items.map((p) => (
        <span key={p.id}>
          {formatArea(p.area_value, p.area_unit)}
          {p.area_unit !== "sq_ft" && formatSqft(p.area_sqft) && (
            <span className="block text-xs text-muted">
              {formatSqft(p.area_sqft)}
            </span>
          )}
        </span>
      )),
      text: items.map((p) => String(p.area_sqft ?? "")),
      best: bestIndexes(
        items.map((p) => p.area_sqft),
        "max",
      ),
      bestNote: "Largest",
    },
    {
      label: "Size",
      cells: items.map(
        (p) =>
          p.dimensions_text ??
          (p.length_ft && p.width_ft
            ? `${formatNumber(p.length_ft)} × ${formatNumber(p.width_ft)} ft`
            : "—"),
      ),
      text: items.map(
        (p) => p.dimensions_text ?? `${p.length_ft}x${p.width_ft}`,
      ),
    },
    {
      label: "Type",
      cells: items.map((p) => p.type_name),
      text: items.map((p) => p.type_name),
    },
    {
      label: "Place",
      cells: items.map((p) =>
        [p.locality, p.city, p.district !== p.city ? p.district : null]
          .filter(Boolean)
          .join(", "),
      ),
      text: items.map((p) => `${p.locality}${p.city}`),
    },
    {
      label: "Road",
      cells: items.map((p) =>
        p.road_width_ft == null
          ? "—"
          : `${formatNumber(p.road_width_ft)} ft road`,
      ),
      text: items.map((p) => String(p.road_width_ft ?? "")),
      best: bestIndexes(
        items.map((p) => p.road_width_ft),
        "max",
      ),
      bestNote: "Widest road",
    },
    {
      label: "Facing",
      cells: items.map((p) =>
        p.facing ? (facingLabels[p.facing] ?? p.facing) : "—",
      ),
      text: items.map((p) => p.facing ?? ""),
    },
    {
      label: "Corner plot",
      cells: items.map((p) => (p.is_corner ? "Yes" : "No")),
      text: items.map((p) => String(p.is_corner)),
    },
    {
      label: "Water",
      cells: items.map((p) =>
        p.water_available && p.water_source
          ? `Yes — ${p.water_source}`
          : yesNo(p.water_available),
      ),
      text: items.map((p) => `${p.water_available}${p.water_source}`),
    },
    {
      label: "Electricity",
      cells: items.map((p) => yesNo(p.electricity_available)),
      text: items.map((p) => String(p.electricity_available)),
    },
    {
      label: "Approval",
      cells: items.map((p) => (
        <span key={p.id}>
          {approvalLabels[p.approval_type] ?? p.approval_type}
          {p.approval_number && (
            <span className="block text-xs text-muted">
              No. {p.approval_number}
            </span>
          )}
          {p.rera_number && (
            <span className="block text-xs text-muted">
              RERA {p.rera_number}
            </span>
          )}
        </span>
      )),
      text: items.map(
        (p) => `${p.approval_type}${p.approval_number}${p.rera_number}`,
      ),
    },
    {
      label: "Availability",
      cells: items.map((p) => availabilityLabels[p.availability]),
      text: items.map((p) => p.availability),
    },
    {
      label: "Amenities",
      cells: items.map((p) =>
        p.amenities.length ? (
          <ul key={p.id} className="space-y-0.5">
            {p.amenities.map((name) => (
              <li key={name}>{name}</li>
            ))}
          </ul>
        ) : (
          "—"
        ),
      ),
      text: items.map((p) => p.amenities.join("|")),
    },
    {
      label: "Highlights",
      cells: items.map((p) =>
        p.highlights.length ? (
          <ul key={p.id} className="list-disc space-y-0.5 pl-4">
            {p.highlights.map((text) => (
              <li key={text}>{text}</li>
            ))}
          </ul>
        ) : (
          "—"
        ),
      ),
      text: items.map((p) => p.highlights.join("|")),
    },
  ];

  const distances = items.map((p) =>
    items
      .filter((other) => other.id !== p.id)
      .map((other) => ({ code: other.code, km: distanceKm(p, other) }))
      .filter((d): d is { code: string; km: number } => d.km != null),
  );
  if (distances.some((list) => list.length > 0)) {
    rows.push({
      label: "Distance apart",
      cells: distances.map((list, i) =>
        list.length ? (
          <ul key={i} className="space-y-0.5">
            {list.map((d) => (
              <li key={d.code}>
                {formatDistance(d.km)} from {d.code}
              </li>
            ))}
          </ul>
        ) : (
          "—"
        ),
      ),
      // Never hidden as "the same": each column lists the others.
      text: distances.map((_, i) => String(i)),
    });
  }
  return rows;
}
