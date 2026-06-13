"use server";

import { revalidatePath } from "next/cache";
import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";

export async function markPayoutPaid(
  payoutId: string,
  utr: string,
  mode: string,
  notes: string,
): Promise<{ ok: true } | { ok: false; error: string }> {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { error } = await supabase.rpc("admin_mark_engineer_payout_paid", {
    p_payout_id: payoutId,
    p_utr: utr || null,
    p_mode: mode || null,
    p_notes: notes || null,
  });
  if (error) {
    console.error("admin_mark_engineer_payout_paid failed:", error);
    return { ok: false, error: "Could not mark payout paid. Check server logs." };
  }
  revalidatePath("/payouts");
  return { ok: true };
}

export async function cancelPayout(
  payoutId: string,
  reason: string,
): Promise<{ ok: true } | { ok: false; error: string }> {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { error } = await supabase.rpc("admin_cancel_engineer_payout", {
    p_payout_id: payoutId,
    p_reason: reason,
  });
  if (error) {
    console.error("admin_cancel_engineer_payout failed:", error);
    return { ok: false, error: "Could not cancel payout. Check server logs." };
  }
  revalidatePath("/payouts");
  return { ok: true };
}
