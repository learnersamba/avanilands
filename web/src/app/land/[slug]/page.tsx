import {
  ArrowLeftRight,
  BadgeCheck,
  Building2,
  Compass,
  CornerDownRight,
  Droplets,
  FileText,
  Hash,
  Map as MapIcon,
  MapPin,
  MessageCircle,
  Phone,
  Download,
  Ruler,
  Zap,
} from "lucide-react";
import type { Metadata } from "next";
import Link from "next/link";
import { notFound } from "next/navigation";
import { Suspense, type ReactNode } from "react";

import { JsonLd } from "@/components/json-ld";
import { PhotoGallery } from "@/components/property/photo-gallery";
import { PropertyMap } from "@/components/property/property-map";
import { UploadedVideo, YouTubeVideo } from "@/components/property/property-video";
import { PropertyGrid } from "@/components/property-card";
import { RecordView } from "@/components/account/record-view";
import { SaveButton } from "@/components/account/save-button";
import { CompareButton } from "@/components/compare/compare-button";
import { EnquiryForm } from "@/components/enquiry/enquiry-form";
import { ContactTabs } from "@/components/site-visit/contact-tabs";
import { SiteVisitForm } from "@/components/site-visit/site-visit-form";
import { TrackedLink } from "@/components/enquiry/tracked-link";
import { buttonClasses, Container, StatusBadge } from "@/components/ui";
import {
  getPropertyPage,
  getPublishedSlugs,
  getRelatedProperties,
  getSiteSettings,
} from "@/lib/data";
import {
  approvalLabels,
  digits,
  facingLabels,
  formatArea,
  formatBytes,
  formatNumber,
  formatRupees,
  formatRupeesShort,
  formatSqft,
  unitLabel,
  whatsappLink,
} from "@/lib/format";
import { env } from "@/lib/env";
import { mediaUrl } from "@/lib/media";
import { breadcrumbJsonLd, listingJsonLd } from "@/lib/structured-data";

export async function generateStaticParams() {
  const slugs = await getPublishedSlugs();
  return slugs.map((slug) => ({ slug }));
}

export async function generateMetadata(props: PageProps<"/land/[slug]">): Promise<Metadata> {
  const { slug } = await props.params;
  const page = await getPropertyPage(slug);
  if (!page) return { title: "Property not found", robots: { index: false } };
  const p = page.property;
  const title = p.seo_title ?? p.title;
  const price = p.price_type === "total" && p.price != null ? ` · ${formatRupeesShort(p.price)}` : "";
  const description =
    p.seo_description ??
    `${formatArea(p.area_value, p.area_unit)} ${p.type_name.toLowerCase()} in ${[p.locality, p.city].filter(Boolean).join(", ")}${price}. ${p.description ?? ""}`
      .trim()
      .slice(0, 160);
  const image = p.cover_large ? mediaUrl(p.cover_large) : undefined;
  return {
    title,
    description,
    alternates: { canonical: `/land/${p.slug}` },
    openGraph: {
      type: "website",
      title,
      description,
      url: `/land/${p.slug}`,
      ...(image && { images: [{ url: image, width: 2000, height: 1500, alt: p.cover_alt }] }),
    },
    twitter: { card: "summary_large_image", title, description, ...(image && { images: [image] }) },
  };
}

/**
 * A property page. Old links, archived and unknown properties are handled
 * before this renders (src/proxy.ts). The enquiry form sends from Phase 8.
 */
export default function PropertyPageRoute(props: PageProps<"/land/[slug]">) {
  return (
    <Suspense fallback={<PropertySkeleton />}>
      <PropertyContent params={props.params} />
    </Suspense>
  );
}

