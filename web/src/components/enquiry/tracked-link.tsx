"use client";

import type { ComponentProps } from "react";

import { logContactTap } from "@/app/enquiry-actions";

/** A WhatsApp or call link that also counts the tap (no personal data). */
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
        onClick?.(event);
      }}
    />
  );
}
