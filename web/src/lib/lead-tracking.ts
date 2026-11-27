import "server-only";

import { cookies, headers } from "next/headers";

import { type Attribution, browserId, clickId, parseAttribution } from "@/lib/attribution";
import { adsAllowed, CONSENT_COOKIE } from "@/lib/consent";
import { getSiteSettings } from "@/lib/data";
import { metaConfig, sendMetaEvents } from "@/lib/meta-capi";
import { metaUserData } from "@/lib/meta-events";
import { createAdminClient } from "@/lib/supabase/admin";

type Lead = {
  kind: "enquiry" | "site_visit";
  /** The saved enquiry / site visit. */
  id: string;
  /** The form's double-submit key: also the event id the browser pixel uses, so Meta counts the lead once. */
  eventId: string;
  eventName: "Lead" | "Schedule";
  attribution: FormDataEntryValue | null;
  phone: string;
  email: string | null;
  propertyId: string | null;
  ip: string | null;
};

/**
 * After a new enquiry or site visit request (decision 133):
 *  1. keeps which campaign brought it (utm tags; always, nothing personal),
 *     whether the visitor agreed to advertising cookies, and — only then —
 *     Meta's click and browser ids, so later status changes can be reported;
 *  2. with consent, and advertising switched on in Settings, tells Meta's
 *     Conversions API about the lead (phone and email hashed).
 * Never throws: the enquiry is already saved and must not fail because of ads.
 */
export async function recordLead(lead: Lead): Promise<void> {
  try {
    const [cookieStore, headerList, settings] = await Promise.all([cookies(), headers(), getSiteSettings()]);
    const consent = adsAllowed(cookieStore.get(CONSENT_COOKIE)?.value, headerList.get("sec-gpc") === "1");
    const attribution: Attribution = parseAttribution(lead.attribution);
    const now = Date.now();
    const fbc = consent ? clickId(cookieStore.get("_fbc")?.value, attribution, now) : null;
    const fbp = consent ? browserId(cookieStore.get("_fbp")?.value) : null;

    const admin = createAdminClient();
    const hasCampaign = Object.keys(attribution).some((key) => key.startsWith("utm_"));
    if (hasCampaign || consent) {
      const { error } = await admin.from("lead_attribution").insert({
        [lead.kind === "enquiry" ? "enquiry_id" : "site_visit_id"]: lead.id,
        utm_source: attribution.utm_source ?? null,
        utm_medium: attribution.utm_medium ?? null,
        utm_campaign: attribution.utm_campaign ?? null,
        utm_content: attribution.utm_content ?? null,
        utm_term: attribution.utm_term ?? null,
        landing_path: attribution.landing_path ?? null,
        ad_consent: consent,
        consent_at: consent ? new Date(now).toISOString() : null,
        meta_fbc: fbc,
        meta_fbp: fbp,
      });
      if (error) console.error("Could not save lead attribution", error);
    }

    if (!consent || !settings.meta_ads_enabled || !metaConfig()) return;
    const property = lead.propertyId
      ? (await admin.from("public_properties").select("code").eq("id", lead.propertyId).maybeSingle()).data
      : null;
    await sendMetaEvents([
      {
        event_name: lead.eventName,
        event_time: Math.floor(now / 1000),
        event_id: lead.eventId,
        action_source: "website",
        event_source_url: pageUrl(headerList.get("referer")),
        user_data: metaUserData({
          phone: lead.phone,
          email: lead.email,
          ip: lead.ip,
          userAgent: headerList.get("user-agent"),
          fbc,
          fbp,
        }),
        custom_data: {
          content_category: "land",
          ...(property?.code && { content_ids: [property.code], content_type: "product" }),
        },
      },
    ]);
  } catch (error) {
    console.error("Lead tracking failed", error);
  }
}

/** The page the form was on, without its query (which may hold campaign or click ids). */
function pageUrl(referer: string | null): string | undefined {
  if (!referer) return undefined;
  try {
    const url = new URL(referer);
    return `${url.origin}${url.pathname}`;
  } catch {
    return undefined;
  }
}
