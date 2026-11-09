import type { Metadata } from "next";

import { LegalPage } from "@/components/legal-page";
import { getSiteContent } from "@/lib/data";

export const metadata: Metadata = { title: "Privacy policy" };

export default async function PrivacyPage() {
  return <LegalPage content={(await getSiteContent()).legal.privacy} path="/privacy" />;
}
