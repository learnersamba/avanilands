import { secretMatches } from "@/lib/secret";
import { sendCustomerVisitEmail } from "@/lib/site-visit-server";
import { createAdminClient } from "@/lib/supabase/admin";

/**
 * Daily job (Vercel Cron, see vercel.json): reminds customers of their
 * confirmed visit tomorrow, and clears notifications older than 90 days and
 * page views older than 13 months.
 * Vercel sends "Authorization: Bearer <CRON_SECRET>".
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
  return Response.json({
    visits: visits.length,
    sent,
    old_notifications_removed: removed ?? 0,
    old_page_views_removed: oldViews ?? 0,
  });
}
