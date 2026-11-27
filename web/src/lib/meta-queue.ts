import "server-only";

import { getSiteSettings } from "@/lib/data";
import { metaConfig, sendMetaEvents } from "@/lib/meta-capi";
import { metaUserData } from "@/lib/meta-events";
import { createAdminClient } from "@/lib/supabase/admin";

type QueuedEvent = {
  id: number;
  event_name: string;
  event_id: string;
  created_at: string;
  phone: string;
  email: string | null;
  fbc: string | null;
  fbp: string | null;
  property_code: string | null;
};

/**
 * Sales results back to Meta (decision 133). When the team marks an enquiry
 * Interested or Converted, or a site visit Completed, the database queues an
 * event (only for leads who agreed to advertising cookies, and only while
 * advertising is switched on). This sends the queue: Meta then learns which
 * kind of visitor actually buys land, not just who fills in forms.
 * Called by the database right after queuing (/api/meta/send) and by the
 * daily job (retries).
 */
export async function flushMetaQueue(): Promise<{ sent: number; failed: number; skipped?: string }> {
  if (!metaConfig()) return { sent: 0, failed: 0, skipped: "not_configured" };
  const settings = await getSiteSettings();
  if (!settings.meta_ads_enabled) return { sent: 0, failed: 0, skipped: "switched_off" };

  const admin = createAdminClient();
  const { data, error } = await admin.rpc("claim_meta_events", { p_limit: 200 });
  if (error) {
    console.error("Could not claim Meta events", error);
    return { sent: 0, failed: 0, skipped: "claim_failed" };
  }
  const rows = (data ?? []) as QueuedEvent[];
  if (rows.length === 0) return { sent: 0, failed: 0 };

  const result = await sendMetaEvents(
    rows.map((row) => ({
      event_name: row.event_name,
      event_time: Math.floor(new Date(row.created_at).getTime() / 1000),
      event_id: row.event_id,
      action_source: "system_generated" as const,
      user_data: metaUserData({ phone: row.phone, email: row.email, fbc: row.fbc, fbp: row.fbp }),
      custom_data: {
        event_source: "crm",
        lead_event_source: "Avanilands admin",
        content_category: "land",
        ...(row.property_code && { content_ids: [row.property_code], content_type: "product" }),
      },
    })),
  );
  const ids = rows.map((row) => row.id);
  await admin.rpc("finish_meta_events", {
    p_sent: result.ok ? ids : [],
    p_failed: result.ok ? [] : ids,
    p_error: result.ok ? null : (result.error ?? "failed"),
  });
  return result.ok ? { sent: ids.length, failed: 0 } : { sent: 0, failed: ids.length };
}
