"use server";

import { revalidatePath } from "next/cache";
import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";

export async function forceReleaseEscrow(
  escrowId: string,
  reason: string,
): Promise<{ ok: true } | { ok: false; error: string }> {
  await requireFounder();
  if (reason.trim().length < 10) {
    return { ok: false, error: "Reason min 10 chars (founder forensic record)" };
  }
  const supabase = await getSupabaseServerClient();
  const { error } = await supabase.rpc("founder_force_release_escrow", {
    p_escrow_id: escrowId,
    p_reason: reason.trim(),
  });
  if (error) return { ok: false, error: error.message };
  revalidatePath("/disputes");
  return { ok: true };
}
