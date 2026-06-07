// Supabase edge function: founder_invoice_digest
//
// Round 463 — daily email summary of every GST invoice emailed in the
// past 24 hours. Pulls rows from repair_invoice_emails (logged by
// dispatch_repair_invoice) and sends one summary to the founder.
//
// Caller: pg_cron at 02:30 UTC = 08:00 IST daily. The cron job calls
// this URL with x-webhook-secret = CRON_TICK_SECRET (existing).
//
// Required env:
//   SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY
//   CRON_TICK_SECRET            (matches cron caller's secret)
//   FOUNDER_DIGEST_EMAIL        (recipient — typically founder ops email)
//   RESEND_API_KEY, RESEND_FROM (email transport)
//
// Manual invocation (admin re-run) — same headers, POST body unused:
//   curl -X POST https://<ref>.functions.supabase.co/founder_invoice_digest \
//     -H "x-webhook-secret: $CRON_TICK_SECRET"

import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.45.4";

const json = (status: number, body: unknown) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { "content-type": "application/json" },
  });

const bad = (code: string, message: string, status = 400) =>
  json(status, { ok: false, code, message });

function timingSafeEqual(a: string, b: string): boolean {
  if (a.length !== b.length) return false;
  let diff = 0;
  for (let i = 0; i < a.length; i++) diff |= a.charCodeAt(i) ^ b.charCodeAt(i);
  return diff === 0;
}

function esc(x: unknown): string {
  return String(x ?? "")
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;");
}

const inr = (n: unknown) =>
  new Intl.NumberFormat("en-IN", {
    style: "currency",
    currency: "INR",
    minimumFractionDigits: 2,
  }).format(Number(n) || 0);

interface DigestRow {
  invoice_number: string;
  invoice_date: string;
  hospital_name: string | null;
  hospital_email: string | null;
  gross_rupees: number;
  gst_total: number;
  email_status: string;
  sent_at: string;
}

