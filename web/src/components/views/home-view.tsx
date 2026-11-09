import { ArrowRight, CheckCircle2, Quote, Star } from "lucide-react";
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
      {/* Hero */}
      <section className="bg-contours relative overflow-hidden bg-forest-dark text-white">
        {hero.image_path && (
          // eslint-disable-next-line @next/next/no-img-element
          <img
            src={storageUrl("site-assets", hero.image_path)}
            alt=""
            fetchPriority="high"
            className="absolute inset-0 h-full w-full object-cover opacity-35"
          />
        )}
        <div
          className="absolute inset-0 bg-[radial-gradient(ellipse_at_top_right,rgba(200,161,90,0.25),transparent_55%)]"
          aria-hidden
        />
        <Container className="relative py-20 sm:py-28">
          <p className="text-xs font-semibold uppercase tracking-[0.25em] text-sand">
            {hero.eyebrow}
          </p>
          <h1 className="mt-5 max-w-3xl font-serif text-4xl leading-[1.1] sm:text-6xl">
            {hero.title}
          </h1>
          <p className="mt-6 max-w-2xl text-lg text-white/80">
            {hero.subtitle}
          </p>
          <div className="mt-10 max-w-5xl">
            <HeroSearch locations={locations} types={types} />
          </div>
        </Container>
      </section>

      {/* Trust strip */}
      <section
        aria-label="Why buyers trust us"
        className="border-b border-line bg-white"
      >
        <Container className="grid grid-cols-2 gap-6 py-8 lg:grid-cols-4">
          {trustPoints.map((point) => {
            const Icon = contentIcons[point.icon] ?? contentIcons.badge;
            return (
              <div key={point.title} className="flex items-start gap-3">
                <span className="flex h-10 w-10 shrink-0 items-center justify-center rounded-full bg-sand-light text-forest">
                  <Icon className="h-5 w-5" aria-hidden />
                </span>
                <div>
                  <p className="font-semibold text-ink">{point.title}</p>
                  <p className="text-sm text-muted">{point.text}</p>
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
                className="flex overflow-hidden rounded-2xl bg-sand-light ring-1 ring-sand/40 md:last:odd:col-span-2"
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
                <SectionHeading
                  eyebrow="Featured"
                  title="Handpicked land, ready to visit"
                />
              </div>
              <ButtonLink href="/land" variant="outline">
                See all land <ArrowRight className="h-4 w-4" aria-hidden />
              </ButtonLink>
            </div>
            <div className="mt-10">
              <PropertyGrid properties={featured} />
            </div>
          </Container>
        </section>
      )}

      {/* Popular locations */}
      {popular.length > 0 && (
        <section className="bg-white py-20" aria-labelledby="locations-title">
          <Container>
            <div id="locations-title">
              <SectionHeading
                eyebrow="Locations"
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

      {/* Why choose us */}
      <section className="py-20" aria-labelledby="why-title">
        <Container>
          <div id="why-title">
            <SectionHeading
              align="center"
              eyebrow="Why us"
              title="Buying land should feel safe"
            />
          </div>
          <div className="mt-12 grid gap-6 sm:grid-cols-2 lg:grid-cols-4">
            {whyChooseUs.map((item) => {
              const Icon = contentIcons[item.icon] ?? contentIcons.badge;
              return (
                <div
                  key={item.title}
                  className="rounded-2xl border border-line bg-white p-6"
                >
                  <Icon className="h-8 w-8 text-sand" aria-hidden />
                  <h3 className="mt-4 font-serif text-xl text-forest">
                    {item.title}
                  </h3>
                  <p className="mt-2 text-sm leading-relaxed text-ink/75">
                    {item.text}
                  </p>
                </div>
              );
            })}
          </div>
        </Container>
      </section>

      {/* Verification */}
      <section
        className="bg-contours bg-forest-dark py-20 text-white"
        aria-labelledby="verify-title"
      >
        <Container className="grid items-center gap-12 lg:grid-cols-2">
          <div id="verify-title">
            <SectionHeading
              dark
              eyebrow="Verification"
              title="Every property is checked before it is listed"
              subtitle="We only sell land we would buy ourselves. Before a property appears here, our team and lawyers check:"
            />
          </div>
          <ul className="space-y-4">
            {verificationChecks.map((check) => (
              <li
                key={check}
                className="flex gap-3 rounded-xl bg-white/5 p-4 ring-1 ring-white/10"
              >
                <CheckCircle2
                  className="mt-0.5 h-5 w-5 shrink-0 text-sand"
                  aria-hidden
                />
                <span className="text-white/90">{check}</span>
              </li>
            ))}
          </ul>
        </Container>
      </section>

      {/* How buying works */}
      <section className="py-20" aria-labelledby="steps-title">
        <Container>
          <div id="steps-title">
            <SectionHeading
              align="center"
              eyebrow="How it works"
              title="From first call to registration"
            />
          </div>
          <ol className="mt-12 grid gap-6 md:grid-cols-5">
            {buyingSteps.map((step, index) => (
              <li
                key={step.title}
                className="relative rounded-2xl border border-line bg-white p-6"
              >
                <span className="flex h-10 w-10 items-center justify-center rounded-full bg-forest font-serif text-lg text-sand">
                  {index + 1}
                </span>
                <h3 className="mt-4 font-semibold text-ink">{step.title}</h3>
                <p className="mt-1 text-sm text-ink/75">{step.text}</p>
              </li>
            ))}
          </ol>
        </Container>
      </section>

      {/* Recently added */}
      {recentOnly.length > 0 && (
        <section className="bg-white py-20" aria-labelledby="recent-title">
          <Container>
            <div id="recent-title">
              <SectionHeading eyebrow="New" title="Recently added" />
            </div>
            <div className="mt-10">
              <PropertyGrid properties={recentOnly} />
            </div>
          </Container>
        </section>
      )}

      {/* Testimonials: only real customers who agreed to be shown (admin panel). */}
      {testimonials.length > 0 && (
        <section className="py-20" aria-labelledby="testimonials-title">
          <Container>
            <div id="testimonials-title">
              <SectionHeading
                align="center"
                eyebrow="Our buyers"
                title="What buyers say"
              />
            </div>
            <div className="mt-12 grid gap-6 md:grid-cols-2 lg:grid-cols-3">
              {testimonials.map((t) => (
                <figure
                  key={t.id}
                  className="flex flex-col rounded-2xl border border-line bg-white p-6"
                >
                  <Quote className="h-7 w-7 text-sand" aria-hidden />
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
                  <blockquote className="mt-3 flex-1 leading-relaxed text-ink/85">
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
      <section className="py-20" aria-labelledby="faq-title">
        <Container className="grid gap-10 lg:grid-cols-[1fr_1.5fr]">
          <div id="faq-title">
            <SectionHeading eyebrow="Questions" title="Things buyers ask us" />
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
