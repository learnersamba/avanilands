import "server-only";

import { createHash } from "node:crypto";

import { headers } from "next/headers";

export async function visitorIp(): Promise<string | null> {
  const list = await headers();
  return list.get("x-forwarded-for")?.split(",")[0]?.trim() || list.get("x-real-ip") || null;
}

/** Visitor IPs are never stored, only a salted hash used for the hourly limits. */
export function hashIp(ip: string | null): string | null {
  if (!ip) return null;
  const salt = process.env.IP_HASH_SALT ?? "";
  return createHash("sha256").update(`${salt}:${ip}`).digest("hex");
}

/**
 * Website statistics: the visitor's IP and browser as a salted hash. The
 * database hashes it again with a salt that changes daily (track_page_view).
 */
export function visitorClient(ip: string | null, userAgent: string | null): string {
  const salt = process.env.IP_HASH_SALT ?? "";
  return createHash("sha256").update(`${salt}:analytics:${ip ?? ""}:${userAgent ?? ""}`).digest("hex");
}