async function PropertyContent({ params }: { params: Promise<{ slug: string }> }) {
  const { slug } = await params;
  const [page, settings] = await Promise.all([getPropertyPage(slug), getSiteSettings()]);
  if (!page) notFound();
  const related = await getRelatedProperties(page.property);
  const p = page.property;
  const place = [p.locality, p.city, p.district !== p.city ? p.district : null].filter(Boolean).join(", ");
  const whatsappMessage = `Hello, I'm interested in ${p.code} — ${p.title}.`;
  const url = `${env.siteUrl}/land/${p.slug}`;

  return (
    <>
      <JsonLd
        data={listingJsonLd({
          ...p,
          url,
          images: page.photos.slice(0, 6).map((photo) => mediaUrl(photo.large)),
        })}
      />
      <JsonLd
        data={breadcrumbJsonLd([
          { name: "Home", url: env.siteUrl },
          { name: "Land for sale", url: `${env.siteUrl}/land` },
          { name: p.city, url: `${env.siteUrl}/land-for-sale/${p.location_slug}` },
          { name: p.title, url },
        ])}
      />

      <Container className="pt-6">
        <nav aria-label="Breadcrumb" className="text-sm text-muted">
          <ol className="flex flex-wrap items-center gap-2">
            <li><Link href="/" className="hover:text-forest">Home</Link></li>
            <li aria-hidden>/</li>
            <li><Link href="/land" className="hover:text-forest">Land for sale</Link></li>
            <li aria-hidden>/</li>
            <li><Link href={`/land-for-sale/${p.location_slug}`} className="hover:text-forest">{p.city}</Link></li>
            <li aria-hidden>/</li>
            <li className="text-ink">{p.code}</li>
          </ol>
        </nav>
      </Container>

      {p.availability !== "available" && (
        <Container className="pt-4">
          <div
            className={`rounded-xl px-5 py-4 text-sm font-medium ${
              p.availability === "reserved" ? "bg-reserved/10 text-reserved" : "bg-sold/10 text-sold"
            }`}
          >
            {p.availability === "reserved"
              ? "This property is reserved by another buyer. Ask us about similar land — we'll also let you know if it becomes available."
              : "This property has been sold. Have a look at similar land below."}
          </div>
        </Container>
      )}

      <Container className="pt-6">
        <PhotoGallery
          photos={page.photos.map((photo) => ({
            id: photo.id,
            alt: photo.alt,
            thumb: mediaUrl(photo.thumb),
            medium: mediaUrl(photo.medium),
            large: mediaUrl(photo.large),
          }))}
        />
      </Container>

      <Container className="grid gap-10 py-10 lg:grid-cols-[1fr_380px]">
        <div className="space-y-10">
          <header>
            <div className="flex flex-wrap items-center gap-3">
              <StatusBadge status={p.availability} />
              <span className="text-sm text-muted">{p.type_name} · {p.code}</span>
              <span className="ml-auto flex gap-2">
                <CompareButton pick={{ code: p.code, title: p.title, thumb: p.cover_thumb }} variant="page" />
                <SaveButton propertyId={p.id} code={p.code} variant="page" />
              </span>
            </div>
            <RecordView propertyId={p.id} />
            <h1 className="mt-3 font-serif text-3xl leading-tight text-ink sm:text-4xl">{p.title}</h1>
            <p className="mt-3 flex items-center gap-2 text-ink/75">
              <MapPin className="h-5 w-5 text-sand" aria-hidden /> {place}
            </p>
            <div className="mt-6 flex flex-wrap items-end gap-x-6 gap-y-2">
              <p className="font-serif text-4xl text-forest">
                {p.price_type === "on_request" || p.price == null ? "Price on request" : formatRupees(p.price)}
              </p>
              {p.price != null && p.price_type === "total" && (
                <p className="pb-1 text-muted">({formatRupeesShort(p.price)})</p>
              )}
              {p.price_per_unit != null && p.price_per_unit_unit && (
                <p className="pb-1 text-muted">
                  {formatRupees(p.price_per_unit)} / {unitLabel(p.price_per_unit_unit)}
                </p>
              )}
              {p.is_negotiable && (
                <span className="mb-1 rounded-full bg-sand-light px-3 py-1 text-xs font-semibold text-forest-dark">
                  Negotiable
                </span>
              )}
            </div>
          </header>

          <Section title="Overview">
            <dl className="grid grid-cols-2 gap-4 sm:grid-cols-3">
              <Fact icon={<Ruler />} label="Area" value={formatArea(p.area_value, p.area_unit)} note={p.area_unit === "sq_ft" ? undefined : formatSqft(p.area_sqft) ?? undefined} />
              {(p.length_ft || p.dimensions_text) && (
                <Fact
                  icon={<ArrowLeftRight />}
                  label="Dimensions"
                  value={p.length_ft && p.width_ft ? `${formatNumber(p.length_ft)} × ${formatNumber(p.width_ft)} ft` : (p.dimensions_text ?? "")}
                  note={p.length_ft && p.dimensions_text ? p.dimensions_text : undefined}
                />
              )}
              <Fact icon={<Building2 />} label="Type" value={p.type_name} />
              {p.facing && <Fact icon={<Compass />} label="Facing" value={facingLabels[p.facing] ?? p.facing} />}
              {p.road_width_ft && <Fact icon={<MapIcon />} label="Road width" value={`${formatNumber(p.road_width_ft)} ft`} />}
              {p.is_corner && <Fact icon={<CornerDownRight />} label="Plot" value="Corner plot" />}
              {p.water_available != null && (
                <Fact icon={<Droplets />} label="Water" value={p.water_available ? "Available" : "Not available"} note={p.water_source ?? undefined} />
              )}
              {p.electricity_available != null && (
                <Fact icon={<Zap />} label="Electricity" value={p.electricity_available ? "Available" : "Not available"} />
              )}
              <Fact icon={<BadgeCheck />} label="Approval" value={approvalLabels[p.approval_type] ?? p.approval_type} note={p.approval_number ?? undefined} />
              {p.rera_number && <Fact icon={<Hash />} label="RERA number" value={p.rera_number} />}
            </dl>
          </Section>

          {p.highlights.length > 0 && (
            <Section title="Highlights">
              <ul className="grid gap-3 sm:grid-cols-2">
                {p.highlights.map((highlight) => (
                  <li key={highlight} className="flex items-start gap-3 rounded-xl bg-white p-4 ring-1 ring-line">
                    <BadgeCheck className="mt-0.5 h-5 w-5 shrink-0 text-sand" aria-hidden />
                    {highlight}
                  </li>
                ))}
              </ul>
            </Section>
          )}

          {p.description && (
            <Section title="About this land">
              <div className="space-y-4 leading-relaxed text-ink/80">
                {p.description.split(/\n{2,}/).map((paragraph) => (
                  <p key={paragraph.slice(0, 40)}>{paragraph}</p>
                ))}
              </div>
            </Section>
          )}

          {page.videos.length > 0 && (
            <Section title="Video">
              {page.videos.slice(0, 1).map((video) =>
                video.kind === "youtube" && video.youtube_id ? (
                  <YouTubeVideo key={video.id} id={video.youtube_id} title={video.title ?? `Video of ${p.title}`} />
                ) : (
                  <UploadedVideo
                    key={video.id}
                    src={mediaUrl(video.storage_path!)}
                    poster={p.cover_large ? mediaUrl(p.cover_large) : undefined}
                    title={video.title ?? `Video of ${p.title}`}
                  />
                ),
              )}
            </Section>
          )}

          {page.amenities.length > 0 && (
            <Section title="Amenities">
              <ul className="flex flex-wrap gap-2">
                {page.amenities.map((amenity) => (
                  <li key={amenity} className="rounded-full bg-white px-4 py-2 text-sm ring-1 ring-line">{amenity}</li>
                ))}
              </ul>
            </Section>
          )}

          <Section title="Location">
            {p.latitude != null && p.longitude != null ? (
              <>
                <PropertyMap lat={p.latitude} lng={p.longitude} exact={p.show_exact_location} label={place} />
                <div className="mt-3 flex flex-wrap items-center justify-between gap-3 text-sm">
                  <p className="text-muted">
                    {p.show_exact_location
                      ? place
                      : "The circle shows the area (about 1 km). We share the exact location when you enquire."}
                  </p>
                  {p.show_exact_location && (
                    <a
                      href={`https://www.google.com/maps/dir/?api=1&destination=${p.latitude},${p.longitude}`}
                      target="_blank"
                      rel="noopener"
                      className="inline-flex items-center gap-1.5 font-semibold text-forest hover:underline"
                    >
                      <MapPin className="h-4 w-4" aria-hidden /> Get directions
                    </a>
                  )}
                </div>
              </>
            ) : (
              <div className="bg-contours flex aspect-[16/9] flex-col items-center justify-center rounded-2xl bg-forest px-6 text-center text-white">
                <MapPin className="h-10 w-10 text-sand" aria-hidden />
                <p className="mt-3 font-serif text-xl">{place}</p>
                <p className="mt-1 text-sm text-white/70">Map location not shared yet — ask us for directions.</p>
              </div>
            )}
            {page.nearby.length > 0 && (
              <ul className="mt-6 divide-y divide-line rounded-2xl bg-white ring-1 ring-line">
                {page.nearby.map((place) => (
                  <li key={place.id} className="flex items-center justify-between px-5 py-3 text-sm">
                    <span>{place.name}</span>
                    {place.distance_km != null && <span className="text-muted">{formatNumber(place.distance_km)} km</span>}
                  </li>
                ))}
              </ul>
            )}
          </Section>

          <Section title="Documents & approvals">
            <div className="rounded-2xl bg-white p-5 ring-1 ring-line">
              <p className="font-medium">{approvalLabels[p.approval_type] ?? p.approval_type}
                {p.approval_number && <span className="text-muted"> · {p.approval_number}</span>}
              </p>
              {p.legal_notes && <p className="mt-2 text-ink/75">{p.legal_notes}</p>}
              {page.documents.length > 0 && (
                <ul className="mt-4 space-y-2">
                  {page.documents.map((document) => (
                    <li key={document.id}>
                      <a
                        href={`/api/documents/${document.id}`}
                        rel="nofollow"
                        className="inline-flex items-center gap-3 py-1 text-sm font-medium text-forest hover:underline"
                      >
                        <FileText className="h-5 w-5 text-sand" aria-hidden />
                        {document.title}
                        <span className="font-normal text-muted">
                          ({document.mime_type === "application/pdf" ? "PDF" : "Image"}, {formatBytes(document.size_bytes)})
                        </span>
                        <Download className="h-4 w-4" aria-hidden />
                      </a>
                    </li>
                  ))}
                </ul>
              )}
              <p className="mt-4 text-sm text-muted">Full documents are shared for your lawyer to verify before booking.</p>
            </div>
          </Section>
        </div>

        <aside id="enquire" className="scroll-mt-24 lg:sticky lg:top-24 lg:self-start" aria-label="Contact about this property">
          <span id="visit" className="block scroll-mt-24" aria-hidden />
          <div className="rounded-2xl bg-white p-6 shadow-sm ring-1 ring-line">
            <h2 className="font-serif text-2xl text-forest">Interested?</h2>
            {p.availability === "sold" ? (
              <p className="mt-2 text-sm text-ink/80">
                This property has been sold. Call or WhatsApp us and we&apos;ll suggest similar land.
              </p>
            ) : (
              <>
                <p className="mt-1 text-sm text-muted">
                  {p.availability === "reserved"
                    ? `${p.code} is reserved — ask us about similar land or to be told if it frees up.`
                    : `Ask about ${p.code} or arrange a site visit.`}
                </p>
                <div className="mt-5">
                  <ContactTabs
                    enquire={
                      <EnquiryForm
                        idPrefix="property"
                        source="property_page"
                        propertyId={p.id}
                        propertyCode={p.code}
                        defaultMessage={`I'm interested in ${p.code}. Please contact me.`}
                        whatsappHref={settings.whatsapp ? whatsappLink(settings.whatsapp, whatsappMessage) : null}
                      />
                    }
                    visit={
                      <SiteVisitForm
                        idPrefix="visit"
                        propertyId={p.id}
                        propertyCode={p.code}
                        settings={settings}
                        whatsappHref={settings.whatsapp ? whatsappLink(settings.whatsapp, whatsappMessage) : null}
                      />
                    }
                  />
                </div>
                {p.availability === "available" && (
                  <Link
                    href={`/book/${p.code}`}
                    className="mt-5 block rounded-xl border border-sand bg-sand-light/60 px-4 py-3 text-sm hover:border-forest"
                  >
                    <span className="font-semibold text-forest">Decided? Request to book {p.code} →</span>
                    <span className="block text-ink/70">No payment now — our team calls you first.</span>
                  </Link>
                )}
              </>
            )}
            <div className="mt-5 grid grid-cols-2 gap-3">
              {settings.phone && (
                <TrackedLink channel="call" propertyId={p.id} href={`tel:+${digits(settings.phone)}`} className={buttonClasses("outline")}>
                  <Phone className="h-4 w-4" aria-hidden /> Call
                </TrackedLink>
              )}
              {settings.whatsapp && (
                <TrackedLink
                  channel="whatsapp"
                  propertyId={p.id}
                  href={whatsappLink(settings.whatsapp, whatsappMessage)}
                  target="_blank"
                  rel="noopener"
                  className={buttonClasses("gold")}
                >
                  <MessageCircle className="h-4 w-4" aria-hidden /> WhatsApp
                </TrackedLink>
              )}
            </div>
          </div>
        </aside>
      </Container>

      {related.length > 0 && (
        <section className="border-t border-line bg-white py-14" aria-labelledby="related-title">
          <Container>
            <h2 id="related-title" className="font-serif text-3xl text-forest">Similar land</h2>
            <div className="mt-8">
              <PropertyGrid properties={related} />
            </div>
          </Container>
        </section>
      )}

      {/* Phone: call / WhatsApp / enquire always in reach. */}
      <div id="property-action-bar" className={`fixed inset-x-0 bottom-0 z-30 grid ${p.availability === "sold" ? "grid-cols-3" : "grid-cols-4"} gap-2 border-t border-line bg-white p-3 lg:hidden`}>
        {settings.phone && (
          <TrackedLink channel="call" propertyId={p.id} href={`tel:+${digits(settings.phone)}`} className={buttonClasses("outline", "px-2")}>
            <Phone className="h-4 w-4" aria-hidden /> Call
          </TrackedLink>
        )}
        {settings.whatsapp && (
          <TrackedLink
            channel="whatsapp"
            propertyId={p.id}
            href={whatsappLink(settings.whatsapp, whatsappMessage)}
            target="_blank"
            rel="noopener"
            className={buttonClasses("gold", "px-2")}
          >
            <MessageCircle className="h-4 w-4" aria-hidden /> WhatsApp
          </TrackedLink>
        )}
        <a href="#enquire" className={buttonClasses("outline", "px-2")}>
          Enquire
        </a>
        {p.availability !== "sold" && (
          <a href="#visit" className={buttonClasses("primary", "px-2")}>
            Visit
          </a>
        )}
      </div>
      <div className="h-20 lg:hidden" aria-hidden />
    </>
  );
}

