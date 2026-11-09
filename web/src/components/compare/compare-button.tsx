"use client";

import { Check, Plus } from "lucide-react";
import { useState } from "react";

import { maxCompare } from "@/lib/compare";
import {
  addPick,
  type ComparePick,
  removePick,
  useComparePicks,
} from "@/lib/compare-store";

/** "Compare" toggle on cards and the property page. */
export function CompareButton({
  pick,
  variant = "card",
}: {
  pick: ComparePick;
  variant?: "card" | "page";
}) {
  const picks = useComparePicks();
  const [full, setFull] = useState(false);
  const picked = picks.some((p) => p.code === pick.code);

  const onClick = () => {
    if (picked) {
      removePick(pick.code);
      setFull(false);
    } else {
      setFull(addPick(pick) === "full");
    }
  };

  return (
    <span className="relative inline-flex">
      <button
        type="button"
        onClick={onClick}
        aria-pressed={picked}
        aria-label={
          picked
            ? `Remove ${pick.code} from comparison`
            : `Compare ${pick.code}`
        }
        className={
          variant === "card"
            ? `inline-flex items-center gap-1 rounded-full border px-3 py-1.5 text-xs font-semibold transition ${
                picked
                  ? "border-forest bg-forest text-white"
                  : "border-line text-ink/75 hover:border-forest hover:text-forest"
              }`
            : `inline-flex items-center gap-2 rounded-lg border px-4 py-2.5 text-sm font-semibold transition ${
                picked
                  ? "border-forest bg-forest text-white"
                  : "border-forest/30 text-forest hover:bg-forest/5"
              }`
        }
      >
        {picked ? (
          <Check className="h-4 w-4" aria-hidden />
        ) : (
          <Plus className="h-4 w-4" aria-hidden />
        )}
        {picked ? "Comparing" : "Compare"}
      </button>
      {full && !picked && (
        <span
          role="alert"
          className="absolute bottom-full right-0 z-20 mb-2 w-56 rounded-lg bg-ink px-3 py-2 text-xs text-white shadow-lg"
        >
          You can compare {maxCompare} at a time. Remove one from the compare
          list first.
        </span>
      )}
    </span>
  );
}
