"use client";

/**
 * Meta Pixel in the browser (decision 133). Loaded only after the visitor
 * agrees to advertising cookies (components/meta-pixel.tsx). Automatic
 * collection (button clicks, form field details) is switched off: only the
 * events below are sent, and never names, phone numbers or emails — those go
 * hashed from our server (Conversions API), and only with consent.
 */

type Fbq = ((...args: unknown[]) => void) & {
  callMethod?: (...args: unknown[]) => void;
  queue: unknown[][];
  push: Fbq;
  loaded: boolean;
  version: string;
};

declare global {
  interface Window {
    fbq?: Fbq;
    _fbq?: Fbq;
  }
}

const STANDARD_EVENTS = new Set(["PageView", "ViewContent", "Search", "Lead", "Contact", "Schedule", "CompleteRegistration"]);

let active = false;
/**
 * Events from the first moments of a page, before the consent check has
 * run: sent if the pixel starts within 30 seconds, otherwise forgotten.
 */
let early: { at: number; args: unknown[] }[] = [];

/** Adds Meta's script (once) and starts the pixel. */
export function startPixel(pixelId: string): void {
  if (!window.fbq) {
    const fbq = function (...args: unknown[]) {
      if (fbq.callMethod) fbq.callMethod(...args);
      else fbq.queue.push(args);
    } as Fbq;
    fbq.queue = [];
    fbq.push = fbq;
    fbq.loaded = true;
    fbq.version = "2.0";
    window.fbq = fbq;
    window._fbq ??= fbq;
    const script = document.createElement("script");
    script.async = true;
    script.src = "https://connect.facebook.net/en_US/fbevents.js";
    document.head.appendChild(script);
    window.fbq("set", "autoConfig", false, pixelId);
    window.fbq("init", pixelId);
  }
  window.fbq("consent", "grant");
  active = true;
  const now = Date.now();
  for (const event of early) if (now - event.at < 30_000) window.fbq(...event.args);
  early = [];
}

/** Consent withdrawn: the pixel stops sending anything from now on. */
export function stopPixel(): void {
  if (active && window.fbq) window.fbq("consent", "revoke");
  active = false;
}

export function pixelActive(): boolean {
  return active;
}

/**
 * Sends one event if the pixel is running. eventId matches the server's
 * Conversions API event so Meta counts it once.
 */
export function trackMeta(name: string, params: Record<string, unknown> = {}, eventId?: string): void {
  const args = [STANDARD_EVENTS.has(name) ? "track" : "trackCustom", name, params, eventId ? { eventID: eventId } : undefined];
  if (active && window.fbq) window.fbq(...args);
  else if (!active && early.length < 20) early.push({ at: Date.now(), args });
}
