/**
 * Site visit rules, shared by the booking form and the server action. The
 * database checks the same things again (submit_site_visit). All dates are
 * India time and written "YYYY-MM-DD".
 */
import { z } from "zod";

import { normalizeIndianMobile } from "@/lib/enquiry";

export type VisitSettings = {
  visit_days: number[];
  visit_slots: string[];
  visit_closed_dates: string[];
  visit_days_ahead: number;
};

/** Today's date in India, e.g. "2026-11-09". */
export function todayInIndia(now: Date = new Date()): string {
  return new Intl.DateTimeFormat("en-CA", { timeZone: "Asia/Kolkata" }).format(now);
}

function addDays(date: string, days: number): string {
  const value = new Date(`${date}T00:00:00Z`);
  value.setUTCDate(value.getUTCDate() + days);
  return value.toISOString().slice(0, 10);
}

/** 1 = Monday … 7 = Sunday */
function isoWeekday(date: string): number {
  return new Date(`${date}T00:00:00Z`).getUTCDay() || 7;
}

/** Bookable days: from tomorrow, within the window, on visit days, not holidays. */
export function availableVisitDates(settings: VisitSettings, today: string): string[] {
  const closed = new Set(settings.visit_closed_dates);
  const dates: string[] = [];
  for (let offset = 1; offset <= settings.visit_days_ahead; offset++) {
    const date = addDays(today, offset);
    if (settings.visit_days.includes(isoWeekday(date)) && !closed.has(date)) dates.push(date);
  }
  return dates;
}

/** "2026-11-14" → "Sat, 14 Nov" (with the year when asked: "Sat, 14 Nov 2026"). */
export function formatVisitDate(date: string, withYear = false): string {
  const parts = Object.fromEntries(
    new Intl.DateTimeFormat("en-IN", { weekday: "short", day: "numeric", month: "short", year: "numeric", timeZone: "UTC" })
      .formatToParts(new Date(`${date}T00:00:00Z`))
      .map((part) => [part.type, part.value]),
  );
  return `${parts.weekday}, ${parts.day} ${parts.month}${withYear ? ` ${parts.year}` : ""}`;
}

/** "15:00" → "3:00 pm" */
export function formatSlot(slot: string): string {
  const [hours, minutes] = slot.split(":").map(Number);
  const suffix = hours >= 12 ? "pm" : "am";
  return `${hours % 12 || 12}:${String(minutes).padStart(2, "0")} ${suffix}`;
}

export const siteVisitSchema = z.object({
  name: z.string().trim().min(2, "Please enter your name.").max(80, "Please shorten your name."),
  phone: z
    .string()
    .trim()
    .transform((value, context) => {
      const phone = normalizeIndianMobile(value);
      if (!phone) {
        context.addIssue({ code: "custom", message: "Enter a 10-digit Indian mobile number." });
        return z.NEVER;
      }
      return phone;
    }),
  email: z
    .string()
    .trim()
    .max(254)
    .refine((value) => value === "" || /^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(value), "Enter a valid email or leave it empty.")
    .transform((value) => (value === "" ? null : value.toLowerCase())),
  visitDate: z.string().regex(/^\d{4}-\d{2}-\d{2}$/, "Choose a day for your visit."),
  slot: z.string().regex(/^([01]\d|2[0-3]):[0-5]\d$/, "Choose a time."),
  visitors: z.coerce.number().int().min(1, "At least 1 person.").max(20, "For more than 20 people, please call us."),
  message: z
    .string()
    .trim()
    .max(1000, "Keep it under 1000 characters.")
    .transform((value) => (value === "" ? null : value)),
  propertyId: z.string().uuid(),
  idempotencyKey: z.string().uuid(),
});

export type SiteVisitInput = z.infer<typeof siteVisitSchema>;
export type SiteVisitFields = "name" | "phone" | "email" | "visitDate" | "slot" | "visitors" | "message";

export type SiteVisitState =
  | { status: "idle" }
  | { status: "sent"; reference: string; visitDate: string; slot: string; alreadyBooked: boolean }
  | {
      status: "error";
      message: string;
      fieldErrors: Partial<Record<SiteVisitFields, string>>;
      values: Partial<Record<SiteVisitFields, string>>;
    };

/** Database error keys (submit_site_visit) → sentences for the visitor. */
export function explainVisitError(message: string): { message: string; field?: SiteVisitFields } {
  if (message.includes("invalid_phone")) return { message: "Enter a 10-digit Indian mobile number.", field: "phone" };
  if (message.includes("invalid_date") || message.includes("closed_day")) {
    return { message: "That day isn't available any more. Please choose another day.", field: "visitDate" };
  }
  if (message.includes("invalid_slot")) return { message: "That time isn't available. Please choose another.", field: "slot" };
  if (message.includes("rate_limited")) {
    return { message: "We've already received several visit requests from you in the last hour. We'll call you soon." };
  }
  if (message.includes("property_unavailable")) {
    return { message: "Sorry — this property has just been sold or withdrawn, so visits are closed. Ask us about similar land." };
  }
  return { message: "Something went wrong on our side. Please try again, or call us." };
}

/** Link that opens Google Calendar with the visit filled in (2-hour slot). */
export function googleCalendarLink(visit: {
  date: string;
  slot: string;
  title: string;
  details: string;
  location: string | null;
}): string {
  const start = `${visit.date.replaceAll("-", "")}T${visit.slot.replace(":", "")}00`;
  const [hours, minutes] = visit.slot.split(":").map(Number);
  const endHour = Math.min(hours + 2, 23);
  const end = `${visit.date.replaceAll("-", "")}T${String(endHour).padStart(2, "0")}${String(minutes).padStart(2, "0")}00`;
  const params = new URLSearchParams({
    action: "TEMPLATE",
    text: visit.title,
    dates: `${start}/${end}`,
    ctz: "Asia/Kolkata",
    details: visit.details,
    ...(visit.location && { location: visit.location }),
  });
  return `https://calendar.google.com/calendar/render?${params}`;
}
