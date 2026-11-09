import { ChevronDown } from "lucide-react";

/** Accordion built on <details>, so it works without JavaScript. */
export function FaqList({ items }: { items: { q: string; a: string }[] }) {
  return (
    <div className="divide-y divide-line rounded-2xl border border-line bg-white">
      {items.map((item) => (
        <details key={item.q} className="group px-5 py-4 sm:px-6">
          <summary className="flex cursor-pointer items-center justify-between gap-4 font-medium text-ink">
            {item.q}
            <ChevronDown className="h-5 w-5 shrink-0 text-sand transition-transform group-open:rotate-180" aria-hidden />
          </summary>
          <p className="mt-3 text-ink/75">{item.a}</p>
        </details>
      ))}
    </div>
  );
}
