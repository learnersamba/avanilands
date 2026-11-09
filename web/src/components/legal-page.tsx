import { PageHero } from "@/components/page-hero";
import { Container } from "@/components/ui";
import { type LegalContent, paragraphs } from "@/lib/content";

export function LegalPage({
  content,
  path,
}: {
  content: LegalContent;
  path: string;
}) {
  return (
    <>
      <PageHero
        title={content.title}
        crumbs={[{ href: path, label: content.title }]}
      />
      <Container className="max-w-3xl py-14">
        {!content.final && (
          <p className="rounded-xl bg-sand-light/60 px-4 py-3 text-sm text-forest-dark">
            Draft text — to be replaced with the final wording from the
            company&apos;s legal advisor.
          </p>
        )}
        <div className="mt-8 space-y-8">
          {content.sections.map((section) => (
            <section key={section.heading}>
              <h2 className="font-serif text-2xl text-forest">
                {section.heading}
              </h2>
              {paragraphs(section.text).map((text) => (
                <p key={text} className="mt-3 leading-relaxed text-ink/80">
                  {text}
                </p>
              ))}
            </section>
          ))}
        </div>
      </Container>
    </>
  );
}
