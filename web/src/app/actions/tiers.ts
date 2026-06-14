"use server";

import { revalidatePath } from "next/cache";
import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";

const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const TIERS = new Set(["none", "bronze", "silver", "gold"]);

export async function promoteEngineerTier(
  engineerUserId: string,
  tier: string,
  reason: string,
): Promise<{ ok: true } | { ok: false; error: string }> {
  await requireFounder();
  if (!UUID_RE.test(engineerUserId)) {
    return { ok: false, error: "Invalid engineer user_id UUID" };
  }
  if (!TIERS.has(tier)) {
    return { ok: false, error: "Tier must be one of none / bronze / silver / gold" };
  }
  if (reason.trim().length < 10) {
    return { ok: false, error: "Reason min 10 chars (forensic record)" };
  }
  const supabase = await getSupabaseServerClient();
  const { error } = await supabase.rpc("founder_promote_engineer_tier", {
    p_engineer_user_id: engineerUserId,
    p_target_tier: tier,
    p_reason: reason.trim(),
  });
  if (error) {
    console.error("founder_promote_engineer_tier failed:", error);
    return { ok: false, error: "Could not promote tier. Check server logs." };
  }
  revalidatePath(`/engineers/${engineerUserId}`);
  revalidatePath("/tiers");
  return { ok: true };
}
