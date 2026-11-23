import type { Metadata } from "next";
import { notFound } from "next/navigation";

import { AccountPage } from "@/components/account/account-page";
import { Container } from "@/components/ui";
import { features } from "@/lib/features";

export const metadata: Metadata = {
  title: "My account",
  robots: { index: false, follow: false },
};

export default function Page() {
  if (!features.customerAccounts) notFound();
  return (
    <Container className="py-10">
      <AccountPage />
    </Container>
  );
}
