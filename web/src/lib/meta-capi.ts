import "server-only";

import type { MetaServerEvent } from "@/lib/meta-events";

/**
 * Sends events to Meta's Conversions API from our server (decision 133).
 * Needs NEXT_PUBLIC_META_PIXEL_ID and the secret META_CAPI_ACCESS_TOKEN;
 * without them nothing is sent (local development, tests). While testing,
 * META_TEST_EVENT_CODE sends events to Events Manager → Test events only.
 */
export function metaConfig() {
  const pixelId = process.env.NEXT_PUBLIC_META_PIXEL_ID?.trim() ?? "";
  const token = process.env.META_CAPI_ACCESS_TOKEN?.trim() ?? "";
  if (!/^\d{5,20}$/.test(pixelId) || token.length < 20) return null;
  return {
    pixelId,
    token,
    testEventCode: process.env.META_TEST_EVENT_CODE?.trim() || undefined,
    version: /^v\d+\.\d+$/.test(process.env.META_GRAPH_API_VERSION ?? "")
      ? process.env.META_GRAPH_API_VERSION!
      : "v25.0",
  };
}

/** True if Meta accepted the events. Never throws: advertising must not break a form. */
export async function sendMetaEvents(events: MetaServerEvent[]): Promise<{ ok: boolean; error?: string }> {
  const config = metaConfig();
  if (!config || events.length === 0) return { ok: false, error: "not_configured" };
  try {
    const response = await fetch(
      `https://graph.facebook.com/${config.version}/${config.pixelId}/events?access_token=${encodeURIComponent(config.token)}`,
      {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ data: events, ...(config.testEventCode && { test_event_code: config.testEventCode }) }),
        signal: AbortSignal.timeout(4000),
        cache: "no-store",
      },
    );
    if (response.ok) return { ok: true };
    const body = (await response.text()).slice(0, 300);
    console.error("Meta Conversions API refused events", response.status, body);
    return { ok: false, error: `http_${response.status}: ${body}` };
  } catch (error) {
    console.error("Meta Conversions API unreachable", error);
    return { ok: false, error: error instanceof Error ? error.message.slice(0, 300) : "unreachable" };
  }
}
