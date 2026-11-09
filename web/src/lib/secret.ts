import "server-only";

import { timingSafeEqual } from "node:crypto";

/** Compares a secret from a request with the expected one in constant time. */
export function secretMatches(given: string | null, expected: string | undefined): boolean {
  if (!given || !expected) return false;
  const a = Buffer.from(given);
  const b = Buffer.from(expected);
  return a.length === b.length && timingSafeEqual(a, b);
}
