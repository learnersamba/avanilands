import { Mail, MapPin, Phone } from "lucide-react";
import Link from "next/link";

import { Logo } from "@/components/site-header";
import { Container } from "@/components/ui";
import { registrations, withoutFinalDot } from "@/components/company-details";
import { getLocations, getSiteSettings } from "@/lib/data";
import { digits } from "@/lib/format";

export async function SiteFooter() {
  const [settings, locations] = await Promise.all([getSiteSettings(), getLocations()]);
  return (
    <footer className="bg-contours bg-forest-dark text-white/80">
      <Container className="grid gap-10 py-14 sm:grid-cols-2 lg:grid-cols-4">
        <div className="space-y-4">
          <Logo light name={settings.company_name} descriptor={settings.descriptor} />
          <p className="font-serif text-base text-sand">{settings.tagline}</p>
          <p className="text-sm leading-relaxed">
            Verified land sold directly by {settings.company_name}. We own every property we list — no brokers, no
            third-party sellers.
          </p>
        </div>

        <div>
          <h2 className="font-serif text-lg text-white">Explore</h2>
          <ul className="mt-3 space-y-0.5 text-sm">
            <li><Link href="/land" className="inline-block py-1.5 hover:text-sand">All land for sale</Link></li>
            <li><Link href="/locations" className="inline-block py-1.5 hover:text-sand">Locations</Link></li>
            <li><Link href="/about" className="inline-block py-1.5 hover:text-sand">About us</Link></li>
            <li><Link href="/faq" className="inline-block py-1.5 hover:text-sand">Questions & answers</Link></li>
            <li><Link href="/contact" className="inline-block py-1.5 hover:text-sand">Contact</Link></li>
          </ul>
        </div>

        <div>
          <h2 className="font-serif text-lg text-white">Locations</h2>
          <ul className="mt-3 space-y-0.5 text-sm">
            {locations.slice(0, 6).map((location) => (
              <li key={location.id}>
                <Link href={`/land-for-sale/${location.slug}`} className="inline-block py-1.5 hover:text-sand">
                  Land in {location.city}
                </Link>
              </li>
            ))}
          </ul>
        </div>

        <div>
          <h2 className="font-serif text-lg text-white">Contact</h2>
          <ul className="mt-4 space-y-3 text-sm">
            {settings.phone && (
              <li className="flex items-start gap-2">
                <Phone className="mt-0.5 h-4 w-4 text-sand" aria-hidden />
                <a href={`tel:+${digits(settings.phone)}`} className="inline-block py-1.5 hover:text-sand">{settings.phone}</a>
              </li>
            )}
            {settings.email && (
              <li className="flex items-start gap-2">
                <Mail className="mt-0.5 h-4 w-4 text-sand" aria-hidden />
                <a href={`mailto:${settings.email}`} className="inline-block py-1.5 hover:text-sand">{settings.email}</a>
              </li>
            )}
            {settings.address && (
              <li className="flex items-start gap-2">
                <MapPin className="mt-0.5 h-4 w-4 shrink-0 text-sand" aria-hidden />
                <span>{settings.address}</span>
              </li>
            )}
            {settings.office_hours && <li className="text-white/60">{settings.office_hours}</li>}
          </ul>
        </div>
      </Container>
      <div className="border-t border-white/10">
        <Container className="flex flex-col gap-3 py-6 text-xs text-white/60 sm:flex-row sm:items-center sm:justify-between">
          <div className="space-y-1">
            <p>
              © {settings.company_name}, a brand of {withoutFinalDot(settings.legal_name)}. All rights reserved.
            </p>
            {registrations(settings).length > 0 && (
              <p>{registrations(settings).map(([label, value]) => `${label}: ${value}`).join(" · ")}</p>
            )}
          </div>
          <nav aria-label="Legal" className="flex gap-5">
            <Link href="/terms" className="inline-block py-1.5 hover:text-sand">Terms</Link>
            <Link href="/privacy" className="inline-block py-1.5 hover:text-sand">Privacy</Link>
            <Link href="/disclaimer" className="inline-block py-1.5 hover:text-sand">Disclaimer</Link>
          </nav>
        </Container>
      </div>
    </footer>
  );
}
