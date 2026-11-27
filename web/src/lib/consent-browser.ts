"use client";

import {
  CONSENT_COOKIE,
  CONSENT_MAX_AGE_DAYS,
  type ConsentChoice,
  consentCookieValue,
  parseConsent,
  readCookie,
} from "@/lib/consent";

/** The browser's Global Privacy Control signal (an opt-out of sharing for ads). */
export function hasGlobalPrivacyControl(): boolean {
  return (navigator as Navigator & { globalPrivacyControl?: boolean }).globalPrivacyControl === true;
}

export function currentConsent(): ConsentChoice | null {
  return parseConsent(readCookie(document.cookie, CONSENT_COOKIE));
}

const listeners = new Set<() => void>();
const reopenListeners = new Set<() => void>();

export function subscribeConsent(listener: () => void): () => void {
  listeners.add(listener);
  return () => listeners.delete(listener);
}

/** Saves the visitor's choice and tells the page (pixel, banner) at once. */
export function saveConsent(choice: ConsentChoice): void {
  const secure = location.protocol === "https:" ? "; Secure" : "";
  document.cookie =
    `${CONSENT_COOKIE}=${consentCookieValue(choice)}; Max-Age=${CONSENT_MAX_AGE_DAYS * 86400}; Path=/; SameSite=Lax${secure}`;
  if (choice === "denied") removeMetaCookies();
  for (const listener of listeners) listener();
}

/** Meta's own first-party cookies: removed when consent is refused or withdrawn. */
export function removeMetaCookies(): void {
  const host = location.hostname;
  const domains = ["", host, `.${host}`, `.${host.split(".").slice(-2).join(".")}`];
  for (const name of ["_fbp", "_fbc"]) {
    for (const domain of domains) {
      document.cookie = `${name}=; Max-Age=0; Path=/${domain ? `; Domain=${domain}` : ""}`;
    }
  }
}

/** "Cookie choices" in the footer opens the banner again. */
export function onReopenConsent(listener: () => void): () => void {
  reopenListeners.add(listener);
  return () => reopenListeners.delete(listener);
}

export function reopenConsent(): void {
  for (const listener of reopenListeners) listener();
}
