"use server";

import { revalidatePath } from "next/cache";
import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";

export async function registerHospitalChain(formData: FormData) {
  await requireFounder();
  const supabase = await getSupabaseServerClient();

  const chain_name = String(formData.get("chain_name") ?? "").trim();
  if (!chain_name) return;

  const signer_name = String(formData.get("signer_name") ?? "").trim() || null;
  const signer_email = String(formData.get("signer_email") ?? "").trim() || null;
  const signer_phone = String(formData.get("signer_phone") ?? "").trim() || null;
  const amc_tier = String(formData.get("amc_tier") ?? "").trim() || null;
  const monthly_fee_raw = String(formData.get("monthly_fee_rupees") ?? "").trim();
  const target_raw = String(formData.get("target_hospitals") ?? "").trim();

  await supabase.rpc("log_founder_hospital_chain_register", {
    p_chain_name: chain_name,
    p_signer_name: signer_name,
    p_signer_email: signer_email,
    p_signer_phone: signer_phone,
    p_amc_tier: amc_tier,
    p_monthly_fee_rupees: monthly_fee_raw ? Number(monthly_fee_raw) : null,
    p_target_hospitals: target_raw ? Number(target_raw) : 0,
  });

  revalidatePath("/hospital-chains-bulk-import");
}
