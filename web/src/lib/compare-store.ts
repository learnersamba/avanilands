"use client";

import { useSyncExternalStore } from "react";

import { maxCompare } from "@/lib/compare";

/** One pick, with enough to show it in the tray without asking the server. */
export type ComparePick = { code: string; title: string; thumb: string | null };

const key = "bk-compare";
const changed = "bk-compare-changed";
const empty: ComparePick[] = [];
let cache: { raw: string | null; picks: ComparePick[] } = {
  raw: null,
  picks: empty,
};

function read(): ComparePick[] {
  let raw: string | null = null;
  try {
    raw = localStorage.getItem(key);
  } catch {
    return empty;
  }
  if (raw === cache.raw) return cache.picks;
  let picks: ComparePick[] = empty;
  try {
    const value = JSON.parse(raw ?? "[]");
    if (Array.isArray(value)) {
      picks = value
        .filter(
          (p): p is ComparePick =>
            typeof p?.code === "string" && typeof p?.title === "string",
        )
        .slice(0, maxCompare);
    }
  } catch {}
  cache = { raw, picks };
  return picks;
}

function write(picks: ComparePick[]) {
  try {
    localStorage.setItem(key, JSON.stringify(picks));
  } catch {}
  window.dispatchEvent(new Event(changed));
}

function subscribe(onChange: () => void) {
  window.addEventListener("storage", onChange); // other tabs
  window.addEventListener(changed, onChange); // this tab
  return () => {
    window.removeEventListener("storage", onChange);
    window.removeEventListener(changed, onChange);
  };
}

/** Properties picked for comparison on this device (empty while the page loads). */
export function useComparePicks(): ComparePick[] {
  return useSyncExternalStore(subscribe, read, () => empty);
}

/** Adds a pick; "full" when 3 are already picked. */
export function addPick(pick: ComparePick): "added" | "full" {
  const picks = read();
  if (picks.some((p) => p.code === pick.code)) return "added";
  if (picks.length >= maxCompare) return "full";
  write([...picks, pick]);
  return "added";
}

export function removePick(code: string) {
  write(read().filter((p) => p.code !== code));
}

export function clearPicks() {
  write([]);
}
