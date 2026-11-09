import type { Metadata } from "next";
import { notFound } from "next/navigation";
import { Suspense } from "react";

import { PropertyGrid } from "@/components/property-card";
import { ButtonLink, Container } from "@/components/ui";
import { getPropertyRoute, getRelatedProperties } from "@/lib/data";

export const metadata: Metadata = { title: "No longer available", robots: { index: false } };

/**
 * Shown (with status 410) for archived properties — see src/proxy.ts — so
 * old links still help the visitor find similar land.
 */
export default function NoLongerAvailablePage(props: PageProps<"/no-longer-available/[slug]">) {
  return (
    <Suspense fallback={<div className="py-24" />}>
      <Content params={props.params} />
    </Suspense>
  );
}

async function Content({ params }: { params: Promise<{ slug: string }> }) {
  const { slug } = await params;
  const route = await getPropertyRoute(slug);
  if (!route || route.state !== "archived") notFound();
  const related = await getRelatedProperties({
    id: "00000000-0000-0000-0000-000000000000",
    property_type_id: route.property_type_id,
    location_id: route.location_id,
  });
  return (
    <>
      <Container className="py-16 text-center">
        <p className="text-xs font-semibold uppercase tracking-[0.2em] text-sand-dark">No longer available</p>
        <h1 className="mx-auto mt-4 max-w-2xl font-serif text-3xl text-forest sm:text-4xl">{route.title}</h1>
        <p className="mx-auto mt-4 max-w-xl text-ink/75">
          This property has been sold or withdrawn. Here is similar land in {route.city} — or tell us what you are
          looking for.
        </p>
        <div className="mt-8 flex flex-wrap justify-center gap-3">
          <ButtonLink href="/land">Browse all land</ButtonLink>
          <ButtonLink href="/contact" variant="outline">
            Tell us what you need
          </ButtonLink>
        </div>
      </Container>
      {related.length > 0 && (
        <section className="border-t border-line bg-white py-14" aria-labelledby="similar-title">
          <Container>
            <h2 id="similar-title" className="font-serif text-3xl text-forest">
              Similar land
            </h2>
            <div className="mt-8">
              <PropertyGrid properties={related} />
            </div>
          </Container>
        </section>
      )}
    </>
  );
}
