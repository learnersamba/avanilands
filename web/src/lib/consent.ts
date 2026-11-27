/**
 * Advertising consent (decision 133). The website itself needs no cookies;
 * only Meta (Facebook / Instagram) advertising measurement does, so it runs
 * only after the visitor says yes. The choice is kept in a first-party
 * cookie so the server can read it too (Conversions API, lib/lead-tracking.ts).
 *
 * No server or browser code at module level, so this file can be unit-tested.
 */

export const CONSENT_COOKIE = "al_consent";
/** Re-asked after about 6 months, or at once if the wording version changes. */
export const CONSENT_MAX_AGE_DAYS = 180;
/** Bump when the purposes in the banner change: everyone is asked again. */
export const CONSENT_VERSION = 1;

export type ConsentChoice = "granted" | "denied";

/** "granted.1" → "granted"; anything else (missing, old version, junk) → null = not asked yet. */
export function parseConsent(value: string | null | undefined): ConsentChoice | null {
  if (!value) return null;
  const [choice, version] = value.split(".");
  if (Number(version) !== CONSENT_VERSION) return null;
  return choice === "granted" || choice === "denied" ? choice : null;
}

export function consentCookieValue(choice: ConsentChoice): string {
  return `${choice}.${CONSENT_VERSION}`;
}

/** Reads one cookie from a Cookie header / document.cookie string. */
export function readCookie(cookieHeader: string | null | undefined, name: string): string | null {
  if (!cookieHeader) return null;
  for (const part of cookieHeader.split(";")) {
    const index = part.indexOf("=");
    if (index < 0) continue;
    if (part.slice(0, index).trim() === name) {
      try {
        return decodeURIComponent(part.slice(index + 1).trim());
      } catch {
        return null;
      }
    }
  }
  return null;
}

/**
 * Advertising measurement is allowed only with a "yes" in the cookie and no
 * Global Privacy Control signal from the browser (an opt-out we respect,
 * like the website statistics do).
 */
export function adsAllowed(consentCookie: string | null | undefined, globalPrivacyControl: boolean): boolean {
  return !globalPrivacyControl && parseConsent(consentCookie) === "granted";
}
