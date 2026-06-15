"use server";

import { revalidatePath } from "next/cache";
import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";

const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

export async function revokeSupervision(
  assignmentId: string,
  reason: string,
): Promise<{ ok: true } | { ok: false; error: string }> {
  await requireFounder();
  if (!UUID_RE.test(assignmentId))
    return { ok: false, error: "Invalid assignment_id UUID" };
  if (reason.trim().length < 10)
    return { ok: false, error: "Reason min 10 chars (audit ledger)" };
  const supabase = await getSupabaseServerClient();
  const { error } = await supabase.rpc("founder_revoke_supervision", {
    p_assignment_id: assignmentId,
    p_reason: reason.trim(),
  });
  if (error) {
    console.error("founder_revoke_supervision failed:", error);
    return { ok: false, error: error.message ?? "Could not revoke. Check server logs." };
  }
  revalidatePath("/training");
  return { ok: true };
}
