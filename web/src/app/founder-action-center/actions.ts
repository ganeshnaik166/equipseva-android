"use server";

import { getSupabaseServerClient } from "@/lib/supabase/server";
import { requireFounder } from "@/lib/auth/requireFounder";
import { revalidatePath } from "next/cache";

export async function logFounderActionAction(formData: FormData) {
  await requireFounder();
  const source_domain = String(formData.get("source_domain") ?? "");
  const item_kind = String(formData.get("item_kind") ?? "");
  const source_item_id = String(formData.get("source_item_id") ?? "");
  const action_taken = String(formData.get("action_taken") ?? "");
  const note = (formData.get("note") as string) || null;

  if (!source_domain || !item_kind || !source_item_id || !action_taken) {
    throw new Error("missing required field");
  }
  if (!["acked", "resolved", "escalated", "ignored"].includes(action_taken)) {
    throw new Error(`invalid action_taken: ${action_taken}`);
  }

  const supabase = await getSupabaseServerClient();
  const { error } = await supabase.rpc("log_founder_priority_action", {
    p_source_domain: source_domain,
    p_item_kind: item_kind,
    p_source_item_id: source_item_id,
    p_action_taken: action_taken,
    p_note: note,
  });
  if (error) throw new Error(`log_founder_priority_action: ${error.message}`);

  revalidatePath("/founder-action-center");
}
