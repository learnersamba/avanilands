import type { Metadata } from "next";

import { LegalPage } from "@/components/legal-page";
import { getSiteContent } from "@/lib/data";

export const metadata: Metadata = { title: "Terms of use" };

export default async function TermsPage() {
  return <LegalPage content={(await getSiteContent()).legal.terms} path="/terms" />;
}