function Section({ title, children }: { title: string; children: ReactNode }) {
  return (
    <section>
      <h2 className="mb-5 font-serif text-2xl text-forest">{title}</h2>
      {children}
    </section>
  );
}

function Fact({ icon, label, value, note }: { icon: ReactNode; label: string; value: string; note?: string }) {
  return (
    <div className="rounded-xl bg-white p-4 ring-1 ring-line">
      <dt className="flex items-center gap-2 text-xs font-medium uppercase tracking-wide text-muted [&_svg]:h-4 [&_svg]:w-4 [&_svg]:text-sand">
        {icon} {label}
      </dt>
      <dd className="mt-1.5 font-semibold text-ink">{value}</dd>
      {note && <dd className="text-xs text-muted">{note}</dd>}
    </div>
  );
}

/** Same shape as the page, so nothing jumps when the content arrives. */
function PropertySkeleton() {
  return (
    <div aria-busy="true" aria-label="Loading property">
      <Container className="pt-6">
        <div className="h-5 w-64 animate-pulse rounded bg-line" />
      </Container>
      <Container className="pt-6">
        <div className="aspect-[4/3] w-full animate-pulse rounded-2xl bg-line lg:aspect-[21/9]" />
      </Container>
      <Container className="grid gap-10 py-10 lg:grid-cols-[1fr_380px]">
        <div className="space-y-6">
          <div className="h-10 w-3/4 animate-pulse rounded bg-line" />
          <div className="h-6 w-1/2 animate-pulse rounded bg-line" />
          <div className="h-12 w-1/3 animate-pulse rounded bg-line" />
          <div className="h-[1400px] animate-pulse rounded-2xl bg-white ring-1 ring-line" />
        </div>
        <div className="hidden h-[520px] animate-pulse rounded-2xl bg-white ring-1 ring-line lg:block" />
      </Container>
    </div>
  );
}
