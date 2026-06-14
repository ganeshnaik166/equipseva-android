"use server";

import { revalidatePath } from "next/cache";
import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";

const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const GSTIN_RE = /^[0-9]{2}[A-Z]{5}[0-9]{4}[A-Z][0-9A-Z]{3}$/;

export async function registerHospitalChain(input: {
  name: string;
  primaryAdminUserId: string;
  billingGstin?: string;
  notes?: string;
}): Promise<{ ok: true; id: string } | { ok: false; error: string }> {
  await requireFounder();

  const name = input.name.trim();
  if (name.length < 3) return { ok: false, error: "Chain name min 3 chars" };
  if (!UUID_RE.test(input.primaryAdminUserId)) {
    return { ok: false, error: "primary_admin_user_id must be a valid UUID" };
  }
  const gstin = (input.billingGstin ?? "").trim().toUpperCase();
  if (gstin.length > 0 && !GSTIN_RE.test(gstin)) {
    return { ok: false, error: "GSTIN format invalid (15-char Indian GSTIN)" };
  }

  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_register_hospital_chain", {
    p_name: name,
    p_primary_admin_user_id: input.primaryAdminUserId,
    p_billing_gstin: gstin || null,
    p_notes: input.notes?.trim() || null,
  });
  if (error) {
    console.error("founder_register_hospital_chain failed:", error);
    return { ok: false, error: "Could not register chain. Check server logs." };
  }
  revalidatePath("/chains");
  return { ok: true, id: String(data) };
}
