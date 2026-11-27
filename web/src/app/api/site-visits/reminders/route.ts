import { flushMetaQueue } from "@/lib/meta-queue";
import { secretMatches } from "@/lib/secret";
import { sendCustomerVisitEmail } from "@/lib/site-visit-server";
import { createAdminClient } from "@/lib/supabase/admin";

/**
 * Daily job, started at 09:00 India time by the database's scheduler
 * (private.run_daily_website_job, decision 132; or Vercel Cron via
 * vercel.json): reminds customers of their confirmed visit tomorrow, and
 * clears notifications older than 90 days and page views older than 6 months,
 * retries sales results Meta didn't accept and clears old advertising ids
 * (decision 133).
 * The caller sends "Authorization: Bearer <CRON_SECRET>".
 * Each visit is claimed once in the database, so a repeated run sends nothing.
 */
export async function GET(request: Request) {
  const given = request.headers.get("authorization")?.replace(/^Bearer /, "") ?? null;
  if (!secretMatches(given, process.env.CRON_SECRET)) {
    return Response.json({ error: "Not allowed" }, { status: 401 });
  }
  const { data, error } = await createAdminClient().rpc("claim_site_visit_reminders");
  if (error) {
    console.error("Site visit reminders failed", error);
    return Response.json({ error: "Could not load visits" }, { status: 500 });
  }
  const visits = data as Parameters<typeof sendCustomerVisitEmail>[0][];
  let sent = 0;
  for (const visit of visits) if (await sendCustomerVisitEmail(visit, "reminder")) sent++;
  // Same daily job: old notifications and page views go.
  const { data: removed } = await createAdminClient().rpc("cleanup_notifications");
  const { data: oldViews } = await createAdminClient().rpc("cleanup_analytics");
  const meta = await flushMetaQueue().catch((error) => {
    console.error("Meta retry failed", error);
    return null;
  });
  const { data: metaCleared } = await createAdminClient().rpc("cleanup_meta_data");
  return Response.json({
    meta_events_sent: meta?.sent ?? 0,
    meta_ids_cleared: metaCleared ?? 0,
    visits: visits.length,
    sent,
    old_notifications_removed: removed ?? 0,
    old_page_views_removed: oldViews ?? 0,
  });
}
