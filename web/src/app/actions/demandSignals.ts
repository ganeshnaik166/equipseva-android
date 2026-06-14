"use server";

import { revalidatePath } from "next/cache";
import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";

const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

const VIA_VALUES = [
  "supplier_onboarded",
  "bonded_intake",
  "duplicate_of_existing",
  "wont_fulfill",
  "fulfilled_offplatform",
] as const;
type ResolvedVia = (typeof VIA_VALUES)[number];

const PRIORITY_VALUES = ["low", "med", "high"] as const;
type Priority = (typeof PRIORITY_VALUES)[number];

export async function resolveDemandSignal(
  signalId: string,
  via: string,
  notes: string,
): Promise<{ ok: true } | { ok: false; error: string }> {
  await requireFounder();
  if (!UUID_RE.test(signalId)) return { ok: false, error: "Invalid signal id UUID" };
  if (!VIA_VALUES.includes(via as ResolvedVia))
    return { ok: false, error: `via must be one of: ${VIA_VALUES.join(", ")}` };
  const reason = (notes ?? "").trim();
  if (reason.length < 10) return { ok: false, error: "Notes min 10 chars (forensic record)" };
  const supabase = await getSupabaseServerClient();
  const { error } = await supabase.rpc("founder_resolve_demand_signal", {
    p_id: signalId,
    p_via: via,
    p_notes: reason,
  });
  if (error) {
    console.error("founder_resolve_demand_signal failed:", error);
    return { ok: false, error: "Could not resolve. Check server logs." };
  }
  revalidatePath("/demand-signals");
  return { ok: true };
}

export async function setDemandSignalPriority(
  anySignalId: string,
  priority: string,
): Promise<{ ok: true; affected: number } | { ok: false; error: string }> {
  await requireFounder();
  if (!UUID_RE.test(anySignalId))
    return { ok: false, error: "Invalid signal id UUID" };
  if (!PRIORITY_VALUES.includes(priority as Priority))
    return { ok: false, error: `priority must be one of: ${PRIORITY_VALUES.join(", ")}` };
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_set_demand_signal_priority", {
    p_any_signal_id: anySignalId,
    p_priority: priority,
  });
  if (error) {
    console.error("founder_set_demand_signal_priority failed:", error);
    return { ok: false, error: "Could not set priority. Check server logs." };
  }
  revalidatePath("/demand-signals");
  return { ok: true, affected: Number(data ?? 0) };
}
