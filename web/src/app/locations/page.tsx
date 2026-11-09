import type { Metadata } from "next";

import { ContactBand } from "@/components/contact-band";
import { LocationCard } from "@/components/location-card";
import { PageHero } from "@/components/page-hero";
import { Container } from "@/components/ui";
import { getLocations } from "@/lib/data";

export const metadata: Metadata = {
  title: "Locations",
  description: "Towns and districts in Andhra Pradesh where we have land for sale.",
};

export default async function LocationsPage() {
  const locations = await getLocations();
  return (
    <>
      <PageHero
        title="Where we have land"
        subtitle="Every location below has land owned and verified by us."
        crumbs={[{ href: "/locations", label: "Locations" }]}
      />
      <Container className="space-y-6 py-14">
        {locations.map((location) => (
          <section
            key={location.id}
            id={location.slug}
            className="grid scroll-mt-24 items-center gap-6 rounded-2xl bg-white p-4 ring-1 ring-line sm:grid-cols-[320px_1fr] sm:p-5"
          >
            <LocationCard location={location} href={`/land-for-sale/${location.slug}`} />
            <div className="px-1 pb-2">
              <h2 className="font-serif text-2xl text-forest">{location.city}</h2>
              <p className="text-sm text-muted">
                {location.district} district, {location.state}
              </p>
              {location.description && <p className="mt-3 text-ink/80">{location.description}</p>}
            </div>
          </section>
        ))}
      </Container>
      <ContactBand />
    </>
  );
}
