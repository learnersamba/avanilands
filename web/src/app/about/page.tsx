import type { Metadata } from "next";

import { AboutView } from "@/components/views/about-view";
import { getSiteContent } from "@/lib/data";

export const metadata: Metadata = {
  title: "About us",
  description: "Who we are and how we sell land: owned by us, verified, and sold directly.",
};

export default async function AboutPage() {
  return <AboutView content={await getSiteContent()} />;
}
