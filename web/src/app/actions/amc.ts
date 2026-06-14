"use server";

import { revalidatePath } from "next/cache";
import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";

const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const TIERS = new Set(["basic", "bronze", "silver", "gold"]);

export async function setAmcTier(
  contractId: string,
  tier: string,
  reason: string,
): Promise<{ ok: true } | { ok: false; error: string }> {
  await requireFounder();
  if (!UUID_RE.test(contractId))
    return { ok: false, error: "Invalid contract_id UUID" };
  if (!TIERS.has(tier))
    return { ok: false, error: "Tier must be one of basic / bronze / silver / gold" };
  if (reason.trim().length < 10)
    return { ok: false, error: "Reason min 10 chars (forensic record)" };

  const supabase = await getSupabaseServerClient();
  const { error } = await supabase.rpc("founder_set_amc_tier", {
    p_contract_id: contractId,
    p_target_tier: tier,
    p_reason: reason.trim(),
  });
  if (error) {
    console.error("founder_set_amc_tier failed:", error);
    return { ok: false, error: "Could not set AMC tier. Check server logs." };
  }
  revalidatePath("/amc");
  return { ok: true };
}
