"use server";

import { after } from "next/server";

import { getSiteSettings } from "@/lib/data";
import { sendEmail } from "@/lib/email";
import { customerEnquiryEmail, type EnquiryEmailData, salesEnquiryEmail } from "@/lib/email-templates";
import { type EnquiryFields, type EnquiryState, enquirySchema, explainSubmitError } from "@/lib/enquiry";
import { env } from "@/lib/env";
import { createAdminClient } from "@/lib/supabase/admin";
import { currentCustomer } from "@/lib/supabase/server";
import { verifyTurnstile } from "@/lib/turnstile";
import { hashIp, visitorIp } from "@/lib/visitor";

/**
 * Enquiry form → validation → bot check → database (submit_enquiry, which
 * also applies the hourly limit and checks the property can still be
 * enquired about) → confirmation. Emails go out after the reply is sent.
 */
export async function submitEnquiry(_previous: EnquiryState, form: FormData): Promise<EnquiryState> {
  const raw = {
    name: String(form.get("name") ?? ""),
    phone: String(form.get("phone") ?? ""),
    email: String(form.get("email") ?? ""),
    preferredContact: String(form.get("preferredContact") ?? "phone"),
    message: String(form.get("message") ?? ""),
    propertyId: String(form.get("propertyId") ?? ""),
    source: String(form.get("source") ?? "property_page"),
    idempotencyKey: String(form.get("idempotencyKey") ?? ""),
  };
  const values: Partial<Record<EnquiryFields, string>> = {
    name: raw.name,
    phone: raw.phone,
    email: raw.email,
    preferredContact: raw.preferredContact,
    message: raw.message,
  };

  const parsed = enquirySchema.safeParse(raw);
  if (!parsed.success) {
    const fieldErrors: Partial<Record<EnquiryFields, string>> = {};
    for (const issue of parsed.error.issues) {
      const field = issue.path[0] as EnquiryFields;
      if (field in values && !fieldErrors[field]) fieldErrors[field] = issue.message;
    }
    // The schema checks this only once every field is valid; say it now too.
    if (raw.preferredContact === "email" && raw.email.trim() === "" && !fieldErrors.email) {
      fieldErrors.email = "Add your email if you'd like us to reply by email.";
    }
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
  const admin = createAdminClient();
  const { data, error } = await admin.rpc("submit_enquiry", {
    p_name: input.name,
    p_phone: input.phone,
    p_message: input.message,
    p_property_id: input.propertyId,
    p_email: input.email,
    p_preferred_contact: input.preferredContact,
    p_source: input.source,
    p_ip_hash: hashIp(ip),
    p_idempotency_key: input.idempotencyKey,
    p_customer_id: customer?.id ?? null,
  });
  if (error) {
    const explained = explainSubmitError(error.message);
    if (!explained.field && !error.message.match(/rate_limited|property_unavailable/)) {
      console.error("submit_enquiry failed", error);
    }
    return {
      status: "error",
      message: explained.message,
      fieldErrors: explained.field ? { [explained.field]: explained.message } : {},
      values,
    };
  }

  const result = data as { id: string; reference: string; duplicate: boolean };
  if (!result.duplicate) {
    // After the visitor has their confirmation: notify sales and the customer.
    after(() => sendEnquiryEmails(result.reference, input));
  }
  return { status: "sent", reference: result.reference, duplicate: result.duplicate };
}

async function sendEnquiryEmails(reference: string, input: ReturnType<typeof enquirySchema.parse>) {
  const admin = createAdminClient();
  const [settings, recipients, property] = await Promise.all([
    getSiteSettings(),
    admin.from("site_settings").select("sales_notify_emails").eq("id", 1).single(),
    input.propertyId
      ? admin.from("public_properties").select("code, title, slug").eq("id", input.propertyId).maybeSingle()
      : Promise.resolve({ data: null }),
  ]);
  const salesTo = (recipients.data?.sales_notify_emails as string[] | undefined)?.length
    ? (recipients.data!.sales_notify_emails as string[])
    : [process.env.SALES_NOTIFY_EMAIL].filter((value): value is string => Boolean(value));

  const data: EnquiryEmailData = {
    reference,
    name: input.name,
    phone: input.phone,
    email: input.email,
    preferredContact: input.preferredContact,
    message: input.message,
    property: property.data
      ? { code: property.data.code, title: property.data.title, url: `${env.siteUrl}/land/${property.data.slug}` }
      : null,
    companyName: settings.company_name,
    companyPhone: settings.phone,
    adminUrl: process.env.ADMIN_URL ?? null,
  };
  await sendEmail(salesTo, salesEnquiryEmail(data), input.email);
  if (input.email) await sendEmail([input.email], customerEnquiryEmail(data), settings.email);
}

/** Counts a tap on a WhatsApp or call button (no personal data). */
export async function logContactTap(channel: "whatsapp" | "call", propertyId: string | null): Promise<void> {
  if (channel !== "whatsapp" && channel !== "call") return;
  const id = propertyId && /^[0-9a-f-]{36}$/i.test(propertyId) ? propertyId : null;
  await createAdminClient().rpc("log_contact_tap", { p_channel: channel, p_property_id: id });
}
