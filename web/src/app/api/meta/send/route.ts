import { flushMetaQueue } from "@/lib/meta-queue";
import { secretMatches } from "@/lib/secret";
import { serverEnv } from "@/lib/server-env";

/**
 * Called by the database when sales results are queued for Meta
 * (private.notify_meta_events, decision 133), with the same shared secret
 * as the cache refresh.
 */
export async function POST(request: Request) {
  if (!secretMatches(request.headers.get("x-revalidate-secret"), serverEnv().REVALIDATE_SECRET)) {
    return Response.json({ error: "Not allowed" }, { status: 401 });
  }
  return Response.json(await flushMetaQueue());
}
