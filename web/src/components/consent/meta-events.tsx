"use client";

import { type RefObject, useEffect, useRef } from "react";

import { trackMeta } from "@/lib/meta-pixel";

/** Meta "ViewContent" for a property page (sent only if the visitor allowed ad cookies). */
export function MetaViewContent({ code, title, price }: { code: string; title: string; price: number | null }) {
  useEffect(() => {
    trackMeta("ViewContent", {
      content_ids: [code],
      content_type: "product",
      content_name: title,
      content_category: "land",
      ...(price != null && { value: price, currency: "INR" }),
    });
  }, [code, title, price]);
  return null;
}

/**
 * Sends one Meta event when `when` becomes true (e.g. a form was sent). The
 * event id is the form's double-submit key, the same one our server sends to
 * the Conversions API, so Meta counts the lead once.
 */
export function useMetaEventOnce(
  when: boolean,
  name: string,
  eventId: RefObject<string | null>,
  params: Record<string, unknown> = {},
): void {
  const sent = useRef(false);
  const latest = useRef(params);
  useEffect(() => {
    latest.current = params;
  });
  useEffect(() => {
    if (!when || sent.current) return;
    sent.current = true;
    trackMeta(name, latest.current, eventId.current ?? undefined);
  }, [when, name, eventId]);
}
