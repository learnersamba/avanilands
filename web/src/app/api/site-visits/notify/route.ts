import { secretMatches } from "@/lib/secret";
import { serverEnv } from "@/lib/server-env";
import { loadVisit, sendCustomerVisitEmail } from "@/lib/site-visit-server";

const events = ["confirmed", "rescheduled", "cancelled"] as const;

/**
 * Called by the database (private.notify_site_visit_change) when the team
 * confirms, moves or cancels a visit: emails the customer.
 * Body: {"id": "<visit id>", "event": "confirmed"}; header x-revalidate-secret.
 */
export async function POST(request: Request) {
  if (!secretMatches(request.headers.get("x-revalidate-secret"), serverEnv().REVALIDATE_SECRET)) {
    return Response.json({ error: "Not allowed" }, { status: 401 });
  }
  let body: { id?: unknown; event?: unknown };
  try {
    body = (await request.json()) as typeof body;
  } catch {
    return Response.json({ error: "Expected JSON" }, { status: 400 });
  }
  const event = events.find((name) => name === body.event);
  if (!event || typeof body.id !== "string" || !/^[0-9a-f-]{36}$/i.test(body.id)) {
    return Response.json({ error: "Expected id and event" }, { status: 400 });
  }
  const visit = await loadVisit(body.id);
  if (!visit) return Response.json({ error: "Unknown visit" }, { status: 404 });
  const sent = await sendCustomerVisitEmail(visit, event);
  return Response.json({ sent });
}
