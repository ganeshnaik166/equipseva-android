// Supabase edge function: generate_repair_invoice
//
// Round 449 — GST tax invoice for completed repair_jobs.
//
// Caller flow (mirrors generate_service_report):
//   1. Hospital taps "Download invoice" on a completed repair_job
//   2. Client POSTs { job_id } here with their JWT
//   3. We auth as the caller; RLS on the get_repair_invoice_payload
//      RPC gates the SELECT
//   4. Render an HTML tax invoice (browser print-to-PDF lands a
//      valid B2B GST invoice)
//   5. Upload via service-role to invoices/repair_<job_id>.html
//   6. Return a 15-min signed URL
//
// Round 463 — render + supplier-env reader extracted to _shared so the
// auto-fire (dispatch_repair_invoice) and daily digest fns reuse them.
//
// Required env (supplier identity baked into the invoice):
//   SUPABASE_URL, SUPABASE_ANON_KEY, SUPABASE_SERVICE_ROLE_KEY
//   SUPPLIER_LEGAL_NAME       (e.g. "Dhanavath Ganesh Naik")
//   SUPPLIER_TRADE_NAME       (e.g. "EquipSeva")
//   SUPPLIER_GSTIN            (the GSTIN that was approved 2026-06-03)
//   SUPPLIER_ADDRESS          (multi-line, kept short for invoice header)
//   SUPPLIER_STATE            (e.g. "Telangana" — drives intra/inter
//                              GST split against buyer state)
//   SUPPLIER_STATE_CODE       (e.g. "36" for Telangana — needed for
//                              place of supply column)
//   SUPPLIER_PINCODE
//   SUPPLIER_EMAIL            (optional, for footer contact)
//   SUPPLIER_PHONE            (optional, for footer contact)

import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.45.4";
import {
  type InvoicePayload,
  readSupplierEnv,
  renderInvoiceHtml,
  supplierIsConfigured,
} from "../_shared/repair_invoice_render.ts";

const json = (status: number, body: unknown) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { "content-type": "application/json" },
  });

const bad = (code: string, message: string, status = 400) =>
  json(status, { ok: false, code, message });

serve(async (req) => {
  if (req.method !== "POST") return bad("bad_request", "POST only", 405);

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY");
  if (!supabaseUrl || !serviceKey || !anonKey) {
    return bad("server_error", "edge function not configured", 500);
  }

  const supplier = readSupplierEnv();
  if (!supplierIsConfigured(supplier)) {
    console.error("generate_repair_invoice: supplier env incomplete");
    return bad("server_error", "supplier identity unset", 500);
  }

  const authHeader = req.headers.get("authorization") ?? "";
  if (!authHeader.toLowerCase().startsWith("bearer ")) {
    return bad("unauthenticated", "missing bearer token", 401);
  }

  let body: { job_id?: string };
  try {
    body = await req.json();
  } catch {
    return bad("bad_request", "invalid json");
  }
  const jobId = body?.job_id;
  if (!jobId) return bad("bad_request", "missing job_id");

  // Caller-scoped client — uses the user JWT, so the RLS gate inside
  // get_repair_invoice_payload runs against the caller.
  const callerClient = createClient(supabaseUrl, anonKey, {
    global: { headers: { Authorization: authHeader } },
  });

  const { data, error } = await callerClient.rpc("get_repair_invoice_payload", {
    p_job_id: jobId,
  });
  if (error) {
    console.error("generate_repair_invoice rpc error", error);
    return bad("server_error", "invoice fetch failed", 500);
  }
  const rows = (data as InvoicePayload[] | null) ?? [];
  if (rows.length === 0) {
    return bad("not_found", "no access or job not completed", 404);
  }
  const payload = rows[0];

  const html = renderInvoiceHtml(payload, supplier);

  // Upload via service-role to the existing `invoices` Storage bucket.
  // Filename prefix `repair_` distinguishes from spare-part invoices
  // (which use the order UUID alone).
  const admin = createClient(supabaseUrl, serviceKey);
  const path = `repair_${jobId}.html`;
  const upload = await admin.storage
    .from("invoices")
    .upload(path, new Blob([html], { type: "text/html" }), {
      upsert: true,
      contentType: "text/html",
    });
  if (upload.error) {
    console.error("generate_repair_invoice upload failed", upload.error?.message ?? "");
    return bad("server_error", "invoice upload failed", 500);
  }

  // Round 451: TTL dropped from 30 days → 15 minutes. Called from the
  // Android app (RepairInvoiceRepository.generate); user opens URL
  // immediately via Intent.ACTION_VIEW. Idempotent re-mint is one tap
  // away. 30-day bearer-token URL bypassing RLS was a leak amplifier
  // (the invoice carries hospital name, address, GSTIN, amounts).
  const { data: signed, error: signErr } = await admin.storage
    .from("invoices")
    .createSignedUrl(path, 60 * 15);
  if (signErr || !signed?.signedUrl) {
    console.error("generate_repair_invoice sign failed", signErr?.message ?? "");
    return bad("server_error", "invoice sign failed", 500);
  }

  return json(200, {
    ok: true,
    invoice_number: payload.invoice_number,
    invoice_url: signed.signedUrl,
    gross_rupees: payload.gross_rupees,
    taxable_value: payload.taxable_value,
    gst_total: payload.gst_total,
  });
});
