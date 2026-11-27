"use client";

import { reopenConsent } from "@/lib/consent-browser";

/** Footer link that opens the advertising-cookie question again (withdraw or give consent). */
export function CookieChoicesButton({ className = "" }: { className?: string }) {
  return (
    <button type="button" onClick={reopenConsent} className={className}>
      Cookie choices
    </button>
  );
}
