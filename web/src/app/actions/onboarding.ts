"use server";

import { revalidatePath } from "next/cache";
import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";

export type VerificationStatus = "verified" | "rejected" | "pending";

export async function setEngineerVerification(
  userId: string,
  status: VerificationStatus,
  reason: string | null,
  rejectedDocTypes: string[] | null,
): Promise<{ ok: true } | { ok: false; error: string }> {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { error } = await supabase.rpc("admin_set_engineer_verification", {
    p_user_id: userId,
    p_status: status,
    p_reason: reason,
    p_rejected_doc_types: rejectedDocTypes,
  });
  if (error) {
    console.error("admin_set_engineer_verification failed:", error);
    return { ok: false, error: "Could not update verification. Check server logs." };
  }
  revalidatePath("/onboarding");
  return { ok: true };
}
