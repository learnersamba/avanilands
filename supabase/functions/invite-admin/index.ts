// Invite a new admin by email. Super admins only.
//
// POST { full_name, email, role: "admin" | "super_admin", redirect_to }
// → 200 { user_id, email } or 4xx { error: "<sentence for the admin>" }
//
// The admin_users row is inserted with the CALLER's token, so the database
// checks the caller is a super admin again (RLS) and the audit log records
// who invited whom. Only the invitation itself needs the service key.
import { createClient } from "npm:@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const EMAIL = /^[^@\s]+@[^@\s]+\.[^@\s]+$/;

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return json({ error: "Method not allowed." }, 405);

  const url = Deno.env.get("SUPABASE_URL")!;
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY")!;
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

  const caller = createClient(url, anonKey, {
    global: { headers: { Authorization: req.headers.get("Authorization") ?? "" } },
    auth: { persistSession: false, autoRefreshToken: false },
  });
  const { data: isSuperAdmin, error: roleError } = await caller.rpc("is_super_admin");
  if (roleError || isSuperAdmin !== true) {
    return json({ error: "Only a super admin can invite admins." }, 403);
  }

  let body: Record<string, unknown>;
  try {
    body = await req.json();
  } catch {
    return json({ error: "Invalid request." }, 400);
  }
  const fullName = String(body.full_name ?? "").trim();
  const email = String(body.email ?? "").trim().toLowerCase();
  const role = body.role === "super_admin" ? "super_admin" : "admin";
  const redirectTo = typeof body.redirect_to === "string" ? body.redirect_to : undefined;

  if (fullName.length < 1 || fullName.length > 80) {
    return json({ error: "Enter a name (up to 80 characters)." }, 400);
  }
  if (!EMAIL.test(email) || email.length > 254) {
    return json({ error: "Enter a valid email." }, 400);
  }

  const { data: existing, error: lookupError } = await caller
    .from("admin_users")
    .select("is_active")
    .eq("email", email)
    .maybeSingle();
  if (lookupError) return json({ error: "Could not check the admin list. Try again." }, 500);
  if (existing) {
    return json(
      {
        error: existing.is_active
          ? "This person is already an admin."
          : "This person is a deactivated admin. Reactivate them instead.",
      },
      409,
    );
  }

  const service = createClient(url, serviceKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
  const { data: invited, error: inviteError } = await service.auth.admin.inviteUserByEmail(email, {
    redirectTo,
    data: { name: fullName },
  });
  if (inviteError || !invited?.user) {
    const exists = /already|registered|exists/i.test(inviteError?.message ?? "");
    return json(
      {
        error: exists
          ? "Someone with this email already has an account."
          : `Could not send the invitation: ${inviteError?.message ?? "unknown error"}.`,
      },
      exists ? 409 : 400,
    );
  }

  const { error: insertError } = await caller
    .from("admin_users")
    .insert({ user_id: invited.user.id, full_name: fullName, email, role });
  if (insertError) {
    // Don't leave a login behind that has no admin record — but only remove
    // one this request created, never an existing account.
    const createdNow = Date.now() - Date.parse(invited.user.created_at) < 60_000;
    if (createdNow) await service.auth.admin.deleteUser(invited.user.id);
    console.error("invite-admin insert failed", insertError);
    return json({ error: "The invitation was sent but the admin could not be added. Try again." }, 500);
  }

  return json({ user_id: invited.user.id, email });
});
