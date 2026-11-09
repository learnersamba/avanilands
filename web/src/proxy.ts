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

export async function proxy(request: NextRequest) {
  const slug = decodeURIComponent(request.nextUrl.pathname.slice("/land/".length));
  if (!slugPattern.test(slug) || slug.length > 120) {
    return NextResponse.rewrite(new URL("/listing-not-found", request.url), { status: 404 });
  }

  const route = await lookup(slug);
  // If the database can't be reached, let the page try (it shows its own error).
  if (route === "error") return NextResponse.next();
  if (route == null) return NextResponse.rewrite(new URL("/listing-not-found", request.url), { status: 404 });
  if (route.state === "archived") {
    return NextResponse.rewrite(new URL(`/no-longer-available/${route.slug}`, request.url), { status: 410 });
  }
  if (route.slug !== slug) {
    return NextResponse.redirect(new URL(`/land/${route.slug}${request.nextUrl.search}`, request.url), 301);
  }
  return NextResponse.next();
}

export const config = { matcher: "/land/:slug" };
