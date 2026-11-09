import "server-only";

import { getSiteSettings } from "@/lib/data";
import { sendEmail } from "@/lib/email";
import { env } from "@/lib/env";
import {
  type CustomerVisitEvent,
  customerSiteVisitEmail,
  salesSiteVisitEmail,
  type SiteVisitEmailData,
} from "@/lib/site-visit-emails";
import { createAdminClient } from "@/lib/supabase/admin";

type VisitRow = {
  reference: string;
  name: string;
  phone: string;
  email: string | null;
  visitors: number;
  visit_date: string;
  slot: string;
  message: string | null;
  property_id: string;
};

const visitColumns = "reference, name, phone, email, visitors, visit_date, slot, message, property_id";

/** Everything the visit emails need (property, company details). */
async function emailData(visit: VisitRow): Promise<SiteVisitEmailData> {
  const admin = createAdminClient();
  const [settings, property] = await Promise.all([
    getSiteSettings(),
    admin
      .from("properties")
      .select("code, title, slug, locality, latitude, longitude, show_exact_location, location:locations(city)")
      .eq("id", visit.property_id)
      .single(),
  ]);
  const p = property.data as unknown as {
    code: string;
    title: string;
    slug: string | null;
    locality: string | null;
    latitude: number | null;
    longitude: number | null;
    show_exact_location: boolean;
    location: { city: string } | null;
  };
  return {
    reference: visit.reference,
    name: visit.name,
    phone: visit.phone,
    email: visit.email,
    visitors: visit.visitors,
    visitDate: visit.visit_date,
    slot: visit.slot,
    message: visit.message,
    property: {
      code: p.code,
      title: p.title,
      url: `${env.siteUrl}/land/${p.slug ?? ""}`,
      place: [p.locality, p.location?.city].filter(Boolean).join(", ") || null,
      // Exact directions only where the property's location is public;
      // otherwise the team shares the meeting point by phone.
      mapsUrl:
        p.show_exact_location && p.latitude !== null && p.longitude !== null
          ? `https://www.google.com/maps/dir/?api=1&destination=${p.latitude},${p.longitude}`
          : null,
    },
    companyName: settings.company_name,
    companyPhone: settings.phone,
    adminUrl: process.env.ADMIN_URL ?? null,
  };
}

/** New request: email sales, and the customer if they gave an email. */
export async function sendVisitRequestEmails(visitId: string): Promise<void> {
  const admin = createAdminClient();
  const [{ data: visit }, { data: settings }] = await Promise.all([
    admin.from("site_visits").select(visitColumns).eq("id", visitId).single(),
    admin.from("site_settings").select("email, sales_notify_emails").eq("id", 1).single(),
  ]);
  if (!visit) return;
  const data = await emailData(visit as VisitRow);
  const salesTo = (settings?.sales_notify_emails as string[] | undefined)?.length
    ? (settings!.sales_notify_emails as string[])
    : [process.env.SALES_NOTIFY_EMAIL].filter((value): value is string => Boolean(value));
  await sendEmail(salesTo, salesSiteVisitEmail(data), data.email);
  if (data.email) await sendEmail([data.email], customerSiteVisitEmail(data, "requested"), settings?.email);
}

/** Confirmed / moved / cancelled / reminder: email the customer (if they gave an email). */
export async function sendCustomerVisitEmail(visit: VisitRow, event: CustomerVisitEvent): Promise<boolean> {
  if (!visit.email) return false;
  const [data, settings] = await Promise.all([emailData(visit), getSiteSettings()]);
  return sendEmail([visit.email], customerSiteVisitEmail(data, event), settings.email);
}

export async function loadVisit(id: string): Promise<(VisitRow & { status: string }) | null> {
  const { data } = await createAdminClient()
    .from("site_visits")
    .select(`${visitColumns}, status`)
    .eq("id", id)
    .maybeSingle();
  return data as (VisitRow & { status: string }) | null;
}