serve(async (req) => {
  if (req.method !== "POST" && req.method !== "GET") {
    return bad("bad_request", "POST or GET only", 405);
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!supabaseUrl || !serviceKey) {
    return bad("server_error", "edge function not configured", 500);
  }

  const expectedSecret = Deno.env.get("CRON_TICK_SECRET");
  const incomingSecret = req.headers.get("x-webhook-secret") ?? "";
  if (!expectedSecret || !timingSafeEqual(incomingSecret, expectedSecret)) {
    return bad("unauthenticated", "bad webhook secret", 401);
  }

  const founderEmail = Deno.env.get("FOUNDER_DIGEST_EMAIL");
  if (!founderEmail) {
    console.error("founder_invoice_digest: FOUNDER_DIGEST_EMAIL unset");
    return bad("server_error", "founder_email_unset", 500);
  }

  const resendApiKey = Deno.env.get("RESEND_API_KEY");
  const resendFrom = Deno.env.get("RESEND_FROM") ?? "onboarding@resend.dev";
  if (!resendApiKey) {
    return bad("server_error", "resend_unconfigured", 500);
  }

  const admin = createClient(supabaseUrl, serviceKey);
  const since = new Date(Date.now() - 24 * 60 * 60 * 1000).toISOString();

  const { data, error } = await admin.rpc("get_invoice_digest_payload", {
    p_since: since,
  });
  if (error) {
    console.error("founder_invoice_digest rpc error", error);
    return bad("server_error", "digest fetch failed", 500);
  }

  const rows = (data as DigestRow[] | null) ?? [];
  if (rows.length === 0) {
    // No invoices in the window — skip the email. Daily noise from
    // empty digests trains the founder to ignore the channel; only
    // send when there's something to report.
    return json(200, { ok: true, status: "no_invoices_in_window", count: 0 });
  }

  let totalGross = 0;
  let totalGst = 0;
  let sentCount = 0;
  let skippedCount = 0;
  let failedCount = 0;
  for (const r of rows) {
    totalGross += Number(r.gross_rupees) || 0;
    totalGst += Number(r.gst_total) || 0;
    if (r.email_status === "sent") sentCount++;
    else if (r.email_status === "skipped_no_email" || r.email_status === "disabled") skippedCount++;
    else failedCount++;
  }

  const todayIst = new Date().toLocaleDateString("en-IN", {
    timeZone: "Asia/Kolkata",
    year: "numeric",
    month: "short",
    day: "numeric",
  });

  const html = `<!doctype html>
<html><body style="font-family: -apple-system, Helvetica, Arial, sans-serif; color: #111; padding: 20px; max-width: 720px;">
  <h2 style="margin-bottom: 4px;">GST Invoices — ${esc(todayIst)}</h2>
  <p style="color: #666; margin-top: 0;">Repair jobs completed in the last 24 hours.</p>

  <table style="border-collapse: collapse; margin: 16px 0; font-size: 14px;">
    <tr><td style="padding: 4px 16px 4px 0; color: #666;">Total invoices</td><td><strong>${rows.length}</strong></td></tr>
    <tr><td style="padding: 4px 16px 4px 0; color: #666;">Emailed</td><td>${sentCount}</td></tr>
    <tr><td style="padding: 4px 16px 4px 0; color: #666;">No-email hospitals</td><td>${skippedCount}</td></tr>
    ${failedCount > 0 ? `<tr><td style="padding: 4px 16px 4px 0; color: #c00;">Delivery failures</td><td style="color: #c00;">${failedCount}</td></tr>` : ""}
    <tr><td style="padding: 8px 16px 4px 0; color: #666; border-top: 1px solid #ddd;">Gross revenue</td><td style="padding-top: 8px; border-top: 1px solid #ddd;"><strong>${esc(inr(totalGross))}</strong></td></tr>
    <tr><td style="padding: 4px 16px 4px 0; color: #666;">GST collected (output liability)</td><td>${esc(inr(totalGst))}</td></tr>
  </table>

  <h3 style="margin-top: 28px; font-size: 14px; text-transform: uppercase; letter-spacing: 0.4px; color: #666;">Line items</h3>
  <table style="border-collapse: collapse; width: 100%; font-size: 13px;">
    <thead>
      <tr style="background: #f5f5f5;">
        <th style="text-align: left; padding: 8px;">Invoice</th>
        <th style="text-align: left; padding: 8px;">Hospital</th>
        <th style="text-align: right; padding: 8px;">Gross</th>
        <th style="text-align: right; padding: 8px;">GST</th>
        <th style="text-align: left; padding: 8px;">Status</th>
      </tr>
    </thead>
    <tbody>
      ${rows.map((r) => `
        <tr style="border-bottom: 1px solid #eee;">
          <td style="padding: 8px;"><strong>${esc(r.invoice_number)}</strong><div style="color: #888; font-size: 11px;">${esc(r.invoice_date)}</div></td>
          <td style="padding: 8px;">${esc(r.hospital_name ?? "—")}<div style="color: #888; font-size: 11px;">${esc(r.hospital_email ?? "")}</div></td>
          <td style="padding: 8px; text-align: right; font-variant-numeric: tabular-nums;">${esc(inr(r.gross_rupees))}</td>
          <td style="padding: 8px; text-align: right; font-variant-numeric: tabular-nums;">${esc(inr(r.gst_total))}</td>
          <td style="padding: 8px;">
            <span style="display: inline-block; padding: 2px 8px; border-radius: 8px; font-size: 11px; ${statusBadgeStyle(r.email_status)}">${esc(r.email_status)}</span>
          </td>
        </tr>
      `).join("")}
    </tbody>
  </table>

  <p style="margin-top: 32px; font-size: 11px; color: #666;">Filed automatically by EquipSeva backend. Use this as the daily revenue + GST-output checkpoint before GSTR-3B filing on the 20th.</p>
</body></html>`;

  try {
    const r = await fetch("https://api.resend.com/emails", {
      method: "POST",
      headers: {
        "content-type": "application/json",
        authorization: `Bearer ${resendApiKey}`,
      },
      body: JSON.stringify({
        from: resendFrom,
        to: [founderEmail],
        subject: `EquipSeva — ${rows.length} invoice${rows.length === 1 ? "" : "s"} • ${inr(totalGross)} • ${todayIst}`,
        html,
      }),
      signal: AbortSignal.timeout(12_000),
    });
    if (!r.ok) {
      const t = await r.text();
      console.error("founder_invoice_digest resend non-2xx", r.status, t.slice(0, 400));
      return bad("server_error", "digest_email_failed", 500);
    }
  } catch (e) {
    const msg = e instanceof Error ? e.message : String(e);
    console.error("founder_invoice_digest resend threw", msg);
    return bad("server_error", "digest_email_threw", 500);
  }

  return json(200, {
    ok: true,
    status: "sent",
    count: rows.length,
    total_gross: totalGross,
    total_gst: totalGst,
  });
});

function statusBadgeStyle(s: string): string {
  switch (s) {
    case "sent":
      return "background: #e6f4ea; color: #1f7038;";
    case "skipped_no_email":
    case "disabled":
      return "background: #fef3c7; color: #92400e;";
    default:
      return "background: #fee2e2; color: #991b1b;";
  }
}
