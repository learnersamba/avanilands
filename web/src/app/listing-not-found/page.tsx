import type { Metadata } from "next";

import NotFound from "@/app/not-found";

export const metadata: Metadata = { title: "Property not found", robots: { index: false } };

/** Shown (with status 404) for unknown property links — see src/proxy.ts. */
export default function ListingNotFound() {
  return <NotFound />;
}
