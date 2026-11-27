/**
 * Which ad or link brought an enquiry (decision 133). Campaign tags (utm_*)
 * describe the campaign, not the person, and are kept with every enquiry and
 * site visit request so the team sees which campaign works. The Meta click id
 * (fbclid) is used only when the visitor agreed to advertising cookies.
 *
 * No server or browser code here, so it can be unit-tested.
 */

export const UTM_KEYS = ["utm_source", "utm_medium", "utm_campaign", "utm_content", "utm_term"] as const;
export type UtmKey = (typeof UTM_KEYS)[number];

export type Attribution = Partial<Record<UtmKey, string>> & {
  /** First page of the visit, path only (no query, nothing personal). */
  landing_path?: string;
  /** Meta click id from the ad link and when it was seen (ms). */
  fbclid?: string;
  fbclid_at?: number;
};

const MAX = { utm_source: 100, utm_medium: 100, utm_campaign: 200, utm_content: 200, utm_term: 100 } as const;

function cleanText(value: unknown, max: number): string | undefined {
  if (typeof value !== "string") return undefined;
  // Printable text only; campaign names never need control characters.
  const text = value.replace(/[\u0000-\u001f\u007f]/g, "").trim().slice(0, max);
  return text || undefined;
}

/** Campaign details from a landing page address; undefined if there are none. */
export function attributionFromUrl(url: URL, now: number): Attribution | undefined {
  const result: Attribution = {};
  for (const key of UTM_KEYS) {
    const value = cleanText(url.searchParams.get(key), MAX[key]);
    if (value) result[key] = value;
  }
  const fbclid = url.searchParams.get("fbclid");
  if (fbclid && /^[A-Za-z0-9_-]{10,500}$/.test(fbclid)) {
    result.fbclid = fbclid;
    result.fbclid_at = now;
  }
  if (Object.keys(result).length === 0) return undefined;
  result.landing_path = cleanText(url.pathname, 300);
  return result;
}

/** What the form sent (JSON from the browser): only known keys, limited and cleaned. */
export function parseAttribution(raw: unknown): Attribution {
  if (typeof raw !== "string" || raw.length > 4000) return {};
  let value: unknown;
  try {
    value = JSON.parse(raw);
  } catch {
    return {};
  }
  if (!value || typeof value !== "object" || Array.isArray(value)) return {};
  const input = value as Record<string, unknown>;
  const result: Attribution = {};
  for (const key of UTM_KEYS) {
    const text = cleanText(input[key], MAX[key]);
    if (text) result[key] = text;
  }
  const path = cleanText(input.landing_path, 300);
  if (path?.startsWith("/")) result.landing_path = path;
  if (typeof input.fbclid === "string" && /^[A-Za-z0-9_-]{10,500}$/.test(input.fbclid)) {
    result.fbclid = input.fbclid;
    if (typeof input.fbclid_at === "number" && Number.isFinite(input.fbclid_at)) {
      result.fbclid_at = Math.trunc(input.fbclid_at);
    }
  }
  return result;
}

/**
 * Meta's click cookie format, fb.1.<ms>.<fbclid>: the _fbc cookie when the
 * pixel set one, otherwise made from the saved fbclid (clicks older than 90
 * days no longer count).
 */
export function clickId(fbcCookie: string | null | undefined, attribution: Attribution, now: number): string | null {
  if (fbcCookie && /^fb\.\d\.\d+\.[A-Za-z0-9_-]{10,500}$/.test(fbcCookie)) return fbcCookie;
  if (!attribution.fbclid) return null;
  const at = attribution.fbclid_at && attribution.fbclid_at <= now ? attribution.fbclid_at : now;
  if (now - at > 90 * 86_400_000) return null;
  return `fb.1.${at}.${attribution.fbclid}`;
}

/** Meta's browser id cookie, fb.1.<ms>.<random>; anything else is ignored. */
export function browserId(fbpCookie: string | null | undefined): string | null {
  return fbpCookie && /^fb\.\d\.\d+\.\d+$/.test(fbpCookie) ? fbpCookie : null;
}
