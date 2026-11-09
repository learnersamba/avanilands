import type { Metadata } from "next";

import { AccountPage } from "@/components/account/account-page";
import { Container } from "@/components/ui";

export const metadata: Metadata = {
  title: "My account",
  robots: { index: false, follow: false },
};

export default function Page() {
  return (
    <Container className="py-10">
      <AccountPage />
    </Container>
  );
}
