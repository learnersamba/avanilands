import "server-only";

import { createClient } from "@supabase/supabase-js";

import { env } from "@/lib/env";
import { serverEnv } from "@/lib/server-env";

/**
 * Client with the secret key: bypasses row rules. Server code only, and only
 * for the few things visitors can't do themselves (signed document links,
 * Phase 8 enquiries). Always check permissions before using it.
 */
export function createAdminClient() {
  return createClient(env.supabaseUrl, serverEnv().SUPABASE_SECRET_KEY, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
}
