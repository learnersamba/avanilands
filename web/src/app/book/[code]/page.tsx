import type { Metadata } from "next";
import { Suspense } from "react";

import { BookingRequest } from "@/components/booking/booking-request";
import { ButtonLink, Container } from "@/components/ui";
import { parseCodes } from "@/lib/compare";
import { getComparison } from "@/lib/data";

export const metadata: Metadata = {
  title: "Request to book",
  robots: { index: false, follow: false },
};

export default function BookPage(props: PageProps<"/book/[code]">) {
  return (
    <Container className="max-w-3xl py-12">
      <Suspense fallback={<p className="text-muted">Loading…</p>}>
        <Booking params={props.params} />
      </Suspense>
    </Container>
  );
}

async function Booking({
  params,
}: {
  params: PageProps<"/book/[code]">["params"];
}) {
  const [code] = parseCodes((await params).code);
  const property = code ? (await getComparison([code])).items[0] : undefined;
  if (!property || property.availability !== "available") {
    return (
      <div>
        <h1 className="font-serif text-3xl text-forest">
          This property can&apos;t be booked
        </h1>
        <p className="mt-2 text-ink/75">
          {property
            ? `${property.code} is ${property.availability === "sold" ? "sold" : "reserved for another buyer"}. Have a look at similar land.`
            : "We couldn't find this property. It may have been sold or taken off the website."}
        </p>
        <div className="mt-6 flex gap-3">
          {property && (
            <ButtonLink href={`/land/${property.slug}`} variant="outline">
              Back to {property.code}
            </ButtonLink>
          )}
          <ButtonLink href="/land">Browse land</ButtonLink>
        </div>
      </div>
    );
  }
  return (
    <BookingRequest
      property={{
        id: property.id,
        code: property.code,
        title: property.title,
        slug: property.slug,
        price: property.price_type === "total" ? property.price : null,
        place: [property.locality, property.city].filter(Boolean).join(", "),
        thumb: property.cover_medium,
      }}
    />
  );
}
