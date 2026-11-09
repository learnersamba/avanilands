import { z } from "zod";

// Public settings (safe in the browser). Read with literal `process.env.X`
// so Next.js can inline them at build time.
const publicEnv = z
  .object({
    NEXT_PUBLIC_SITE_URL: z.url(),
    NEXT_PUBLIC_SUPABASE_URL: z.url(),
    NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY: z.string().min(1),
  })
  .parse({
    NEXT_PUBLIC_SITE_URL: process.env.NEXT_PUBLIC_SITE_URL,
    NEXT_PUBLIC_SUPABASE_URL: process.env.NEXT_PUBLIC_SUPABASE_URL,
    NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY: process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY,
  });

export const env = {
  siteUrl: publicEnv.NEXT_PUBLIC_SITE_URL,
  supabaseUrl: publicEnv.NEXT_PUBLIC_SUPABASE_URL,
  supabasePublishableKey: publicEnv.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY,
};
