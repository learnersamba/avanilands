import { type NextRequest, NextResponse } from "next/server";

/**
 * Property links (/land/<slug>) before the page renders, so search engines
 * get the right answer (the page itself streams, which always means 200):
 *   current slug   → the page
 *   old slug       → 301 to the current slug
 *   archived       → 410 "no longer available" page with similar land
 *   anything else  → 404
 * Answers are kept in memory for a minute to stay fast.
 */

type Route = { slug: string; state: "published" | "archived" } | null;

const cache = new Map<string, { at: number; route: Route }>();
const TTL = 60_000;
const slugPattern = /^[a-z0-9]+(-[a-z0-9]+)*$/;

async function lookup(slug: string): Promise<Route | "error"> {
  const hit = cache.get(slug);
  if (hit && Date.now() - hit.at < TTL) return hit.route;
  try {
    const response = await fetch(`${process.env.NEXT_PUBLIC_SUPABASE_URL}/rest/v1/rpc/property_route`, {
      method: "POST",
      headers: {
        apikey: process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY ?? "",
        "Content-Type": "application/json",
      },
      body: JSON.stringify({ p_slug: slug }),
      signal: AbortSignal.timeout(3000),
    });
    if (!response.ok) return "error";
    const route = (await response.json()) as Route;
    if (cache.size > 2000) cache.clear();
    cache.set(slug, { at: Date.now(), route });
    return route;
  } catch {
    return "error";
  }
}

/**
 * Shows another page under this address with the given status. A plain
 * rewrite keeps the status in development but loses it in production: the
 * target page comes from the static cache and is sent as 200, which search
 * engines read as a "soft 404". So the page is fetched here and sent on with
 * the right status. The targets are outside this proxy's matcher (no loop).
 */
async function showWithStatus(request: NextRequest, path: string, status: 404 | 410) {
  const target = new URL(path, request.url);
  // Only page loads (browsers, crawlers) ask for HTML. In-app navigation asks
  // for React data instead (Next.js hides its own headers from the proxy), and
  // the status doesn't matter there, so it gets the usual rewrite.
  if (!request.headers.get("accept")?.includes("text/html")) return NextResponse.rewrite(target, { status });
  try {
    const page = await fetch(target, {
      headers: { accept: "text/html" },
      signal: AbortSignal.timeout(5000),
    });
    if (page.ok) {
      const headers = new Headers(page.headers);
      for (const name of ["content-encoding", "content-length", "transfer-encoding", "connection"]) {
        headers.delete(name);
      }
      return new NextResponse(page.body, { status, headers });
    }
  } catch {
    // Fall through to the rewrite: the right page, if not the right status.
  }
  return NextResponse.rewrite(target, { status });
}

export async function proxy(request: NextRequest) {
  let slug = "";
  try {
    slug = decodeURIComponent(request.nextUrl.pathname.slice("/land/".length));
  } catch {
    // Malformed escapes (e.g. /land/%E0%A4) are "not found", not a server error.
  }
  if (!slugPattern.test(slug) || slug.length > 120) {
    return showWithStatus(request, "/listing-not-found", 404);
  }

  const route = await lookup(slug);
  // If the database can't be reached, let the page try (it shows its own error).
  if (route === "error") return NextResponse.next();
  if (route == null) return showWithStatus(request, "/listing-not-found", 404);
  if (route.state === "archived") return showWithStatus(request, `/no-longer-available/${route.slug}`, 410);
  if (route.slug !== slug) {
    return NextResponse.redirect(new URL(`/land/${route.slug}${request.nextUrl.search}`, request.url), 301);
  }
  return NextResponse.next();
}

export const config = { matcher: "/land/:slug" };
