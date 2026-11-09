"use server";

import { createAdminClient } from "@/lib/supabase/admin";
import { currentCustomer } from "@/lib/supabase/server";

/**
 * Deletes the signed-in customer's account. Their profile and saved
 * properties go with it; enquiries and visits stay with the team, unlinked.
 * Staff accounts are never deleted here (a super admin removes those).
 */
export async function deleteMyAccount(): Promise<
  { ok: true } | { ok: false; message: string }
> {
  const customer = await currentCustomer();
  if (!customer) return { ok: false, message: "Please sign in again first." };
  const admin = createAdminClient();
  const { data: staff } = await admin
    .from("admin_users")
    .select("user_id")
    .eq("user_id", customer.id)
    .maybeSingle();
  if (staff)
    return {
      ok: false,
      message: "This is a staff account. Ask a super admin to remove it.",
    };
  const { error } = await admin.auth.admin.deleteUser(customer.id);
  if (error) {
    console.error("Account deletion failed", error);
    return {
      ok: false,
      message:
        "We couldn't delete the account. Please try again or contact us.",
    };
  }
  return { ok: true };
}
