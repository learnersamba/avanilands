import Link from "next/link";
import type { ReactNode } from "react";

import { Container } from "@/components/ui";

/** Title band at the top of inner pages, with optional breadcrumbs. */
export function PageHero({
  title,
  subtitle,
  crumbs = [],
  children,
}: {
  title: string;
  subtitle?: string;
  crumbs?: { href: string; label: string }[];
  children?: ReactNode;
}) {
  return (
    <section className="bg-contours bg-forest-dark text-white">
      <Container className="py-14 sm:py-20">
        {crumbs.length > 0 && (
          <nav aria-label="Breadcrumb" className="mb-4 text-sm text-white/70">
            <ol className="flex flex-wrap items-center gap-2">
              <li><Link href="/" className="inline-block py-1.5 hover:text-sand">Home</Link></li>
              {crumbs.map((crumb) => (
                <li key={crumb.href} className="flex items-center gap-2">
                  <span aria-hidden>/</span>
                  <Link href={crumb.href} className="inline-block py-1.5 hover:text-sand">{crumb.label}</Link>
                </li>
              ))}
            </ol>
          </nav>
        )}
        <h1 className="max-w-3xl font-serif text-[2.4rem] leading-[1.08] sm:text-[3.4rem]">{title}</h1>
        {subtitle && <p className="mt-5 max-w-2xl text-lg leading-relaxed text-white/75">{subtitle}</p>}
        {children}
      </Container>
    </section>
  );
}
