"use client";

import { createBrowserClient } from "@supabase/ssr";
import type { SupabaseClient } from "@supabase/supabase-js";

import { env } from "@/lib/env";

let client: SupabaseClient | null = null;

/**
 * The signed-in customer's client in the browser. The session lives in
 * cookies (so server actions can see who is signed in) and refreshes itself.
 * Row rules limit it to the customer's own data.
 */
export function browserSupabase(): SupabaseClient {
  client ??= createBrowserClient(env.supabaseUrl, env.supabasePublishableKey);
  return client;
}
