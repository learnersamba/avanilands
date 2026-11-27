/**
 * Building Conversions API events (decision 133). Names, phone numbers and
 * emails never leave our server in plain text: Meta's rules ask for them
 * normalised and SHA-256 hashed, which is what happens here.
 *
 * No server-only imports, so it can be unit-tested.
 */
import { createHash } from "node:crypto";

export type MetaUserInput = {
  /** 10-digit Indian mobile as stored ("9876543210"). */
  phone?: string | null;
  email?: string | null;
  ip?: string | null;
  userAgent?: string | null;
  fbc?: string | null;
  fbp?: string | null;
};

export type MetaUserData = {
  ph?: string[];
  em?: string[];
  country?: string[];
  client_ip_address?: string;
  client_user_agent?: string;
  fbc?: string;
  fbp?: string;
};

export type MetaServerEvent = {
  event_name: string;
  event_time: number;
  event_id: string;
  action_source: "website" | "system_generated";
  event_source_url?: string;
  user_data: MetaUserData;
  custom_data?: Record<string, unknown>;
};

export const sha256 = (value: string) => createHash("sha256").update(value).digest("hex");

/** "9876543210" → "919876543210" (country code, digits only, as Meta asks). */
export function metaPhone(phone: string | null | undefined): string | null {
  const digits = (phone ?? "").replace(/\D/g, "");
  if (/^[6-9]\d{9}$/.test(digits)) return `91${digits}`;
  if (/^91[6-9]\d{9}$/.test(digits)) return digits;
  return null;
}

export function metaUserData(input: MetaUserInput): MetaUserData {
  const data: MetaUserData = { country: [sha256("in")] };
  const phone = metaPhone(input.phone);
  if (phone) data.ph = [sha256(phone)];
  const email = input.email?.trim().toLowerCase();
  if (email) data.em = [sha256(email)];
  if (input.ip) data.client_ip_address = input.ip;
  if (input.userAgent) data.client_user_agent = input.userAgent.slice(0, 500);
  if (input.fbc) data.fbc = input.fbc;
  if (input.fbp) data.fbp = input.fbp;
  return data;
}

/** Status changes in the admin panel → the events Meta learns from. */
export const crmEvents = {
  "enquiry:interested": "QualifiedLead",
  "enquiry:converted": "ConvertedLead",
  "site_visit:completed": "SiteVisitCompleted",
} as const;
