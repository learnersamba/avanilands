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
              className="aspect-[16/9] w-full rounded-2xl object-cover"
            />
          )}
          {!isPlaceholder(about.intro) &&
            paragraphs(about.intro).map((text) => <p key={text}>{text}</p>)}
        </div>
        <div className="space-y-4">
          {!isPlaceholder(about.mission) && (
            <div className="rounded-2xl bg-white p-6 ring-1 ring-line">
              <h2 className="font-serif text-xl text-forest">Our mission</h2>
              <p className="mt-2 text-ink/80">{about.mission}</p>
            </div>
          )}
          {!isPlaceholder(about.vision) && (
            <div className="rounded-2xl bg-white p-6 ring-1 ring-line">
              <h2 className="font-serif text-xl text-forest">Our vision</h2>
              <p className="mt-2 text-ink/80">{about.vision}</p>
            </div>
          )}
        </div>
      </Container>

      <section className="bg-white py-16">
        <Container>
          <SectionHeading eyebrow="Values" title="What we stand for" />
          <div className="mt-10 grid gap-6 sm:grid-cols-3">
            {about.values.map((value) => (
              <div
                key={value.title}
                className="rounded-2xl border border-line p-6"
              >
                <h3 className="font-serif text-xl text-forest">
                  {value.title}
                </h3>
                <p className="mt-2 text-ink/75">{value.text}</p>
              </div>
            ))}
          </div>
        </Container>
      </section>

      <Container className="py-16">
        <SectionHeading eyebrow="How we work" title="Why buyers choose us" />
        <div className="mt-10 grid gap-6 sm:grid-cols-2 lg:grid-cols-4">
          {whyUs.map((item) => {
            const Icon = contentIcons[item.icon] ?? contentIcons.badge;
            return (
              <div
                key={item.title}
                className="rounded-2xl border border-line bg-white p-6"
              >
                <Icon className="h-7 w-7 text-sand" aria-hidden />
                <h3 className="mt-3 font-serif text-lg text-forest">
                  {item.title}
                </h3>
                <p className="mt-2 text-sm text-ink/75">{item.text}</p>
              </div>
            );
          })}
        </div>
      </Container>
      <ContactBand />
    </>
  );
}
