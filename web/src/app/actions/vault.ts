"use server";

import { revalidatePath } from "next/cache";
import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";

export type PackDecision = "accepted" | "rejected";

export async function decideEvidencePack(
  packId: string,
  decision: PackDecision,
  note: string,
): Promise<{ ok: true } | { ok: false; error: string }> {
  await requireFounder();
  if (note.trim().length < 5) {
    return { ok: false, error: "Mediator note min 5 chars (forensic record)" };
  }
  const supabase = await getSupabaseServerClient();
  const { error } = await supabase.rpc("founder_decide_dispute_pack", {
    p_pack_id: packId,
    p_decision: decision,
    p_note: note.trim(),
  });
  if (error) {
    console.error("founder_decide_dispute_pack failed:", error);
    return { ok: false, error: "Could not record decision. Check server logs." };
  }
  revalidatePath("/vault");
  return { ok: true };
}
