"use client";

import type { ComponentProps } from "react";

import { logContactTap } from "@/app/enquiry-actions";
import { trackMeta } from "@/lib/meta-pixel";

/** A WhatsApp or call link that also counts the tap (no personal data; decision 133 for Meta). */
export function TrackedLink({
  channel,
  propertyId = null,
  onClick,
  ...props
}: ComponentProps<"a"> & { channel: "whatsapp" | "call"; propertyId?: string | null }) {
  return (
    <a
      {...props}
      onClick={(event) => {
        void logContactTap(channel, propertyId).catch(() => {});
        // Meta "Contact" (only if the visitor allowed ad cookies).
        trackMeta("Contact", { content_category: channel });
        onClick?.(event);
      }}
    />
  );
}
