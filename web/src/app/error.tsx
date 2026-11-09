"use client";

import { Container } from "@/components/ui";

export default function Error({ reset }: { error: Error & { digest?: string }; reset: () => void }) {
  return (
    <Container className="py-28 text-center">
      <h1 className="font-serif text-4xl text-forest">Something went wrong</h1>
      <p className="mt-4 text-ink/75">Please try again. If it keeps happening, call or WhatsApp us.</p>
      <button
        type="button"
        onClick={reset}
        className="mt-8 rounded-lg bg-forest px-5 py-3 text-sm font-semibold text-white hover:bg-forest-dark"
      >
        Try again
      </button>
    </Container>
  );
}
