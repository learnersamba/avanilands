"use client";

import { Check, Link2, MessageCircle, X } from "lucide-react";
import Link from "next/link";
import { type ReactNode, useState } from "react";

import { compareHref } from "@/lib/compare";
import { removePick, useComparePicks } from "@/lib/compare-store";

/** Table wrapper with the "Only show differences" switch. */
export function DifferencesToggle({ children }: { children: ReactNode }) {
  const [onlyDiff, setOnlyDiff] = useState(false);
  return (
    <div data-diff-only={onlyDiff} className="group/compare">
      <label className="mb-4 inline-flex cursor-pointer items-center gap-2 text-sm font-medium">
        <input
          type="checkbox"
          checked={onlyDiff}
          onChange={(event) => setOnlyDiff(event.target.checked)}
          className="h-4 w-4 accent-forest"
        />
        Only show differences
      </label>
      {children}
    </div>
  );
}

/** Takes a property out of this comparison (and the device's compare list). */
export function RemoveFromComparison({
  code,
  codes,
}: {
  code: string;
  codes: string[];
}) {
  return (
    <Link
      href={compareHref(codes.filter((c) => c !== code))}
      onClick={() => removePick(code)}
      aria-label={`Remove ${code} from the comparison`}
      className="inline-flex items-center gap-1 text-xs text-muted hover:text-red-700"
    >
      <X className="h-3.5 w-3.5" aria-hidden /> Remove
    </Link>
  );
}

/** WhatsApp and copy-link buttons for the comparison address. */
export function ShareComparison({ url }: { url: string }) {
  const [copied, setCopied] = useState(false);
  return (
    <div className="flex flex-wrap gap-2">
      <a
        href={`https://wa.me/?text=${encodeURIComponent(`Have a look at these plots side by side: ${url}`)}`}
        target="_blank"
        rel="noopener"
        className="inline-flex items-center gap-2 rounded-lg bg-sand px-4 py-2.5 text-sm font-semibold text-forest-dark hover:bg-[#b8914c]"
      >
        <MessageCircle className="h-4 w-4" aria-hidden /> Share on WhatsApp
      </a>
      <button
        type="button"
        onClick={async () => {
          try {
            await navigator.clipboard.writeText(url);
            setCopied(true);
          } catch {
            window.prompt("Copy this link:", url);
          }
        }}
        className="inline-flex items-center gap-2 rounded-lg border border-forest/30 px-4 py-2.5 text-sm font-semibold text-forest hover:bg-forest/5"
      >
        {copied ? (
          <Check className="h-4 w-4" aria-hidden />
        ) : (
          <Link2 className="h-4 w-4" aria-hidden />
        )}
        {copied ? "Link copied" : "Copy link"}
      </button>
    </div>
  );
}

/** On an empty comparison: offer the picks saved on this device. */
export function YourPicks() {
  const picks = useComparePicks();
  if (picks.length < 2) return null;
  return (
    <Link
      href={compareHref(picks.map((p) => p.code))}
      className="inline-flex rounded-lg bg-forest px-5 py-3 text-sm font-semibold text-white hover:bg-forest-dark"
    >
      Compare your {picks.length} picks ({picks.map((p) => p.code).join(", ")})
    </Link>
  );
}
