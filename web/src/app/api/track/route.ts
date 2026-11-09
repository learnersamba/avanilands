import { deviceOf, isBot, referrerHost, searchFilters, trackablePath } from "@/lib/analytics";
import { env } from "@/lib/env";
import { createAdminClient } from "@/lib/supabase/admin";
import { visitorClient, visitorIp } from "@/lib/visitor";

/**
 * Page tracker (components/page-tracker.tsx) → one page view. Answers 204
 * whether or not the view was counted, so it tells a script nothing.
 * Not counted: other sites, bots, Do Not Track / Global Privacy Control.
 */
export async function POST(request: Request) {
  const done = new Response(null, { status: 204 });
  const headers = request.headers;
  if (headers.get("sec-fetch-site") === "cross-site") return done;
  if (headers.get("dnt") === "1" || headers.get("sec-gpc") === "1") return done;
  const userAgent = headers.get("user-agent");
  if (isBot(userAgent)) return done;

  let body: { path?: unknown; search?: unknown; referrer?: unknown };
  try {
    const text = await request.text();
    if (text.length > 2000) return done;
    body = JSON.parse(text);
  } catch {
    return done;
  }
  const path = trackablePath(body?.path);
  if (!path) return done;

  const entry = typeof body.referrer === "string";
  const { cities, types } = searchFilters(typeof body.search === "string" ? body.search.slice(0, 500) : "");
  const ownHosts = [new URL(request.url).host, new URL(env.siteUrl).host];
  const { error } = await createAdminClient().rpc("track_page_view", {
    p_client: visitorClient(await visitorIp(), userAgent),
    p_path: path,
    p_entry: entry,
    p_referrer_host: entry ? referrerHost(body.referrer as string, ownHosts) : null,
    p_device: deviceOf(userAgent),
    p_location_slugs: cities,
    p_type_slugs: types,
  });
  if (error) console.error("track_page_view failed", error);
  return done;
}
