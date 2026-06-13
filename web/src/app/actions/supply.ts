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

export async function recordBondedIntake(input: {
  supplierId: string;
  invoiceNo: string;
  invoiceDate: string; // YYYY-MM-DD
  invoiceUrl: string;
  oemBrand: string;
  partNumber: string;
  partDescription: string;
  quantity: number;
  unitCostRupees: number;
  tamperQrCodes: string[];
}): Promise<{ ok: true; id: string } | { ok: false; error: string }> {
  await requireFounder();

  if (!input.supplierId) return { ok: false, error: "Supplier required" };
  if (!input.invoiceNo.trim()) return { ok: false, error: "Vendor invoice no required" };
  if (!input.invoiceDate) return { ok: false, error: "Invoice date required" };
  if (input.quantity < 1) return { ok: false, error: "Quantity must be >= 1" };
  if (input.unitCostRupees <= 0) return { ok: false, error: "Unit cost must be > 0" };
  const codes = input.tamperQrCodes.map((c) => c.trim()).filter(Boolean);
  if (codes.length !== input.quantity) {
    return {
      ok: false,
      error: `QR code count (${codes.length}) must equal quantity (${input.quantity}).`,
    };
  }
  if (new Set(codes).size !== codes.length) {
    return { ok: false, error: "Duplicate QR codes in submission." };
  }

  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_record_bonded_intake", {
    p_supplier_id: input.supplierId,
    p_vendor_invoice_no: input.invoiceNo.trim(),
    p_vendor_invoice_date: input.invoiceDate,
    p_vendor_invoice_url: input.invoiceUrl.trim(),
    p_oem_brand: input.oemBrand.trim(),
    p_part_number: input.partNumber.trim(),
    p_part_description: input.partDescription.trim(),
    p_quantity_received: input.quantity,
    p_unit_cost_rupees: input.unitCostRupees,
    p_tamper_qr_codes: codes,
  });
  if (error) return { ok: false, error: error.message };
  revalidatePath("/supply");
  return { ok: true, id: String(data) };
}
