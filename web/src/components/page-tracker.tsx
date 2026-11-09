"use client";

import { usePathname, useSearchParams } from "next/navigation";
import { useEffect } from "react";

import { pageKey, searchFilters } from "@/lib/analytics";

// Once per page, even when React runs the effect twice (development).
let lastKey: string | null = null;
let firstPage = true;

/**
 * Counts each page shown, including in-app navigation (no cookies, nothing
 * personal: see /api/track). Only the first page of a visit sends where it came from.
 */
export function PageTracker() {
  const pathname = usePathname();
  const params = useSearchParams();
  const search = params.toString();

  useEffect(() => {
    const key = pageKey(pathname, search);
    if (key === lastKey) return;
    lastKey = key;
    if (pathname.startsWith("/preview")) return;
    const { cities, types } = searchFilters(search);
    const body = JSON.stringify({
      path: pathname,
      search: new URLSearchParams({
        ...(cities.length && { city: cities.join(",") }),
        ...(types.length && { type: types.join(",") }),
      }).toString(),
      ...(firstPage && !fromOwnSite() && { referrer: document.referrer }),
    });
    firstPage = false;
    const queued = navigator.sendBeacon?.("/api/track", new Blob([body], { type: "application/json" }));
    if (!queued) {
      fetch("/api/track", { method: "POST", body, keepalive: true, headers: { "content-type": "application/json" } }).catch(
        () => {},
      );
    }
  }, [pathname, search]);

  return null;
}

/** A full page load from one of our own pages (e.g. a reload) is not a new visit. */
function fromOwnSite(): boolean {
  try {
    return new URL(document.referrer).origin === window.location.origin;
  } catch {
    return false;
  }
}
