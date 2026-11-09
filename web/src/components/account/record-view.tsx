"use client";

import { useEffect } from "react";

import { addRecent } from "@/lib/account/recent";

/** Remembers (in this browser only) that this property was viewed. */
export function RecordView({ propertyId }: { propertyId: string }) {
  useEffect(() => addRecent(propertyId), [propertyId]);
  return null;
}
