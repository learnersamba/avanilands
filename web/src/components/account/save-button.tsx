"use client";

import { Heart } from "lucide-react";
import { useRouter } from "next/navigation";
import { useState } from "react";

import { useAccount } from "@/components/account/account-provider";

/** Heart to save a property. Guests are taken to sign in, then it's saved. */
export function SaveButton({
  propertyId,
  code,
  variant = "card",
}: {
  propertyId: string;
  code: string;
  variant?: "card" | "page";
}) {
  const { saved, toggleSave } = useAccount();
  const router = useRouter();
  const [busy, setBusy] = useState(false);
  const [problem, setProblem] = useState(false);
  const isSaved = saved.has(propertyId);

  const onClick = async () => {
    setBusy(true);
    const result = await toggleSave(propertyId);
    setBusy(false);
    setProblem(result === "error");
    if (result === "sign-in") {
      // Read when tapped (not while rendering, so pages stay pre-rendered).
      router.push(
        `/account/sign-in?${new URLSearchParams({ next: window.location.pathname, save: propertyId })}`,
      );
    }
  };

  const label = isSaved ? `Remove ${code} from saved` : `Save ${code}`;
  return (
    <button
      type="button"
      onClick={onClick}
      disabled={busy}
      aria-pressed={isSaved}
      aria-label={label}
      title={problem ? "Couldn't save — try again" : label}
      className={
        variant === "card"
          ? "inline-flex h-10 w-10 items-center justify-center rounded-full bg-white/95 text-forest shadow-sm transition hover:scale-105 disabled:opacity-60"
          : "inline-flex items-center gap-2 rounded-lg border border-forest/30 px-4 py-2.5 text-sm font-semibold text-forest hover:bg-forest/5 disabled:opacity-60"
      }
    >
      <Heart
        className={`h-5 w-5 ${isSaved ? "fill-red-600 text-red-600" : ""} ${problem ? "text-red-700" : ""}`}
        aria-hidden
      />
      {variant === "page" && <span>{isSaved ? "Saved" : "Save"}</span>}
    </button>
  );
}
