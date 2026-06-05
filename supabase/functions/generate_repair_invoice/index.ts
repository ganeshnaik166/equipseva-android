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
//   6. Return a 30-day signed URL
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

const json = (status: number, body: unknown) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { "content-type": "application/json" },
  });

const bad = (code: string, message: string, status = 400) =>
  json(status, { ok: false, code, message });

const inr = (n: unknown) =>
  new Intl.NumberFormat("en-IN", {
    style: "currency",
    currency: "INR",
    minimumFractionDigits: 2,
  }).format(Number(n) || 0);

function esc(s: unknown): string {
  return String(s ?? "")
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;");
}

interface InvoicePayload {
  invoice_number: string;
  invoice_date: string;
  job_number: string | null;
  completed_at: string | null;
  hospital_name: string;
  hospital_email: string;
  hospital_phone: string;
  hospital_gstin: string | null;
  hospital_address: string;
  hospital_city: string;
  hospital_state: string;
  hospital_pincode: string;
  equipment_type: string | null;
  equipment_brand: string | null;
  equipment_model: string | null;
  equipment_serial: string | null;
  work_done: string | null;
  gross_rupees: number;
  taxable_value: number;
  gst_total: number;
  cgst: number;
  sgst: number;
  igst: number;
  hsn_sac_code: string;
  service_description: string;
}

interface SupplierEnv {
  legalName: string;
  tradeName: string;
  gstin: string;
  address: string;
  state: string;
  stateCode: string;
  pincode: string;
  email: string;
  phone: string;
}

