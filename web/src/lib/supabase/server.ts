import "server-only";

import { createServerClient } from "@supabase/ssr";
import { cookies } from "next/headers";

import { env } from "@/lib/env";

/**
 * Who is signed in, for server actions (pages stay cached and never read
 * cookies). Returns null for guests. getUser() asks Supabase to confirm the
 * session, so a forged cookie can't pass.
 */
export async function currentCustomer(): Promise<{ id: string; email: string | null } | null> {
  const store = await cookies();
  const supabase = createServerClient(env.supabaseUrl, env.supabasePublishableKey, {
    cookies: {
      getAll: () => store.getAll(),
      setAll: (list) => {
        try {
          for (const { name, value, options } of list) store.set(name, value, options);
        } catch {
          // Called during rendering: the browser refreshes the session itself.
        }
      },
    },
  });
  const { data } = await supabase.auth.getUser();
  return data.user ? { id: data.user.id, email: data.user.email ?? null } : null;
}
