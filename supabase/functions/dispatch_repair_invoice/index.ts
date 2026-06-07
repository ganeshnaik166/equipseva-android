// Supabase edge function: dispatch_repair_invoice
//
// Round 463 — webhook-authed auto-fire path for the GST invoice flow.
//
// Caller: repair_jobs_dispatch_invoice() trigger (defined in migration
// 20260720000000_round463_invoice_auto_dispatch.sql). Fires when
// repair_jobs.status transitions OLD != 'completed' AND NEW = 'completed'.
//
// Differences vs generate_repair_invoice (manual, caller-scoped):
//   • Auth: shared secret in x-webhook-secret (= INVOICE_DISPATCH_SECRET),
//     NOT a user JWT. Service-role inside the fn.
//   • Calls get_repair_invoice_payload_unchecked (no auth.uid() gate) —
//     the webhook secret IS the gate.
//   • Sends the invoice via Resend to the hospital's profile email.
//   • Records dispatch to repair_invoice_emails (idempotent: a row for
//     today already-> 'already_sent').
//   • Signed URL TTL = 7 days (link rides in an email, must outlive
//     "I'll check my inbox tonight").
//
// Required env:
//   SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY
//   INVOICE_DISPATCH_SECRET      (matches webhook_secret in
//                                  _app_repair_invoice_config table)
//   SUPPLIER_*                   (same as generate_repair_invoice)
//   RESEND_API_KEY, RESEND_FROM  (email transport)

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

// Constant-time string compare so a timing oracle can't recover the
// shared secret one byte at a time.
function timingSafeEqual(a: string, b: string): boolean {
  if (a.length !== b.length) return false;
  let diff = 0;
  for (let i = 0; i < a.length; i++) diff |= a.charCodeAt(i) ^ b.charCodeAt(i);
  return diff === 0;
}

const SIGNED_URL_TTL_SECONDS = 60 * 60 * 24 * 7; // 7 days

serve(async (req) => {
  if (req.method !== "POST") return bad("bad_request", "POST only", 405);

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!supabaseUrl || !serviceKey) {
    return bad("server_error", "edge function not configured", 500);
  }

  const expectedSecret = Deno.env.get("INVOICE_DISPATCH_SECRET");
  const incomingSecret = req.headers.get("x-webhook-secret") ?? "";
  if (!expectedSecret || !timingSafeEqual(incomingSecret, expectedSecret)) {
    return bad("unauthenticated", "bad webhook secret", 401);
  }

  const supplier = readSupplierEnv();
  if (!supplierIsConfigured(supplier)) {
    // Don't loud-fail: the manual button surfaces the same error to
    // the hospital. Record a row so the founder digest reflects that
    // a completion happened but no invoice went out.
    console.error("dispatch_repair_invoice: supplier env incomplete");
    return bad("server_error", "supplier identity unset", 500);
  }

  let body: { job_id?: string };
  try {
    body = await req.json();
  } catch {
    return bad("bad_request", "invalid json");
  }
  const jobId = body?.job_id;
  if (!jobId) return bad("bad_request", "missing job_id");

  const admin = createClient(supabaseUrl, serviceKey);

  // Idempotency check — if we already sent within the last 24h,
  // short-circuit before rendering + uploading + emailing. The
  // (job_id, sent_at) index makes this a single index scan.
  const { data: existing } = await admin
    .from("repair_invoice_emails")
    .select("id, sent_at, email_status")
    .eq("job_id", jobId)
    .gte("sent_at", new Date(Date.now() - 24 * 60 * 60 * 1000).toISOString())
    .limit(1)
    .maybeSingle();
  if (existing) {
    return json(200, { ok: true, status: "already_sent_today", id: existing.id });
  }

  const { data, error } = await admin.rpc("get_repair_invoice_payload_unchecked", {
    p_job_id: jobId,
  });
  if (error) {
    console.error("dispatch_repair_invoice rpc error", error);
    return bad("server_error", "invoice fetch failed", 500);
  }
  const rows = (data as InvoicePayload[] | null) ?? [];
  if (rows.length === 0) {
    // Job not completed or not found — trigger should never let this
    // through, but be defensive (no row, no log).
    return bad("not_found", "job not in invoiceable state", 404);
  }
  const payload = rows[0];

  const html = renderInvoiceHtml(payload, supplier);
  const path = `repair_${jobId}.html`;

  const upload = await admin.storage
    .from("invoices")
    .upload(path, new Blob([html], { type: "text/html" }), {
      upsert: true,
      contentType: "text/html",
    });
  if (upload.error) {
    console.error("dispatch_repair_invoice upload failed", upload.error?.message ?? "");
    return bad("server_error", "invoice upload failed", 500);
  }

  const { data: signed, error: signErr } = await admin.storage
    .from("invoices")
    .createSignedUrl(path, SIGNED_URL_TTL_SECONDS);
  if (signErr || !signed?.signedUrl) {
    console.error("dispatch_repair_invoice sign failed", signErr?.message ?? "");
    return bad("server_error", "invoice sign failed", 500);
  }
  const signedUrl = signed.signedUrl;
  const urlExpiresAt = new Date(Date.now() + SIGNED_URL_TTL_SECONDS * 1000).toISOString();

  let emailStatus: "sent" | "skipped_no_email" | "resend_failed" | "disabled" = "sent";
  let emailError: string | null = null;

  const resendApiKey = Deno.env.get("RESEND_API_KEY");
  const resendFrom = Deno.env.get("RESEND_FROM") ?? "onboarding@resend.dev";

  if (!resendApiKey) {
    emailStatus = "disabled";
    emailError = "resend_unconfigured";
    console.warn("dispatch_repair_invoice: RESEND_API_KEY unset; skipping email");
  } else if (!payload.hospital_email || !payload.hospital_email.trim()) {
    emailStatus = "skipped_no_email";
    emailError = "hospital_has_no_email";
  } else {
    try {
      const r = await fetch("https://api.resend.com/emails", {
        method: "POST",
        headers: {
          "content-type": "application/json",
          authorization: `Bearer ${resendApiKey}`,
        },
        body: JSON.stringify({
          from: resendFrom,
          to: [payload.hospital_email],
          subject: `EquipSeva GST Invoice — ${payload.invoice_number}`,
          html: emailBodyHtml(payload, supplier, signedUrl),
        }),
        signal: AbortSignal.timeout(12_000),
      });
      if (!r.ok) {
        const t = await r.text();
        console.error("dispatch_repair_invoice resend non-2xx", r.status, t.slice(0, 400));
        emailStatus = "resend_failed";
        emailError = `resend_status_${r.status}`;
      }
    } catch (e) {
      const msg = e instanceof Error ? e.message : String(e);
      console.error("dispatch_repair_invoice resend threw", msg);
      emailStatus = "resend_failed";
      emailError = "resend_exception";
    }
  }

  const { error: insErr } = await admin
    .from("repair_invoice_emails")
    .insert({
      job_id: jobId,
      invoice_number: payload.invoice_number,
      invoice_date: payload.invoice_date,
      hospital_email: payload.hospital_email,
      hospital_name: payload.hospital_name,
      gross_rupees: payload.gross_rupees,
      gst_total: payload.gst_total,
      signed_url: signedUrl,
      url_expires_at: urlExpiresAt,
      email_status: emailStatus,
      email_error: emailError,
    });
  if (insErr) {
    // Log row write failed (e.g. RLS bug, table missing, FK
    // violation). Email already went out, so return 200 with a
    // diagnostic status — bouncing the webhook would cause the
    // trigger to retry and double-send.
    console.error("dispatch_repair_invoice insert log row failed", insErr);
    return json(200, {
      ok: true,
      status: "log_failed",
      invoice_number: payload.invoice_number,
    });
  }

  return json(200, {
    ok: true,
    status: emailStatus,
    invoice_number: payload.invoice_number,
    invoice_url: signedUrl,
  });
});

