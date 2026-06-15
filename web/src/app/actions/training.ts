"use server";

import { revalidatePath } from "next/cache";
import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";

const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const TIER_VALUES = ["none", "bronze", "silver", "gold"] as const;
type Tier = (typeof TIER_VALUES)[number];

export async function setTierSupervisedThreshold(
  tier: string,
  min: number,
): Promise<{ ok: true } | { ok: false; error: string }> {
  await requireFounder();
  if (!TIER_VALUES.includes(tier as Tier))
    return { ok: false, error: `tier must be one of: ${TIER_VALUES.join(", ")}` };
  if (!Number.isInteger(min) || min < 0 || min > 100)
    return { ok: false, error: "min must be a non-negative integer ≤ 100" };
  const supabase = await getSupabaseServerClient();
  const { error } = await supabase.rpc("founder_set_tier_supervised_threshold", {
    p_tier: tier,
    p_min: min,
  });
  if (error) {
    console.error("founder_set_tier_supervised_threshold failed:", error);
    return { ok: false, error: error.message ?? "Could not set threshold." };
  }
  revalidatePath("/training");
  return { ok: true };
}

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
