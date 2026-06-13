"use server";

import { revalidatePath } from "next/cache";
import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";

export async function registerBondedSupplier(input: {
  name: string;
  gstin: string;
  tier: "OEM" | "AUTHORIZED" | "VERIFIED";
  brands: string[];
  email?: string;
  phone?: string;
}): Promise<{ ok: true; id: string } | { ok: false; error: string }> {
  await requireFounder();
  const supabase = await getSupabaseServerClient();

  // Server-side validation belt-and-suspenders; the RPC also enforces.
  if (input.name.trim().length < 3) return { ok: false, error: "Name min 3 chars" };
  if (!["OEM", "AUTHORIZED", "VERIFIED"].includes(input.tier)) {
    return { ok: false, error: "Invalid tier" };
  }
  if (!Array.isArray(input.brands) || input.brands.length === 0) {
    return { ok: false, error: "At least one OEM brand required" };
  }

  const { data, error } = await supabase.rpc("founder_register_bonded_supplier", {
    p_supplier_name: input.name.trim(),
    p_supplier_gstin: input.gstin.trim().toUpperCase(),
    p_supplier_tier: input.tier,
    p_oem_brands: input.brands.map((b) => b.trim()).filter(Boolean),
    p_contact_email: input.email?.trim() || null,
    p_contact_phone: input.phone?.trim() || null,
  });
  if (error) return { ok: false, error: error.message };
  revalidatePath("/supply");
  return { ok: true, id: String(data) };
}
