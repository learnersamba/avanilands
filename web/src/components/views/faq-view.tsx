import { ContactBand } from "@/components/contact-band";
import { FaqList } from "@/components/faq-list";
import { PageHero } from "@/components/page-hero";
import { Container } from "@/components/ui";
import { type Faq, isPlaceholder } from "@/lib/content";

export function FaqView({ faqs }: { faqs: Faq[] }) {
  // Search engines can show these answers directly (schema.org FAQPage).
  const structuredData = {
    "@context": "https://schema.org",
    "@type": "FAQPage",
    mainEntity: faqs
      .filter((faq) => faq.is_published !== false && !isPlaceholder(faq.answer))
      .map((faq) => ({
        "@type": "Question",
        name: faq.question,
        acceptedAnswer: { "@type": "Answer", text: faq.answer },
      })),
  };
  return (
    <>
      <script
        type="application/ld+json"
        dangerouslySetInnerHTML={{
          __html: JSON.stringify(structuredData).replace(/</g, "\\u003c"),
        }}
      />
      <PageHero
        title="Questions & answers"
        subtitle="Can't find your answer? Call or WhatsApp us — we're happy to help."
        crumbs={[{ href: "/faq", label: "Questions" }]}
      />
      <Container className="max-w-3xl py-14">
        <FaqList
          items={faqs.map((faq) => ({
            q:
              faq.is_published === false
                ? `${faq.question} (hidden — not on the website)`
                : faq.question,
            a: faq.answer,
          }))}
        />
      </Container>
      <ContactBand />
    </>
  );
}
