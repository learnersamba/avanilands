import "server-only";

import { createClient } from "@supabase/supabase-js";

import { env } from "@/lib/env";

/**
 * Anonymous, cookie-less client for public data (published properties,
 * lookups). RLS limits it to what any visitor may see, and because it does
 * not touch cookies its results can be cached.
 */
export function createPublicClient() {
  return createClient(env.supabaseUrl, env.supabasePublishableKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
}
