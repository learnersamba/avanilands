import { Mail, MessageCircle, Phone } from "lucide-react";

import { ButtonAnchor, ButtonLink, Container } from "@/components/ui";
import { getSiteSettings } from "@/lib/data";
import { digits, whatsappLink } from "@/lib/format";

/** "Talk to us" band near the bottom of most pages. */
export async function ContactBand() {
  const settings = await getSiteSettings();
  return (
    <section className="bg-contours bg-forest py-16 text-white" aria-labelledby="contact-band-title">
      <Container className="flex flex-col items-start justify-between gap-8 lg:flex-row lg:items-center">
        <div className="max-w-xl">
          <h2 id="contact-band-title" className="font-serif text-3xl sm:text-4xl">
            Found something you like?
          </h2>
          <p className="mt-3 text-white/80">
            Call, WhatsApp or send an enquiry. We reply the same day and can show you the land this week.
          </p>
        </div>
        <div className="flex flex-wrap gap-3">
          {settings.phone && (
            <ButtonAnchor href={`tel:+${digits(settings.phone)}`} variant="light">
              <Phone className="h-4 w-4" aria-hidden /> Call {settings.phone}
            </ButtonAnchor>
          )}
          {settings.whatsapp && (
            <ButtonAnchor href={whatsappLink(settings.whatsapp)} target="_blank" rel="noopener" variant="gold">
              <MessageCircle className="h-4 w-4" aria-hidden /> WhatsApp us
            </ButtonAnchor>
          )}
          <ButtonLink href="/contact" variant="light">
            <Mail className="h-4 w-4" aria-hidden /> Send an enquiry
          </ButtonLink>
        </div>
      </Container>
    </section>
  );
}
