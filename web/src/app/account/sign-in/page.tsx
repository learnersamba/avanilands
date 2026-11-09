import type { Metadata } from "next";
import { Suspense } from "react";

import { SignInForm } from "@/components/account/sign-in-form";
import { Container } from "@/components/ui";

export const metadata: Metadata = {
  title: "Sign in",
  description:
    "Sign in to save properties and see your enquiries and site visits.",
  robots: { index: false, follow: false },
};

export default function SignInPage() {
  return (
    <Container className="max-w-md py-14">
      <h1 className="font-serif text-3xl text-forest">Sign in</h1>
      <p className="mt-2 text-ink/75">
        Save properties and see all your enquiries and site visits in one place.
        No password needed — we email you a code.
      </p>
      <div className="mt-8 rounded-2xl bg-white p-6 shadow-sm ring-1 ring-line">
        <Suspense fallback={<p className="text-sm text-muted">Loading…</p>}>
          <SignInForm />
        </Suspense>
      </div>
      <p className="mt-6 text-xs text-muted">
        An account is optional: you can enquire and book visits without one. We
        use your email only to sign you in and reply to you.
      </p>
    </Container>
  );
}
