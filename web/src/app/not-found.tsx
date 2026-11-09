import { ButtonLink, Container } from "@/components/ui";

export default function NotFound() {
  return (
    <Container className="py-28 text-center">
      <p className="text-xs font-semibold uppercase tracking-[0.2em] text-sand">Page not found</p>
      <h1 className="mt-4 font-serif text-4xl text-forest">This page doesn&apos;t exist</h1>
      <p className="mt-4 text-ink/75">The property may have been sold or the link may be old.</p>
      <div className="mt-8 flex justify-center gap-3">
        <ButtonLink href="/land">Browse land for sale</ButtonLink>
        <ButtonLink href="/" variant="outline">Go home</ButtonLink>
      </div>
    </Container>
  );
}
