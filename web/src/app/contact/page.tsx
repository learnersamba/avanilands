import { Clock, Mail, MapPin, MessageCircle, Phone } from "lucide-react";
import type { Metadata } from "next";
import type { ReactNode } from "react";

import { EnquiryForm } from "@/components/enquiry/enquiry-form";
import { PageHero } from "@/components/page-hero";
import { ButtonAnchor, Container } from "@/components/ui";
import { getSiteSettings } from "@/lib/data";
import { digits, whatsappLink } from "@/lib/format";

export const metadata: Metadata = {
  title: "Contact us",
  description: "Call, WhatsApp, email or visit our office to ask about land or arrange a site visit.",
};

export default async function ContactPage() {
  const settings = await getSiteSettings();
  return (
    <>
      <PageHero
        title="Contact us"
        subtitle="Ask about any property or arrange a site visit. We reply the same working day."
        crumbs={[{ href: "/contact", label: "Contact" }]}
      />
      <Container className="grid gap-10 py-14 lg:grid-cols-2">
        <div className="space-y-4">
          {settings.phone && (
            <ContactRow icon={<Phone />} title="Call us">
              <a href={`tel:+${digits(settings.phone)}`} className="text-forest hover:underline">{settings.phone}</a>
            </ContactRow>
          )}
          {settings.whatsapp && (
            <ContactRow icon={<MessageCircle />} title="WhatsApp">
              <ButtonAnchor
                href={whatsappLink(settings.whatsapp, "Hello, I'd like to know about your land.")}
                target="_blank"
                rel="noopener"
                variant="gold"
                className="mt-1"
              >
                Start a chat
              </ButtonAnchor>
            </ContactRow>
          )}
          {settings.email && (
            <ContactRow icon={<Mail />} title="Email">
              <a href={`mailto:${settings.email}`} className="text-forest hover:underline">{settings.email}</a>
            </ContactRow>
          )}
          {settings.address && (
            <ContactRow icon={<MapPin />} title="Office">
              {settings.address}
            </ContactRow>
          )}
          {settings.office_hours && (
            <ContactRow icon={<Clock />} title="Office hours">
              {settings.office_hours}
            </ContactRow>
          )}
        </div>

        <div className="rounded-2xl bg-white p-6 shadow-sm ring-1 ring-line sm:p-8">
          <h2 className="font-serif text-2xl text-forest">Send an enquiry</h2>
          <div className="mt-6">
            <EnquiryForm
              idPrefix="contact"
              source="contact_page"
              whatsappHref={settings.whatsapp ? whatsappLink(settings.whatsapp, "Hello, I sent an enquiry on your website.") : null}
            />
          </div>
        </div>
      </Container>
    </>
  );
}

function ContactRow({ icon, title, children }: { icon: ReactNode; title: string; children: ReactNode }) {
  return (
    <div className="flex gap-4 rounded-2xl bg-white p-5 ring-1 ring-line">
      <span className="flex h-11 w-11 shrink-0 items-center justify-center rounded-full bg-sand-light text-forest [&_svg]:h-5 [&_svg]:w-5">
        {icon}
      </span>
      <div>
        <h2 className="font-semibold text-ink">{title}</h2>
        <div className="mt-1 text-ink/80">{children}</div>
      </div>
    </div>
  );
}
