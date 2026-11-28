import { ContactBand } from "@/components/contact-band";
import { contentIcons } from "@/components/icons";
import { PageHero } from "@/components/page-hero";
import { Container, SectionHeading } from "@/components/ui";
import { isPlaceholder, paragraphs, type SiteContent } from "@/lib/content";
import { storageUrl } from "@/lib/media";

export function AboutView({ content }: { content: SiteContent }) {
  const { about, whyUs } = content;
  return (
    <>
      <PageHero
        title="About us"
        crumbs={[{ href: "/about", label: "About us" }]}
      />
      <Container className="grid gap-12 py-16 lg:grid-cols-[1.4fr_1fr]">
        <div className="space-y-6 text-lg leading-relaxed text-ink/80">
          {about.image_path && (
            // eslint-disable-next-line @next/next/no-img-element
            <img
              src={storageUrl("site-assets", about.image_path)}
              alt=""
              className="aspect-[16/9] w-full rounded-xl object-cover"
            />
          )}
          {!isPlaceholder(about.intro) &&
            paragraphs(about.intro).map((text) => <p key={text}>{text}</p>)}
        </div>
        <div className="space-y-4">
          {!isPlaceholder(about.mission) && (
            <div className="rounded-xl bg-white p-6 ring-1 ring-line">
              <h2 className="font-serif text-[1.5rem] text-forest-dark">Our mission</h2>
              <p className="mt-2 text-ink/80">{about.mission}</p>
            </div>
          )}
          {!isPlaceholder(about.vision) && (
            <div className="rounded-xl bg-white p-6 ring-1 ring-line">
              <h2 className="font-serif text-[1.5rem] text-forest-dark">Our vision</h2>
              <p className="mt-2 text-ink/80">{about.vision}</p>
            </div>
          )}
        </div>
      </Container>

      <section className="bg-white py-20">
        <Container>
          <SectionHeading title="What we stand for" />
          <div className="mt-10 grid gap-x-12 sm:grid-cols-3">
            {about.values.map((value) => (
              <div key={value.title} className="border-t border-sand py-6">
                <h3 className="font-serif text-[1.5rem] text-forest-dark">{value.title}</h3>
                <p className="mt-2 leading-relaxed text-muted">{value.text}</p>
              </div>
            ))}
          </div>
        </Container>
      </section>

      <Container className="py-20">
        <SectionHeading title="Why buyers choose us" />
        <dl className="mt-10 grid gap-x-12 sm:grid-cols-2 lg:grid-cols-4">
          {whyUs.map((item) => {
            const Icon = contentIcons[item.icon] ?? contentIcons.badge;
            return (
              <div key={item.title} className="border-t border-line py-6">
                <dt className="flex items-center gap-3 font-serif text-[1.3rem] text-forest-dark">
                  <Icon className="h-5 w-5 shrink-0 text-sand-dark" strokeWidth={1.5} aria-hidden />
                  {item.title}
                </dt>
                <dd className="mt-2 leading-relaxed text-muted">{item.text}</dd>
              </div>
            );
          })}
        </dl>
      </Container>
      <ContactBand />
    </>
  );
}
