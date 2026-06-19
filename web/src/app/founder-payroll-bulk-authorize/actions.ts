"use server";

import { revalidatePath } from "next/cache";
import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";

export async function dryRunPayroll(_formData: FormData) {
  await requireFounder();
  revalidatePath("/founder-payroll-bulk-authorize");
}

export async function createDraftBatch(formData: FormData) {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const period_start = String(formData.get("period_start") ?? "").trim();
  const period_end = String(formData.get("period_end") ?? "").trim();
  if (!period_start || !period_end) return;
  await supabase.rpc("log_founder_payroll_batch_create", {
    p_period_start: period_start,
    p_period_end: period_end,
  });
  revalidatePath("/founder-payroll-bulk-authorize");
}

export async function authorizeBatch(formData: FormData) {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const batch_id = String(formData.get("batch_id") ?? "").trim();
  if (!batch_id) return;
  await supabase.rpc("log_founder_payroll_batch_authorize", { p_batch_id: batch_id });
  revalidatePath("/founder-payroll-bulk-authorize");
}

export async function setBatchStatus(formData: FormData) {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const batch_id = String(formData.get("batch_id") ?? "").trim();
  const new_status = String(formData.get("new_status") ?? "").trim();
  const note = String(formData.get("note") ?? "").trim() || null;
  if (!batch_id || !new_status) return;
  await supabase.rpc("log_founder_payroll_batch_status", {
    p_batch_id: batch_id,
    p_new_status: new_status,
    p_note: note,
  });
  revalidatePath("/founder-payroll-bulk-authorize");
}
