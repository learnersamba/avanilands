"use server";

import { after } from "next/server";

import { getSiteSettings } from "@/lib/data";
import {
  availableVisitDates,
  explainVisitError,
  type SiteVisitFields,
  type SiteVisitState,
  siteVisitSchema,
  todayInIndia,
} from "@/lib/site-visit";
import { sendVisitRequestEmails } from "@/lib/site-visit-server";
import { createAdminClient } from "@/lib/supabase/admin";
import { currentCustomer } from "@/lib/supabase/server";
import { verifyTurnstile } from "@/lib/turnstile";
import { hashIp, visitorIp } from "@/lib/visitor";

/**
 * Site visit form → validation (including the day and time) → bot check →
 * database (submit_site_visit checks everything again, applies the hourly
 * limit and returns an open request instead of a second one) → confirmation.
 * Emails go out after the reply is sent.
 */
export async function submitSiteVisit(_previous: SiteVisitState, form: FormData): Promise<SiteVisitState> {
  const raw = Object.fromEntries(
    ["name", "phone", "email", "visitDate", "slot", "visitors", "message", "propertyId", "idempotencyKey"].map(
      (key) => [key, String(form.get(key) ?? "")],
    ),
  );
  const values: Partial<Record<SiteVisitFields, string>> = {
    name: raw.name,
    phone: raw.phone,
    email: raw.email,
    visitDate: raw.visitDate,
    slot: raw.slot,
    visitors: raw.visitors,
    message: raw.message,
  };

  const parsed = siteVisitSchema.safeParse(raw);
  const fieldErrors: Partial<Record<SiteVisitFields, string>> = {};
  for (const issue of parsed.error?.issues ?? []) {
    const field = issue.path[0] as SiteVisitFields;
    if (field in values && !fieldErrors[field]) fieldErrors[field] = issue.message;
  }
  // The day and time must be ones the website offers right now.
  const settings = await getSiteSettings();
  if (!fieldErrors.visitDate && !availableVisitDates(settings, todayInIndia()).includes(raw.visitDate)) {
    fieldErrors.visitDate = "That day isn't available. Please choose another day.";
  }
  if (!fieldErrors.slot && !settings.visit_slots.includes(raw.slot)) {
    fieldErrors.slot = "Choose one of the times shown.";
  }
  if (!parsed.success || Object.keys(fieldErrors).length > 0) {
    return { status: "error", message: "Please check the highlighted fields.", fieldErrors, values };
  }
  const input = parsed.data;

  const ip = await visitorIp();
  const token = form.get("cf-turnstile-response");
  if (!(await verifyTurnstile(typeof token === "string" ? token : null, ip))) {
    return {
      status: "error",
      message: "We couldn't confirm you're not a robot. Please wait a moment and try again.",
      fieldErrors: {},
      values,
    };
  }

  const customer = await currentCustomer();
  const { data, error } = await createAdminClient().rpc("submit_site_visit", {
    p_property_id: input.propertyId,
    p_name: input.name,
    p_phone: input.phone,
    p_visit_date: input.visitDate,
    p_slot: input.slot,
    p_visitors: input.visitors,
    p_email: input.email,
    p_message: input.message,
    p_ip_hash: hashIp(ip),
    p_idempotency_key: input.idempotencyKey,
    p_customer_id: customer?.id ?? null,
  });
  if (error) {
    const explained = explainVisitError(error.message);
    if (!explained.field && !/rate_limited|property_unavailable/.test(error.message)) {
      console.error("submit_site_visit failed", error);
    }
    return {
      status: "error",
      message: explained.message,
      fieldErrors: explained.field ? { [explained.field]: explained.message } : {},
      values,
    };
  }

  const result = data as {
    id: string;
    reference: string;
    duplicate: boolean;
    already_booked?: boolean;
    visit_date: string;
    slot: string;
  };
  if (!result.duplicate) after(() => sendVisitRequestEmails(result.id));
  return {
    status: "sent",
    reference: result.reference,
    visitDate: result.visit_date,
    slot: result.slot,
    alreadyBooked: result.already_booked === true,
  };
}
