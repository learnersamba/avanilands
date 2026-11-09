import type { NextConfig } from "next";

const supabase = process.env.NEXT_PUBLIC_SUPABASE_URL ?? "";
const isDev = process.env.NODE_ENV !== "production";
// Map tile server (property maps). Defaults to OpenStreetMap; at launch set
// NEXT_PUBLIC_MAP_TILE_URL to a provider with a plan for public traffic.
const tileOrigin = (() => {
  try {
    return new URL((process.env.NEXT_PUBLIC_MAP_TILE_URL ?? "").replace(/\{[a-z]\}/g, "a")).origin;
  } catch {
    return "https://tile.openstreetmap.org";
  }
})();

/**
 * Content-Security-Policy (docs/01-architecture.md §6). Next.js needs
 * inline scripts for its static pages; dev mode also needs eval for fast refresh.
 */
const csp = [
  "default-src 'self'",
  `script-src 'self' 'unsafe-inline' https://challenges.cloudflare.com${isDev ? " 'unsafe-eval'" : ""}`,
  "style-src 'self' 'unsafe-inline'",
  `img-src 'self' data: blob: ${supabase} https://img.youtube.com https://i.ytimg.com ${tileOrigin}`,
  "font-src 'self'",
  `connect-src 'self' ${supabase}${isDev ? " ws:" : ""}`,
  `media-src 'self' ${supabase}`,
  "frame-src https://www.youtube-nocookie.com https://www.youtube.com https://challenges.cloudflare.com",
  "object-src 'none'",
  "base-uri 'self'",
  "form-action 'self'",
  "frame-ancestors 'none'",
  isDev ? "" : "upgrade-insecure-requests",
]
  .filter(Boolean)
  .join("; ");

const securityHeaders = [
  { key: "Content-Security-Policy", value: csp },
  { key: "X-Content-Type-Options", value: "nosniff" },
  { key: "X-Frame-Options", value: "DENY" },
  { key: "Referrer-Policy", value: "strict-origin-when-cross-origin" },
  { key: "Permissions-Policy", value: "camera=(), microphone=(), geolocation=(), payment=()" },
  ...(isDev ? [] : [{ key: "Strict-Transport-Security", value: "max-age=63072000; includeSubDomains; preload" }]),
];

const nextConfig: NextConfig = {
  cacheComponents: true,
  partialPrefetching: true,
  poweredByHeader: false,
  // Crawlers and link previews get titles, descriptions and canonical links in
  // <head> (Google only trusts a canonical link there). This is Next.js's own
  // list plus Googlebot, which Next.js leaves out because it runs JavaScript.
  // People's browsers keep the streamed metadata: blocking it for everyone
  // left pages like /land without a static shell.
  htmlLimitedBots:
    /Googlebot|[\w-]+-Google|Google-[\w-]+|Chrome-Lighthouse|Slurp|DuckDuckBot|baiduspider|yandex|sogou|bitlybot|tumblr|vkShare|quora link preview|redditbot|ia_archiver|Bingbot|BingPreview|applebot|facebookexternalhit|facebookcatalog|Twitterbot|LinkedInBot|Slackbot|Discordbot|WhatsApp|SkypeUriPreview|Yeti|googleweblight/,
  turbopack: {
    rules: {
      "*.css": {
        loaders: ["@tailwindcss/turbopack"],
        as: "*.css",
      },
    },
  },
  async headers() {
    return [{ source: "/:path*", headers: securityHeaders }];
  },
};

export default nextConfig;
