import type { Metadata } from "next";

import { LegalPage } from "@/components/legal-page";
import { getSiteContent } from "@/lib/data";

export const metadata: Metadata = { title: "Disclaimer" };

export default async function DisclaimerPage() {
  return <LegalPage content={(await getSiteContent()).legal.disclaimer} path="/disclaimer" />;
}
