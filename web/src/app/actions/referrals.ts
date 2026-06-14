"use server";

import { revalidatePath } from "next/cache";
import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";

const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

export async function revokeReferralBounty(
  referralId: string,
  reason: string,
): Promise<{ ok: true } | { ok: false; error: string }> {
  await requireFounder();
  if (!UUID_RE.test(referralId))
    return { ok: false, error: "Invalid referral_id UUID" };
  if (reason.trim().length < 10)
    return { ok: false, error: "Reason min 10 chars (forensic record)" };
  const supabase = await getSupabaseServerClient();
  const { error } = await supabase.rpc("founder_revoke_referral_bounty", {
    p_referral_id: referralId,
    p_reason: reason.trim(),
  });
  if (error) {
    console.error("founder_revoke_referral_bounty failed:", error);
    return { ok: false, error: "Could not revoke bounty. Check server logs." };
  }
  revalidatePath("/referrals");
  return { ok: true };
}
