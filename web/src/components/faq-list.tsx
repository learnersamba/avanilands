import { ChevronDown } from "lucide-react";

/** Accordion built on <details>, so it works without JavaScript. */
export function FaqList({ items }: { items: { q: string; a: string }[] }) {
  return (
    <div className="divide-y divide-line border-y border-line">
      {items.map((item) => (
        <details key={item.q} className="group py-5">
          <summary className="flex cursor-pointer items-center justify-between gap-4 text-lg text-ink hover:text-forest-dark">
            {item.q}
            <ChevronDown className="h-5 w-5 shrink-0 text-sand-dark transition-transform group-open:rotate-180" aria-hidden />
          </summary>
          <p className="mt-3 max-w-2xl leading-relaxed text-muted">{item.a}</p>
        </details>
      ))}
    </div>
  );
}
