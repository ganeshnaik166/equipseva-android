"use server";

import { revalidatePath } from "next/cache";
import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";

export type GrievanceStatus = "in_progress" | "resolved" | "rejected";

export async function resolveGrievance(
  grievanceId: string,
  newStatus: GrievanceStatus,
  resolution: string,
): Promise<{ ok: true } | { ok: false; error: string }> {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { error } = await supabase.rpc("founder_resolve_grievance", {
    p_grievance_id: grievanceId,
    p_new_status: newStatus,
    p_resolution: resolution,
  });
  if (error) {
    // r529 (audit-12 LOW) — log raw error server-side, return generic
    // message to client so we don't leak RPC internals through an
    // already-authenticated channel.
    console.error("founder_resolve_grievance failed:", error);
    return { ok: false, error: "Could not resolve grievance. Check server logs." };
  }
  revalidatePath("/dpdp");
  return { ok: true };
}
