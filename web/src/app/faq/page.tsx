import type { Metadata } from "next";

import { FaqView } from "@/components/views/faq-view";
import { getFaqs } from "@/lib/data";

export const metadata: Metadata = {
  title: "Questions & answers",
  description: "Answers to common questions about buying land from us: documents, site visits, prices and booking.",
};

export default async function FaqPage() {
  return <FaqView faqs={await getFaqs()} />;
}