// Short cover email that wraps the signed-URL link. Keeping this
// separate from the invoice HTML itself — the recipient sees a clean
// "here's your invoice" mail, not a full tax document inlined.
function emailBodyHtml(
  p: InvoicePayload,
  s: { tradeName: string; gstin: string },
  url: string,
): string {
  const esc = (x: unknown) =>
    String(x ?? "")
      .replace(/&/g, "&amp;")
      .replace(/</g, "&lt;")
      .replace(/>/g, "&gt;")
      .replace(/"/g, "&quot;");
  const inr = new Intl.NumberFormat("en-IN", {
    style: "currency",
    currency: "INR",
    minimumFractionDigits: 2,
  });
  return `<!doctype html>
<html><body style="font-family: -apple-system, Helvetica, Arial, sans-serif; color: #111; padding: 20px;">
  <p>Hi ${esc(p.hospital_name)},</p>
  <p>Your repair job <strong>${esc(p.job_number ?? "")}</strong> is complete. The GST tax invoice from <strong>${esc(s.tradeName)}</strong> is attached below.</p>
  <table style="border-collapse: collapse; margin: 16px 0; font-size: 14px;">
    <tr><td style="padding: 4px 12px 4px 0; color: #666;">Invoice No.</td><td style="font-weight: 600;">${esc(p.invoice_number)}</td></tr>
    <tr><td style="padding: 4px 12px 4px 0; color: #666;">Invoice Date</td><td>${esc(p.invoice_date)}</td></tr>
    <tr><td style="padding: 4px 12px 4px 0; color: #666;">Amount (incl. GST)</td><td style="font-weight: 600;">${esc(inr.format(Number(p.gross_rupees) || 0))}</td></tr>
    <tr><td style="padding: 4px 12px 4px 0; color: #666;">GST</td><td>${esc(inr.format(Number(p.gst_total) || 0))}</td></tr>
  </table>
  <p>
    <a href="${esc(url)}" style="display: inline-block; background: #111; color: #fff; padding: 10px 18px; border-radius: 6px; text-decoration: none; font-weight: 600;">View / Download Invoice</a>
  </p>
  <p style="font-size: 12px; color: #666;">This link is valid for 7 days. After that, sign in to the EquipSeva app and tap "Download GST invoice" on the job to mint a fresh link.</p>
  <p style="font-size: 12px; color: #666; margin-top: 24px;">Supplier GSTIN: ${esc(s.gstin)}</p>
</body></html>`;
}
