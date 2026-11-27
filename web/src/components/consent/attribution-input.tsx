"use client";

import { useEffect, useRef } from "react";

import { loadAttribution } from "@/lib/attribution-browser";

/** Hidden form field with the campaign the visit came from (see lib/attribution.ts). */
export function AttributionInput() {
  const input = useRef<HTMLInputElement>(null);
  useEffect(() => {
    if (input.current) input.current.value = loadAttribution();
  }, []);
  return <input ref={input} type="hidden" name="attribution" defaultValue="" />;
}
