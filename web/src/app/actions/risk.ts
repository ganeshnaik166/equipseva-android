"use server";

import { revalidatePath } from "next/cache";
import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";

export type ResolveStatus = "confirmed" | "false_positive" | "resolved";

export async function resolveCollusionFlag(
  flagId: string,
  status: ResolveStatus,
  note: string,
): Promise<{ ok: true } | { ok: false; error: string }> {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { error } = await supabase.rpc("founder_resolve_collusion_flag", {
    p_flag_id: flagId,
    p_status: status,
    p_note: note,
  });
  if (error) {
    // r537 audit-13 LOW — log raw error server-side, return generic
    // message to client so we don't leak Postgres constraint names.
    console.error("founder_resolve_collusion_flag failed:", error);
    return { ok: false, error: "Could not resolve flag. Check server logs." };
  }
  revalidatePath("/risk");
  return { ok: true };
}

export async function resolveDuplicateFlag(
  flagId: string,
  status: ResolveStatus,
  note: string,
): Promise<{ ok: true } | { ok: false; error: string }> {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { error } = await supabase.rpc("founder_resolve_duplicate_flag", {
    p_flag_id: flagId,
    p_status: status,
    p_note: note,
  });
  if (error) {
    console.error("founder_resolve_duplicate_flag failed:", error);
    return { ok: false, error: "Could not resolve flag. Check server logs." };
  }
  revalidatePath("/risk");
  return { ok: true };
}
