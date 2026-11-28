import { ArrowRight, Building2, Check, House, LandPlot, Sprout, Star, TrendingUp } from "lucide-react";
import Link from "next/link";

import { ContactBand } from "@/components/contact-band";
import { FaqList } from "@/components/faq-list";
import { HeroSearch } from "@/components/hero-search";
import { contentIcons } from "@/components/icons";
import { LocationCard } from "@/components/location-card";
import { PropertyGrid } from "@/components/property-card";
import { ButtonLink, Container, SectionHeading } from "@/components/ui";
import type { Banner, Faq, SiteContent, Testimonial } from "@/lib/content";
import type {
  LocationSummary,
  PropertyCardData,
  PropertyType,
} from "@/lib/data";
import { storageUrl } from "@/lib/media";

/** An icon for each property type, matched on its slug. */
function typeIcon(slug: string) {
  if (/farm|agri/.test(slug)) return Sprout;
  if (/resid|villa|house/.test(slug)) return House;
  if (/commer|office|shop/.test(slug)) return Building2;
  if (/invest/.test(slug)) return TrendingUp;
  return LandPlot;
}

export type HomeData = {
  content: SiteContent;
  faqs: Faq[];
  testimonials: Testimonial[];
  banners: Banner[];
  featured: PropertyCardData[];
  recent: PropertyCardData[];
  locations: LocationSummary[];
  types: PropertyType[];
};

