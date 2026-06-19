"use server";

import { getSupabaseServerClient } from "@/lib/supabase/server";
import { requireFounder } from "@/lib/auth/requireFounder";
import { revalidatePath } from "next/cache";

export async function resolveIncidentAction(formData: FormData) {
  await requireFounder();
  const incident_id = String(formData.get("incident_id") ?? "");
  const root_cause = String(formData.get("root_cause") ?? "");
  const postmortem = (formData.get("postmortem") as string) || null;
  if (!incident_id || !root_cause) throw new Error("incident_id + root_cause required");
  const supabase = await getSupabaseServerClient();
  const { error } = await supabase.rpc("founder_resolve_incident", {
    p_incident_id: incident_id,
    p_root_cause: root_cause,
    p_postmortem: postmortem,
  });
  if (error) throw new Error(`founder_resolve_incident: ${error.message}`);
  revalidatePath("/founder-incidents");
}
