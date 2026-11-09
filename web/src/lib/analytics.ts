/**
 * Website statistics (Phase 16): what the page tracker sends and how the
 * server reads it. Nothing personal is kept: see track_page_view in the
 * database. This file has no server or browser code so it can be unit-tested.
 */

export type Device = "mobile" | "tablet" | "desktop";

// Search engines, link previews, monitoring and scripted browsers.
const BOT =
  /bot|crawl|spider|slurp|mediapartners|facebookexternalhit|whatsapp|telegram|skype|preview|headless|lighthouse|pingdom|uptime|curl|wget|python|node-fetch|axios|go-http|java\//i;

export function isBot(userAgent: string | null | undefined): boolean {
  return !userAgent || BOT.test(userAgent);
}

export function deviceOf(userAgent: string | null | undefined): Device {
  const ua = userAgent ?? "";
  if (/iPad|Tablet|PlayBook|Silk|Kindle/i.test(ua) || (/Android/i.test(ua) && !/Mobile/i.test(ua))) return "tablet";
  if (/Mobi|iPhone|iPod|Android|Opera Mini|IEMobile/i.test(ua)) return "mobile";
  return "desktop";
}

/** The referring domain, or null for none / our own site / anything odd. */
export function referrerHost(referrer: string | null | undefined, ownHosts: string[]): string | null {
  if (!referrer) return null;
  // Android apps send their name, e.g. android-app://com.whatsapp/
  if (/^android-app:\/\/com\.whatsapp(\/|$)/i.test(referrer)) return "whatsapp.com";
  try {
    const url = new URL(referrer);
    if (url.protocol !== "http:" && url.protocol !== "https:") return null;
    const host = url.hostname.toLowerCase();
    if (ownHosts.some((own) => own.toLowerCase().split(":")[0] === host)) return null;
    return /^[a-z0-9.-]{1,100}$/.test(host) ? host : null;
  } catch {
    return null;
  }
}

/** Pages worth counting: no previews, API calls or odd addresses. */
export function trackablePath(path: unknown): string | null {
  if (typeof path !== "string" || !path.startsWith("/") || path.startsWith("//") || path.length > 300) return null;
  const clean = path.split(/[?#]/)[0].replace(/\/+$/, "") || "/";
  if (/^\/(preview|api|_next)(\/|$)/.test(clean)) return null;
  return clean;
}

const slugList = (params: URLSearchParams, key: string) =>
  [
    ...new Set(
      params
        .getAll(key)
        .flatMap((value) => value.split(","))
        .map((value) => value.trim().toLowerCase())
        .filter((value) => /^[a-z0-9]+(-[a-z0-9]+)*$/.test(value)),
    ),
  ]
    .sort()
    .slice(0, 10);

/** The searched places and land types (the /land filters `city` and `type`). */
export function searchFilters(search: string | URLSearchParams | null | undefined): {
  cities: string[];
  types: string[];
} {
  const params = search instanceof URLSearchParams ? search : new URLSearchParams(search ?? "");
  return { cities: slugList(params, "city"), types: slugList(params, "type") };
}

/**
 * When the tracker counts a new page: a different address, or on /land a
 * different place / land type. Paging, sorting and price changes on the
 * same search are not new page views.
 */
export function pageKey(pathname: string, search: string): string {
  if (pathname !== "/land") return pathname;
  const { cities, types } = searchFilters(search);
  return `${pathname}?city=${cities.join(",")}&type=${types.join(",")}`;
}
