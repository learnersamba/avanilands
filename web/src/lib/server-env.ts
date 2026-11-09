import "server-only";

import { z } from "zod";

/** Server-only secrets. Read on first use so pages that don't need them still build. */
export function serverEnv() {
  return z
    .object({
      SUPABASE_SECRET_KEY: z.string().min(20),
      REVALIDATE_SECRET: z.string().min(24),
    })
    .parse({
      SUPABASE_SECRET_KEY: process.env.SUPABASE_SECRET_KEY,
      REVALIDATE_SECRET: process.env.REVALIDATE_SECRET,
    });
}
