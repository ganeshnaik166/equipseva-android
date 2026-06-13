"use server";

import { revalidatePath } from "next/cache";
import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";

export async function approveRefund(
  requestId: string,
  note: string,
): Promise<{ ok: true } | { ok: false; error: string }> {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { error } = await supabase.rpc("approve_refund_authorization", {
    p_request_id: requestId,
    p_approver_note: note,
  });
  if (error) {
    console.error("approve_refund_authorization failed:", error);
    return { ok: false, error: "Could not approve refund. Check server logs." };
  }
  revalidatePath("/refunds");
  return { ok: true };
}

export async function rejectRefund(
  requestId: string,
  reason: string,
): Promise<{ ok: true } | { ok: false; error: string }> {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { error } = await supabase.rpc("reject_refund_authorization", {
    p_request_id: requestId,
    p_reject_reason: reason,
  });
  if (error) {
    console.error("reject_refund_authorization failed:", error);
    return { ok: false, error: "Could not reject refund. Check server logs." };
  }
  revalidatePath("/refunds");
  return { ok: true };
}
