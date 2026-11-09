import { getSiteSettings } from "@/lib/data";
import { sendEmail } from "@/lib/email";
import { env } from "@/lib/env";
import { savedLandEmail } from "@/lib/notification-emails";
import { secretMatches } from "@/lib/secret";
import { serverEnv } from "@/lib/server-env";
import { createAdminClient } from "@/lib/supabase/admin";

type Queued = {
  id: number;
  email: string | null;
  name: string;
  title: string;
  body: string | null;
  link: string | null;
};

/**
 * Called by the database when notifications with an email are queued
 * (saved-land changes): claims them (each only once) and sends them.
 */
export async function POST(request: Request) {
  if (
    !secretMatches(
      request.headers.get("x-revalidate-secret"),
      serverEnv().REVALIDATE_SECRET,
    )
  ) {
    return Response.json({ error: "Not allowed" }, { status: 401 });
  }
  const admin = createAdminClient();
  const { data, error } = await admin.rpc("claim_notification_emails", {
    p_limit: 50,
  });
  if (error) {
    console.error("Could not claim notification emails", error);
    return Response.json({ error: "Could not load emails" }, { status: 500 });
  }
  const settings = await getSiteSettings();
  const sent: number[] = [];
  const failed: number[] = [];
  for (const item of (data ?? []) as Queued[]) {
    const ok =
      item.email != null &&
      (await sendEmail(
        [item.email],
        savedLandEmail({
          name: item.name,
          title: item.title,
          body: item.body,
          link: item.link,
          siteUrl: env.siteUrl,
          companyName: settings.company_name,
          companyPhone: settings.phone,
        }),
        settings.email,
      ));
    (ok ? sent : failed).push(item.id);
  }
  await admin.rpc("finish_notification_emails", {
    p_sent: sent,
    p_failed: failed,
  });
  return Response.json({ sent: sent.length, failed: failed.length });
}
