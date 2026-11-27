"use client";

import type { Attribution } from "@/lib/attribution";

const KEY = "al_attribution";

/**
 * Kept for this browser tab only (sessionStorage, not a cookie): the latest
 * campaign link the visitor arrived from. Nothing leaves the browser until
 * they send an enquiry or visit request.
 */
export function saveAttribution(value: Attribution): void {
  try {
    sessionStorage.setItem(KEY, JSON.stringify(value));
  } catch {
    // Private mode or storage switched off: nothing to remember.
  }
}

export function loadAttribution(): string {
  try {
    return sessionStorage.getItem(KEY) ?? "";
  } catch {
    return "";
  }
}