/** The home page, from content (published on the website, drafts in preview). */
export function HomeView({
  content,
  faqs,
  testimonials,
  banners,
  featured,
  recent,
  locations,
  types,
}: HomeData) {
  const {
    hero,
    trustPoints,
    whyUs: whyChooseUs,
    verification: verificationChecks,
    steps: buyingSteps,
  } = content;
  const homeFaqs = faqs.filter((faq) => faq.show_on_home).slice(0, 5);
  const popular = locations.filter((location) => location.is_popular);
  const featuredIds = new Set(featured.map((property) => property.id));
  const recentOnly = recent
    .filter((property) => !featuredIds.has(property.id))
    .slice(0, 3);

  return (
    <>
      {/* Hero: a full-width photo (Admin → Content → Hero image), headline and search. */}
      <section className="relative isolate overflow-hidden bg-forest-dark text-white">
        {hero.image_path ? (
          // eslint-disable-next-line @next/next/no-img-element
          <img
            src={storageUrl("site-assets", hero.image_path)}
            alt=""
            fetchPriority="high"
            className="absolute inset-0 -z-10 h-full w-full object-cover"
          />
        ) : (
          <div className="bg-contours absolute inset-0 -z-10" aria-hidden />
        )}
        {/* Darkens the left side so the headline stays readable on any photo. */}
        <div
          className="absolute inset-0 -z-10 bg-[linear-gradient(90deg,rgba(11,59,46,0.92)_0%,rgba(11,59,46,0.72)_45%,rgba(11,59,46,0.15)_100%)]"
          aria-hidden
        />
        <Container className="pb-28 pt-16 sm:pb-32 sm:pt-24 lg:pb-36 lg:pt-28">
          {hero.eyebrow && (
            <p className="font-heading text-xs font-semibold uppercase tracking-[0.18em] text-sand">{hero.eyebrow}</p>
          )}
          <h1 className="mt-4 max-w-2xl font-serif text-[2.6rem] leading-[1.06] sm:text-6xl lg:text-[4.1rem]">
            {hero.title}
          </h1>
          <p className="mt-5 max-w-lg text-lg leading-relaxed text-white/85">{hero.subtitle}</p>
          <div className="mt-9 max-w-4xl">
            <HeroSearch locations={locations} types={types} />
          </div>
        </Container>
      </section>

      {/* Property types, overlapping the hero like the mockup. */}
      {types.length > 0 && (
        <section aria-label="Browse by type" className="relative z-10 -mt-16">
          <Container>
            <ul className="grid grid-cols-2 overflow-hidden rounded-xl border border-line bg-white shadow-[0_20px_40px_-28px_rgba(11,59,46,0.5)] sm:grid-cols-4 sm:divide-x sm:divide-line">
              {types.slice(0, 4).map((type) => {
                const Icon = typeIcon(type.slug);
                return (
                  <li key={type.id}>
                    <Link
                      href={`/land?type=${type.seo_slug}`}
                      className="group flex flex-col items-center gap-2 px-4 py-6 text-center transition-colors hover:bg-paper"
                    >
                      <Icon className="h-8 w-8 text-forest-light transition-colors group-hover:text-forest-dark" strokeWidth={1.5} aria-hidden />
                      <span className="font-heading text-sm font-semibold text-forest-dark">{type.name}</span>
                    </Link>
                  </li>
                );
              })}
            </ul>
          </Container>
        </section>
      )}

      {/* Trust strip */}
      <section aria-label="Why buyers trust us" className="mt-10 border-y border-line bg-white">
        <Container className="grid grid-cols-2 gap-y-6 py-8 lg:grid-cols-4 lg:divide-x lg:divide-line">
          {trustPoints.map((point) => {
            const Icon = contentIcons[point.icon] ?? contentIcons.badge;
            return (
              <div key={point.title} className="flex items-start gap-3 pr-4 lg:px-6 lg:first:pl-0">
                <Icon className="mt-1 h-5 w-5 shrink-0 text-sand-dark" strokeWidth={1.5} aria-hidden />
                <div>
                  <p className="font-medium text-ink">{point.title}</p>
                  <p className="text-sm leading-snug text-muted">{point.text}</p>
                </div>
              </div>
            );
          })}
        </Container>
      </section>

      {/* Banners (promotional sections, scheduled in the admin panel) */}
      {banners.length > 0 && (
        <section aria-label="News and offers" className="pt-12">
          <Container className="grid gap-4 md:grid-cols-2">
            {banners.map((banner) => (
              <div
                key={banner.id}
                className="flex overflow-hidden rounded-lg bg-sand-light/60 ring-1 ring-sand/40 md:last:odd:col-span-2"
              >
                {banner.image_path && (
                  // eslint-disable-next-line @next/next/no-img-element
                  <img
                    src={storageUrl("site-assets", banner.image_path)}
                    alt=""
                    loading="lazy"
                    className="hidden w-40 shrink-0 object-cover sm:block"
                  />
                )}
                <div className="p-5">
                  <p className="font-serif text-xl text-forest">
                    {banner.title}
                  </p>
                  {banner.text && (
                    <p className="mt-1 text-sm text-ink/80">{banner.text}</p>
                  )}
                  {banner.link_url && (
                    <Link
                      href={banner.link_url}
                      {...(banner.link_url.startsWith("https://") && {
                        target: "_blank",
                        rel: "noopener",
                      })}
                      className="mt-3 inline-flex items-center gap-1 text-sm font-semibold text-forest hover:underline"
                    >
                      {banner.link_label || "Find out more"}{" "}
                      <ArrowRight className="h-4 w-4" aria-hidden />
                    </Link>
                  )}
                </div>
              </div>
            ))}
          </Container>
        </section>
      )}

      {/* Featured */}
      {featured.length > 0 && (
        <section className="py-20" aria-labelledby="featured-title">
          <Container>
            <div className="flex flex-wrap items-end justify-between gap-6">
              <div id="featured-title">
                <SectionHeading title="Featured Properties" />
              </div>
              <Link
                href="/land"
                className="inline-flex items-center gap-1.5 font-heading text-sm font-semibold text-forest-dark transition-[gap] hover:gap-2.5"
              >
                View All <ArrowRight className="h-4 w-4" aria-hidden />
              </Link>
            </div>
            <div className="mt-10">
              <PropertyGrid properties={featured} />
            </div>
          </Container>
        </section>
      )}

      {/* Popular locations */}
      {popular.length > 0 && (
        <section className="bg-white py-24" aria-labelledby="locations-title">
          <Container>
            <div id="locations-title">
              <SectionHeading
                title="Where we have land"
                subtitle="Growing towns along the coast and the new airport corridor."
              />
            </div>
            <div className="mt-10 grid gap-6 sm:grid-cols-2 lg:grid-cols-3">
              {popular.map((location) => (
                <LocationCard
                  key={location.id}
                  location={location}
                  href={`/land-for-sale/${location.slug}`}
                />
              ))}
            </div>
          </Container>
        </section>
      )}

      {/* Why choose us: an editorial list, heading on the left. */}
      <section className="py-24" aria-labelledby="why-title">
        <Container className="grid gap-12 lg:grid-cols-[0.8fr_1.2fr]">
          <div id="why-title">
            <SectionHeading title="Buying land should feel safe" />
          </div>
          <dl className="grid gap-x-12 sm:grid-cols-2">
            {whyChooseUs.map((item) => {
              const Icon = contentIcons[item.icon] ?? contentIcons.badge;
              return (
                <div key={item.title} className="border-t border-line py-7">
                  <dt className="flex items-center gap-3 font-serif text-[1.4rem] text-forest-dark">
                    <Icon className="h-5 w-5 shrink-0 text-sand-dark" strokeWidth={1.5} aria-hidden />
                    {item.title}
                  </dt>
                  <dd className="mt-2 leading-relaxed text-muted">{item.text}</dd>
                </div>
              );
            })}
          </dl>
        </Container>
      </section>

      {/* Verification: the checks, set out like a due-diligence document. */}
      <section className="bg-contours bg-forest-dark py-24 text-white" aria-labelledby="verify-title">
        <Container className="grid items-center gap-12 lg:grid-cols-[1fr_1.1fr]">
          <div id="verify-title">
            <SectionHeading
              dark
              title="Every property is checked before it is listed"
              subtitle="We only sell land we would buy ourselves. Before a property appears here, our team and lawyers check:"
            />
          </div>
          <div className="rounded-lg bg-paper p-6 text-ink shadow-[0_30px_60px_-30px_rgba(0,0,0,0.6)] sm:p-9">
            <div className="flex items-baseline justify-between gap-4 border-b border-ink/15 pb-4">
              <p className="font-serif text-xl text-forest-dark">Due-diligence checklist</p>
              <p className="text-sm text-muted">Done for every property</p>
            </div>
            <ul className="divide-y divide-dashed divide-ink/15">
              {verificationChecks.map((check) => (
                <li key={check} className="flex gap-4 py-3.5">
                  <span className="mt-0.5 flex h-5 w-5 shrink-0 items-center justify-center rounded-[3px] border border-forest bg-forest text-white">
                    <Check className="h-3.5 w-3.5" strokeWidth={2.5} aria-hidden />
                  </span>
                  <span className="leading-snug">{check}</span>
                </li>
              ))}
            </ul>
          </div>
        </Container>
      </section>

      {/* How buying works: a real sequence, so the steps are numbered. */}
      <section className="py-24" aria-labelledby="steps-title">
        <Container>
          <div id="steps-title">
            <SectionHeading title="From first call to registration" />
          </div>
          <ol className="mt-14 grid gap-10 md:grid-cols-5 md:gap-6">
            {buyingSteps.map((step, index) => (
              <li key={step.title} className="relative flex gap-5 md:block">
                {/* The line to the next step (down on phones, across on wider screens). */}
                {index < buyingSteps.length - 1 && (
                  <span
                    className="absolute left-5 top-10 h-full w-px bg-line md:left-10 md:top-5 md:h-px md:w-[calc(100%-1rem)]"
                    aria-hidden
                  />
                )}
                <span className="relative flex h-10 w-10 shrink-0 items-center justify-center rounded-full border border-sand bg-paper font-serif text-lg text-sand-dark tabular-nums">
                  {index + 1}
                </span>
                <div className="md:mt-6">
                  <h3 className="font-medium text-ink">{step.title}</h3>
                  <p className="mt-1.5 text-[0.95rem] leading-relaxed text-muted">{step.text}</p>
                </div>
              </li>
            ))}
          </ol>
        </Container>
      </section>

      {/* Recently added */}
      {recentOnly.length > 0 && (
        <section className="bg-white py-24" aria-labelledby="recent-title">
          <Container>
            <div id="recent-title">
              <SectionHeading title="Recently added" />
            </div>
            <div className="mt-10">
              <PropertyGrid properties={recentOnly} />
            </div>
          </Container>
        </section>
      )}

      {/* Testimonials: only real customers who agreed to be shown (admin panel). */}
      {testimonials.length > 0 && (
        <section className="py-24" aria-labelledby="testimonials-title">
          <Container>
            <div id="testimonials-title">
              <SectionHeading title="What buyers say" />
            </div>
            <div className="mt-12 grid gap-6 md:grid-cols-2 lg:grid-cols-3">
              {testimonials.map((t) => (
                <figure
                  key={t.id}
                  className="flex flex-col border-t border-sand pt-6"
                >
                  {t.rating != null && (
                    <p
                      className="mt-3 flex gap-0.5"
                      aria-label={`${t.rating} out of 5`}
                    >
                      {Array.from({ length: 5 }, (_, i) => (
                        <Star
                          key={i}
                          className={`h-4 w-4 ${i < t.rating! ? "fill-sand text-sand" : "text-line"}`}
                          aria-hidden
                        />
                      ))}
                    </p>
                  )}
                  <blockquote className="mt-3 flex-1 font-serif text-xl leading-normal text-ink">
                    “{t.quote}”
                  </blockquote>
                  <figcaption className="mt-5 flex items-center gap-3">
                    {t.photo_path && (
                      // eslint-disable-next-line @next/next/no-img-element
                      <img
                        src={storageUrl("site-assets", t.photo_path)}
                        alt=""
                        loading="lazy"
                        width={44}
                        height={44}
                        className="h-11 w-11 rounded-full object-cover"
                      />
                    )}
                    <span>
                      <span className="block font-semibold text-ink">
                        {t.name}
                      </span>
                      {t.place && (
                        <span className="block text-sm text-muted">
                          {t.place}
                        </span>
                      )}
                    </span>
                  </figcaption>
                </figure>
              ))}
            </div>
          </Container>
        </section>
      )}

      {/* FAQ */}
      <section className="py-24" aria-labelledby="faq-title">
        <Container className="grid gap-10 lg:grid-cols-[1fr_1.5fr]">
          <div id="faq-title">
            <SectionHeading title="Things buyers ask us" />
            <ButtonLink href="/faq" variant="outline" className="mt-6">
              All questions <ArrowRight className="h-4 w-4" aria-hidden />
            </ButtonLink>
          </div>
          <FaqList
            items={homeFaqs.map((faq) => ({ q: faq.question, a: faq.answer }))}
          />
        </Container>
      </section>

      <ContactBand />
    </>
  );
}
