"use client";

import { Scale, X } from "lucide-react";
import Link from "next/link";
import { usePathname } from "next/navigation";
import { useState } from "react";

import { compareHref, maxCompare } from "@/lib/compare";
import { clearPicks, removePick, useComparePicks } from "@/lib/compare-store";
import { mediaUrl } from "@/lib/media";

/** Floating "Compare (2)" button; opens a small list with "Compare now". */
export function CompareTray() {
  const picks = useComparePicks();
  const pathname = usePathname();
  const [open, setOpen] = useState(false);
  if (picks.length === 0 || pathname === "/compare") return null;
  // Above the property page's phone action bar.
  const lift = pathname.startsWith("/land/")
    ? "bottom-24 lg:bottom-6"
    : "bottom-6";

  return (
    <div
      className={`fixed left-1/2 z-40 w-[min(92vw,26rem)] -translate-x-1/2 ${lift}`}
    >
      {open && (
        <div
          id="compare-tray"
          className="mb-2 rounded-2xl bg-white p-4 shadow-xl ring-1 ring-line"
        >
          <p className="text-sm font-semibold text-ink">
            Compare list ({picks.length} of {maxCompare})
          </p>
          <ul className="mt-3 space-y-2">
            {picks.map((pick) => (
              <li key={pick.code} className="flex items-center gap-3">
                {pick.thumb ? (
                  // eslint-disable-next-line @next/next/no-img-element
                  <img
                    src={mediaUrl(pick.thumb)}
                    alt=""
                    width={48}
                    height={36}
                    className="h-9 w-12 rounded object-cover"
                  />
                ) : (
                  <span className="h-9 w-12 rounded bg-line" aria-hidden />
                )}
                <span className="min-w-0 flex-1 truncate text-sm">
                  <span className="font-semibold">{pick.code}</span> ·{" "}
                  {pick.title}
                </span>
                <button
                  type="button"
                  onClick={() => removePick(pick.code)}
                  aria-label={`Remove ${pick.code} from comparison`}
                  className="inline-flex h-8 w-8 items-center justify-center rounded-full text-muted hover:bg-line/50"
                >
                  <X className="h-4 w-4" aria-hidden />
                </button>
              </li>
            ))}
          </ul>
          <div className="mt-4 flex items-center justify-between gap-3">
            <button
              type="button"
              onClick={clearPicks}
              className="text-sm text-muted underline"
            >
              Clear all
            </button>
            {picks.length < 2 ? (
              <span className="text-sm text-muted">
                Add one more to compare
              </span>
            ) : (
              <Link
                href={compareHref(picks.map((p) => p.code))}
                onClick={() => setOpen(false)}
                className="rounded-lg bg-forest px-4 py-2 text-sm font-semibold text-white hover:bg-forest-dark"
              >
                Compare now
              </Link>
            )}
          </div>
        </div>
      )}
      <button
        type="button"
        onClick={() => setOpen((value) => !value)}
        aria-expanded={open}
        aria-controls="compare-tray"
        className="mx-auto flex items-center gap-2 rounded-full bg-forest px-5 py-3 text-sm font-semibold text-white shadow-lg hover:bg-forest-dark"
      >
        <Scale className="h-4 w-4" aria-hidden /> Compare ({picks.length})
      </button>
    </div>
  );
}
