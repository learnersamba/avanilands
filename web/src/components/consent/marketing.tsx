"use client";

import Link from "next/link";
import { usePathname, useSearchParams } from "next/navigation";
import { useEffect, useState, useSyncExternalStore } from "react";

import { buttonClasses } from "@/components/ui";
import { pageKey, searchFilters } from "@/lib/analytics";
import { attributionFromUrl } from "@/lib/attribution";
import {
  currentConsent,
  hasGlobalPrivacyControl,
  onReopenConsent,
  saveConsent,
  subscribeConsent,
} from "@/lib/consent-browser";
import { saveAttribution } from "@/lib/attribution-browser";
import { startPixel, stopPixel, trackMeta } from "@/lib/meta-pixel";

type Props = {
  /** Meta Pixel / dataset id; empty = advertising measurement not set up. */
  pixelId: string;
  /** Settings → Advertising switch (Super Admin). */
  enabled: boolean;
};

const NOT_READ = "not-read";
const serverSnapshot = () => NOT_READ;
const consentSnapshot = () => currentConsent() ?? "unset";
const noSubscription = () => () => {};

/**
 * Advertising on the website (decision 133):
 *  - always: remembers which campaign link (utm tags) started the visit, for
 *    the enquiry forms;
 *  - when advertising is set up and switched on: asks for consent, and only
 *    after a "yes" runs the Meta Pixel (page views, land searches).
 * Browsers that send Global Privacy Control are not asked and not tracked.
 */
export function Marketing({ pixelId, enabled }: Props) {
  const pathname = usePathname();
  const params = useSearchParams();
  const search = params.toString();
  const active = enabled && /^\d{5,20}$/.test(pixelId);
  const consent = useSyncExternalStore(subscribeConsent, consentSnapshot, serverSnapshot);
  const [reopened, setReopened] = useState(false);
  const gpc = useSyncExternalStore(noSubscription, hasGlobalPrivacyControl, () => false);

  useEffect(() => onReopenConsent(() => setReopened(true)), []);

  // Campaign tags from the address (any page can be an ad's landing page).
  useEffect(() => {
    const found = attributionFromUrl(new URL(window.location.href), Date.now());
    if (found) saveAttribution(found);
  }, [pathname, search]);

  const granted = active && !gpc && consent === "granted";

  useEffect(() => {
    if (granted) startPixel(pixelId);
    else stopPixel();
  }, [granted, pixelId]);

  // One PageView per page (in-app navigation included); a land search with
  // places or types also counts as a Search.
  const key = pageKey(pathname, search);
  useEffect(() => {
    if (!granted || pathname.startsWith("/preview")) return;
    trackMeta("PageView");
    if (pathname === "/land") {
      const { cities, types } = searchFilters(search);
      if (cities.length || types.length) {
        trackMeta("Search", { search_string: [...cities, ...types].join(" "), content_category: "land" });
      }
    }
    // `key` (not `search`): paging or sorting the same search is not a new page.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [granted, key]);

  const showBanner = active && !gpc && consent !== NOT_READ && (consent === "unset" || reopened);
  if (!showBanner || pathname.startsWith("/preview")) return null;

  const choose = (choice: "granted" | "denied") => {
    saveConsent(choice);
    setReopened(false);
  };

  return (
    <section
      role="dialog"
      aria-modal="false"
      aria-labelledby="consent-title"
      className="fixed inset-x-3 bottom-3 z-50 rounded-xl border border-line bg-white p-5 text-ink shadow-2xl sm:left-5 sm:right-auto sm:max-w-md"
    >
      <h2 id="consent-title" className="font-serif text-lg text-forest">
        Cookies for our ads
      </h2>
      <p className="mt-2 text-sm leading-relaxed text-ink/80">
        Our website works without cookies. With your permission, we also use Meta (Facebook and Instagram) cookies
        to measure our ads and to show them to people likely to be interested in land. Meta receives details of
        your visit and may combine them with what it already knows about you.
      </p>
      <p className="mt-2 text-sm leading-relaxed text-ink/80">
        Saying no changes nothing on the website. You can change your mind at any time under{" "}
        <strong className="font-medium">Cookie choices</strong> at the bottom of every page.{" "}
        <Link href="/privacy" className="font-medium text-forest underline">
          Privacy policy
        </Link>
      </p>
      <div className="mt-4 grid grid-cols-2 gap-3">
        <button type="button" onClick={() => choose("denied")} className={buttonClasses("outline", "px-3 py-2.5")}>
          No thanks
        </button>
        <button type="button" onClick={() => choose("granted")} className={buttonClasses("primary", "px-3 py-2.5")}>
          Allow ad cookies
        </button>
      </div>
    </section>
  );
}
