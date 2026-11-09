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
      <Container className="py-12 sm:py-16">
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
        <h1 className="font-serif text-4xl leading-tight sm:text-5xl">{title}</h1>
        {subtitle && <p className="mt-4 max-w-2xl text-lg text-white/80">{subtitle}</p>}
        {children}
      </Container>
    </section>
  );
}