function renderHtml(p: InvoicePayload, s: SupplierEnv): string {
  const interState =
    !!p.hospital_state &&
    p.hospital_state.trim().toLowerCase() !== s.state.trim().toLowerCase();
  // Re-split GST on inter-state — RPC returns intra-state default.
  const cgst = interState ? 0 : p.cgst;
  const sgst = interState ? 0 : p.sgst;
  const igst = interState ? p.gst_total : 0;
  const placeOfSupply = p.hospital_state
    ? esc(p.hospital_state)
    : esc(s.state);
  return `<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <title>Tax Invoice ${esc(p.invoice_number)}</title>
  <style>
    body { font-family: -apple-system, "Helvetica Neue", Arial, sans-serif; color: #111; margin: 0; padding: 24px; font-size: 13px; }
    h1 { font-size: 18px; margin: 0 0 4px; letter-spacing: 0.5px; }
    .muted { color: #666; }
    .hdr { display: flex; justify-content: space-between; gap: 24px; padding-bottom: 16px; border-bottom: 2px solid #111; }
    .hdr-l { max-width: 60%; }
    .hdr-r { text-align: right; }
    table { width: 100%; border-collapse: collapse; margin-top: 16px; font-size: 12px; }
    th, td { padding: 8px 10px; text-align: left; border-bottom: 1px solid #ddd; vertical-align: top; }
    th { background: #f5f5f5; font-weight: 600; font-size: 11px; text-transform: uppercase; letter-spacing: 0.4px; }
    .num { text-align: right; font-variant-numeric: tabular-nums; }
    .totals { width: 320px; margin-left: auto; margin-top: 16px; }
    .totals td { padding: 4px 8px; border: none; font-size: 13px; }
    .totals .row-total { border-top: 2px solid #111; font-weight: 700; font-size: 14px; }
    .meta { display: flex; gap: 32px; margin-top: 20px; flex-wrap: wrap; }
    .meta-block { flex: 1; min-width: 240px; }
    .meta-block h3 { font-size: 11px; text-transform: uppercase; letter-spacing: 0.4px; color: #666; margin: 0 0 6px; }
    .meta-block p { margin: 0; line-height: 1.5; }
    .footer { margin-top: 36px; padding-top: 12px; border-top: 1px solid #ddd; font-size: 11px; color: #666; }
    .badge { display: inline-block; padding: 2px 8px; border-radius: 10px; font-size: 10px; font-weight: 600; letter-spacing: 0.4px; }
    .badge-intra { background: #e6f4ea; color: #1f7038; }
    .badge-inter { background: #fef3c7; color: #92400e; }
    .print-btn { position: fixed; top: 16px; right: 16px; padding: 8px 16px; background: #111; color: white; border: 0; border-radius: 6px; cursor: pointer; font-size: 12px; }
    @media print { .print-btn { display: none; } body { padding: 0; } }
  </style>
</head>
<body>
  <button class="print-btn" onclick="window.print()">Print / Save as PDF</button>
  <div class="hdr">
    <div class="hdr-l">
      <h1>${esc(s.tradeName)}</h1>
      <div class="muted">${esc(s.legalName)}</div>
      <div class="muted" style="white-space: pre-line;">${esc(s.address)}</div>
      <div class="muted">${esc(s.state)} ${esc(s.pincode)}</div>
      <div style="margin-top: 6px;"><strong>GSTIN:</strong> ${esc(s.gstin)}</div>
      ${
        s.email
          ? `<div class="muted">${esc(s.email)}</div>`
          : ""
      }
      ${
        s.phone
          ? `<div class="muted">${esc(s.phone)}</div>`
          : ""
      }
    </div>
    <div class="hdr-r">
      <h1 style="font-size: 14px; letter-spacing: 1px;">TAX INVOICE</h1>
      <div class="muted">Invoice No.</div>
      <div style="font-weight: 600;">${esc(p.invoice_number)}</div>
      <div class="muted" style="margin-top: 8px;">Invoice Date</div>
      <div>${esc(p.invoice_date)}</div>
      <div class="muted" style="margin-top: 8px;">Place of Supply</div>
      <div>${placeOfSupply}</div>
      <div style="margin-top: 8px;">
        <span class="badge ${interState ? "badge-inter" : "badge-intra"}">
          ${interState ? "INTER-STATE (IGST)" : "INTRA-STATE (CGST + SGST)"}
        </span>
      </div>
    </div>
  </div>

  <div class="meta">
    <div class="meta-block">
      <h3>Billed To</h3>
      <p><strong>${esc(p.hospital_name)}</strong></p>
      ${
        p.hospital_address
          ? `<p style="white-space: pre-line;">${esc(p.hospital_address)}</p>`
          : ""
      }
      ${
        p.hospital_city || p.hospital_state || p.hospital_pincode
          ? `<p>${esc([p.hospital_city, p.hospital_state, p.hospital_pincode].filter(Boolean).join(", "))}</p>`
          : ""
      }
      ${
        p.hospital_gstin
          ? `<p><strong>GSTIN:</strong> ${esc(p.hospital_gstin)}</p>`
          : `<p class="muted">GSTIN not provided (unregistered buyer)</p>`
      }
      ${
        p.hospital_email
          ? `<p class="muted">${esc(p.hospital_email)}</p>`
          : ""
      }
    </div>
    <div class="meta-block">
      <h3>Service Reference</h3>
      <p><strong>Job:</strong> ${esc(p.job_number ?? "—")}</p>
      ${
        p.equipment_type
          ? `<p><strong>Equipment:</strong> ${esc(p.equipment_type)}${
              p.equipment_brand
                ? ` (${esc(p.equipment_brand)}${p.equipment_model ? " " + esc(p.equipment_model) : ""})`
                : ""
            }</p>`
          : ""
      }
      ${
        p.equipment_serial
          ? `<p class="muted"><strong>Serial:</strong> ${esc(p.equipment_serial)}</p>`
          : ""
      }
      ${
        p.completed_at
          ? `<p class="muted"><strong>Completed:</strong> ${esc(new Date(p.completed_at).toLocaleString("en-IN"))}</p>`
          : ""
      }
    </div>
  </div>

  <table>
    <thead>
      <tr>
        <th>#</th>
        <th>Service Description</th>
        <th>HSN/SAC</th>
        <th class="num">Taxable Value</th>
        ${
          interState
            ? `<th class="num">IGST (18%)</th>`
            : `<th class="num">CGST (9%)</th><th class="num">SGST (9%)</th>`
        }
        <th class="num">Total</th>
      </tr>
    </thead>
    <tbody>
      <tr>
        <td>1</td>
        <td>
          ${esc(p.service_description)}
          ${
            p.work_done
              ? `<div class="muted" style="margin-top: 4px; font-size: 11px;">${esc(p.work_done)}</div>`
              : ""
          }
        </td>
        <td>${esc(p.hsn_sac_code)}</td>
        <td class="num">${inr(p.taxable_value)}</td>
        ${
          interState
            ? `<td class="num">${inr(igst)}</td>`
            : `<td class="num">${inr(cgst)}</td><td class="num">${inr(sgst)}</td>`
        }
        <td class="num">${inr(p.gross_rupees)}</td>
      </tr>
    </tbody>
  </table>

  <table class="totals">
    <tbody>
      <tr><td>Taxable Value</td><td class="num">${inr(p.taxable_value)}</td></tr>
      ${
        interState
          ? `<tr><td>IGST (18%)</td><td class="num">${inr(igst)}</td></tr>`
          : `<tr><td>CGST (9%)</td><td class="num">${inr(cgst)}</td></tr>
             <tr><td>SGST (9%)</td><td class="num">${inr(sgst)}</td></tr>`
      }
      <tr class="row-total"><td>Total</td><td class="num">${inr(p.gross_rupees)}</td></tr>
    </tbody>
  </table>

  <div class="footer">
    This is a system-generated tax invoice. Subject to ${esc(s.state)} jurisdiction.
    Amounts in INR. E. &amp; O. E.
  </div>
</body>
</html>`;
}

serve(async (req) => {
  if (req.method !== "POST") return bad("bad_request", "POST only", 405);

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY");
  if (!supabaseUrl || !serviceKey || !anonKey) {
    return bad("server_error", "edge function not configured", 500);
  }

  const supplier: SupplierEnv = {
    legalName: Deno.env.get("SUPPLIER_LEGAL_NAME") ?? "",
    tradeName: Deno.env.get("SUPPLIER_TRADE_NAME") ?? "EquipSeva",
    gstin: Deno.env.get("SUPPLIER_GSTIN") ?? "",
    address: Deno.env.get("SUPPLIER_ADDRESS") ?? "",
    state: Deno.env.get("SUPPLIER_STATE") ?? "Telangana",
    stateCode: Deno.env.get("SUPPLIER_STATE_CODE") ?? "36",
    pincode: Deno.env.get("SUPPLIER_PINCODE") ?? "",
    email: Deno.env.get("SUPPLIER_EMAIL") ?? "",
    phone: Deno.env.get("SUPPLIER_PHONE") ?? "",
  };
  if (!supplier.gstin || !supplier.legalName || !supplier.address) {
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

  const html = renderHtml(payload, supplier);

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

  const { data: signed, error: signErr } = await admin.storage
    .from("invoices")
    .createSignedUrl(path, 60 * 60 * 24 * 30);
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
