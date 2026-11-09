import { revalidateTag } from "next/cache";

import { tagsForTable } from "@/lib/revalidate-tags";
import { secretMatches } from "@/lib/secret";
import { serverEnv } from "@/lib/server-env";

/**
 * Called by the database (private.notify_website) after a change, so the
 * website shows it straight away instead of after the cache expires.
 * Body: {"table": "properties"}; header x-revalidate-secret must match.
 */
export async function POST(request: Request) {
  if (!secretMatches(request.headers.get("x-revalidate-secret"), serverEnv().REVALIDATE_SECRET)) {
    return Response.json({ error: "Not allowed" }, { status: 401 });
  }

  let table: unknown;
  try {
    table = ((await request.json()) as { table?: unknown }).table;
  } catch {
    return Response.json({ error: "Expected JSON" }, { status: 400 });
  }
  const tags = tagsForTable(table);
  if (!tags) return Response.json({ error: "Unknown table" }, { status: 400 });

  // expire: 0 → the next visitor gets fresh data (no stale copy).
  for (const tag of tags) revalidateTag(tag, { expire: 0 });
  return Response.json({ refreshed: tags });
}
