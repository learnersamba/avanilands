import { Phone } from "lucide-react";
import Link from "next/link";

import { AccountLink } from "@/components/account/account-link";
import { BrandMark } from "@/components/brand/brand-mark";
import { splitBrandName } from "@/lib/brand";
import { NavLink } from "@/components/nav-link";
import { features } from "@/lib/features";
import { MobileMenu } from "@/components/mobile-menu";
import { Container } from "@/components/ui";
import { getSiteSettings } from "@/lib/data";
import { digits } from "@/lib/format";

export const navLinks = [
  { href: "/", label: "Home" },
  { href: "/land", label: "Browse Land" },
  { href: "/locations", label: "Locations" },
  { href: "/about", label: "About Us" },
  { href: "/contact", label: "Contact" },
];

/**
 * The AVANILANDS logo: symbol, wordmark (AVANI in white or forest, LANDS in gold)
 * and the tagline. `light` = on a dark background (the default header and footer).
 */
export function Logo({
  light = true,
  name,
  descriptor,
}: {
  light?: boolean;
  name: string;
  /** The line under the name: the tagline. */
  descriptor?: string;
}) {
  const [first, last] = splitBrandName(name);
  return (
    <Link href="/" className="flex items-center gap-2.5" aria-label={`${name} home`}>
      <BrandMark className="h-10 w-11 sm:h-11 sm:w-12" />
      <span className="flex flex-col">
        <span className="font-heading text-[1.3rem] font-bold leading-none tracking-[0.01em] sm:text-[1.45rem]">
          <span className={light ? "text-white" : "text-forest-dark"}>{first}</span>
          <span className={light ? "text-sand" : "text-sand-dark"}>{last}</span>
        </span>
        {descriptor && (
          <span
            className={`mt-1 hidden text-[9.5px] font-medium leading-none tracking-[0.04em] sm:block ${light ? "text-white/70" : "text-muted"}`}
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
    <header className="sticky top-0 z-40 border-b border-sand/20 bg-forest-dark text-white">
      <Container className="flex h-[4.5rem] items-center justify-between gap-6">
        <Logo name={settings.company_name} descriptor={settings.tagline} />
        <nav aria-label="Main" className="hidden items-center gap-7 lg:flex">
          {navLinks.map((link) => (
            <NavLink key={link.href} href={link.href}>
              {link.label}
            </NavLink>
          ))}
        </nav>
        <div className="flex items-center gap-2">
          {settings.phone && (
            <a
              href={`tel:+${digits(settings.phone)}`}
              className="mr-2 hidden items-center gap-2 text-[0.9rem] font-medium text-white/85 tabular-nums hover:text-sand xl:inline-flex"
            >
              <Phone className="h-4 w-4 text-sand" aria-hidden /> {settings.phone}
            </a>
          )}
          <Link
            href="/contact"
            className="hidden rounded-md bg-sand px-4 py-2.5 font-heading text-[0.85rem] font-semibold text-forest-dark transition-colors hover:bg-[#C29F2E] sm:inline-flex"
          >
            Enquire Now
          </Link>
          {settings.phone && (
            <a
              href={`tel:+${digits(settings.phone)}`}
              className="inline-flex h-10 w-10 items-center justify-center rounded-lg text-sand lg:hidden"
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
