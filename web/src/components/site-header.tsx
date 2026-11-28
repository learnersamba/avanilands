import { Phone } from "lucide-react";
import Link from "next/link";

import { AccountLink } from "@/components/account/account-link";
import { features } from "@/lib/features";
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
        <circle cx="16" cy="16" r="16" className={light ? "fill-white/10" : "fill-forest-dark"} />
        <path d="M5 22 L12 13 L16 18 L20 11 L27 22 Z" className="fill-sand" />
        <path d="M5 22 H27" className="stroke-sand-light" strokeWidth="1.5" />
      </svg>
      <span className="flex flex-col">
        <span
          className={`font-serif text-lg !font-normal uppercase leading-none tracking-[0.16em] sm:text-xl ${light ? "text-white" : "text-forest-dark"}`}
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
    <header className="sticky top-0 z-40 border-b border-line bg-paper/90 backdrop-blur-md">
      <Container className="flex h-[4.25rem] items-center justify-between gap-6">
        <Logo name={settings.company_name} descriptor={settings.descriptor} />
        <nav aria-label="Main" className="hidden items-center gap-8 md:flex">
          {navLinks.map((link) => (
            <Link key={link.href} href={link.href} className="py-2 text-[0.95rem] text-ink/75 transition-colors hover:text-forest-dark">
              {link.label}
            </Link>
          ))}
        </nav>
        <div className="flex items-center gap-2">
          {settings.phone && (
            <a
              href={`tel:+${digits(settings.phone)}`}
              className="mr-3 hidden items-center gap-2 text-[0.95rem] font-medium text-forest-dark tabular-nums lg:inline-flex"
            >
              <Phone className="h-4 w-4" aria-hidden /> {settings.phone}
            </a>
          )}
          {settings.whatsapp && (
            <a
              href={whatsappLink(settings.whatsapp, "Hello, I'd like to know about your land.")}
              target="_blank"
              rel="noopener"
              className="hidden rounded-md bg-forest-dark px-4 py-2 text-[0.95rem] font-medium text-white hover:bg-forest sm:inline-flex"
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
          {features.customerAccounts && <AccountLink />}
          <MobileMenu links={navLinks} />
        </div>
      </Container>
    </header>
  );
}
