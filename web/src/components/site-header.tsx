import { Phone } from "lucide-react";
import Link from "next/link";

import { AccountLink } from "@/components/account/account-link";
import { MobileMenu } from "@/components/mobile-menu";
import { Container } from "@/components/ui";
import { getSiteSettings } from "@/lib/data";
import { digits, whatsappLink } from "@/lib/format";

export const navLinks = [
  { href: "/land", label: "Explore land" },
  { href: "/locations", label: "Locations" },
  { href: "/about", label: "About" },
  { href: "/contact", label: "Contact" },
];

export function Logo({
  light = false,
  name,
  descriptor,
}: {
  light?: boolean;
  name: string;
  /** The line under the name, e.g. "Real Estate & Property Platform". */
  descriptor?: string;
}) {
  return (
    <Link href="/" className="flex items-center gap-2.5" aria-label={`${name} home`}>
      <svg viewBox="0 0 32 32" className="h-9 w-9" aria-hidden>
        <circle cx="16" cy="16" r="16" className={light ? "fill-white/10" : "fill-forest"} />
        <path d="M5 22 L12 13 L16 18 L20 11 L27 22 Z" className="fill-sand" />
        <path d="M5 22 H27" className="stroke-sand-light" strokeWidth="1.5" />
      </svg>
      <span className="flex flex-col">
        <span
          className={`font-serif text-lg font-semibold uppercase leading-none tracking-[0.12em] sm:text-xl ${light ? "text-white" : "text-forest"}`}
        >
          {name}
        </span>
        {descriptor && (
          <span
            className={`mt-1 hidden text-[9px] font-medium uppercase leading-none tracking-[0.14em] sm:block ${light ? "text-white/60" : "text-muted"}`}
          >
            {descriptor}
          </span>
        )}
      </span>
    </Link>
  );
}

export async function SiteHeader() {
  const settings = await getSiteSettings();
  return (
    <header className="sticky top-0 z-40 border-b border-line/80 bg-paper/95 backdrop-blur">
      <Container className="flex h-16 items-center justify-between gap-6">
        <Logo name={settings.company_name} descriptor={settings.descriptor} />
        <nav aria-label="Main" className="hidden items-center gap-8 md:flex">
          {navLinks.map((link) => (
            <Link key={link.href} href={link.href} className="py-2 text-sm font-medium text-ink/80 hover:text-forest">
              {link.label}
            </Link>
          ))}
        </nav>
        <div className="flex items-center gap-2">
          {settings.phone && (
            <a
              href={`tel:+${digits(settings.phone)}`}
              className="hidden items-center gap-2 text-sm font-semibold text-forest lg:inline-flex"
            >
              <Phone className="h-4 w-4" aria-hidden /> {settings.phone}
            </a>
          )}
          {settings.whatsapp && (
            <a
              href={whatsappLink(settings.whatsapp, "Hello, I'd like to know about your land.")}
              target="_blank"
              rel="noopener"
              className="hidden rounded-lg bg-sand px-4 py-2 text-sm font-semibold text-forest-dark hover:bg-[#b8914c] sm:inline-flex"
            >
              Talk to us
            </a>
          )}
          {settings.phone && (
            <a
              href={`tel:+${digits(settings.phone)}`}
              className="inline-flex h-10 w-10 items-center justify-center rounded-lg text-forest md:hidden"
              aria-label="Call us"
            >
              <Phone className="h-5 w-5" aria-hidden />
            </a>
          )}
          <AccountLink />
          <MobileMenu links={navLinks} />
        </div>
      </Container>
    </header>
  );
}
