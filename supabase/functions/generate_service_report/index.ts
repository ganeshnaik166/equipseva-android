// Supabase edge function: generate_service_report
//
// v2.1 PR-D3 — compliance audit-trail HTML report (T3.11). Hospitals
// need NABH / JCI accreditation, which requires a digital service log
// for every maintenance / repair touch. Off-platform = no audit trail
// = compliance risk. That's the structural moat.
//
// Caller flow (client-driven, not trigger-driven):
//   1. Hospital or engineer taps "Download service report" on a
//      completed repair_job.
//   2. Client POSTs { job_id } here with their JWT.
//   3. We auth as the caller, RLS gates the SELECT on repair_jobs.
//   4. Render an HTML report.
//   5. Upload via service-role to `service-reports/{job_id}.html`.
//   6. Update repair_jobs.service_report_url with a 30-day signed URL.
//   7. Return the signed URL.
//
// Idempotent: re-calling for the same job re-renders + re-uploads
// (upsert: true) so report content always reflects current row state.
// PDF rendering is deferred — for v1, hospitals print to PDF in the
// browser, which preserves all the audit metadata we care about.

import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.45.4";

const json = (status: number, body: unknown) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { "content-type": "application/json" },
  });

const bad = (code: string, message: string, status = 400) =>
  json(status, { ok: false, code, message });

const formatRupee = (n: unknown) =>
  new Intl.NumberFormat("en-IN", { style: "currency", currency: "INR" }).format(
    Number(n) || 0,
  );

const formatDate = (iso: string | null | undefined) => {
  if (!iso) return "—";
  try {
    return new Date(iso).toLocaleString("en-IN", {
      year: "numeric",
      month: "long",
      day: "numeric",
      hour: "2-digit",
      minute: "2-digit",
    });
  } catch {
    return iso ?? "—";
  }
};

function esc(s: unknown): string {
  return String(s ?? "")
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;");
}

interface JobRow {
  id: string;
  job_number: string | null;
  status: string;
  hospital_user_id: string;
  engineer_id: string | null;
  equipment_type: string | null;
  equipment_brand: string | null;
  equipment_model: string | null;
  equipment_serial: string | null;
  job_type: string | null;
  urgency: string | null;
  issue_description: string | null;
  diagnosis: string | null;
  work_done: string | null;
  parts_used: unknown;
  before_photos: string[] | null;
  after_photos: string[] | null;
  actual_cost_parts: number | null;
  actual_cost_labor: number | null;
  actual_cost_total: number | null;
  contracted_amount_rupees: number | null;
  platform_commission: number | null;
  engineer_payout: number | null;
  started_at: string | null;
  completed_at: string | null;
  scheduled_date: string | null;
  site_location: string | null;
  amc_contract_id: string | null;
  amc_visit_number: number | null;
}

function renderHtml(args: {
  job: JobRow;
  hospitalName: string;
  hospitalEmail: string;
  engineerName: string;
  engineerCity: string;
  engineerVerification: string;
}): string {
  const j = args.job;
  const partsBlock = (() => {
    if (!j.parts_used) return "<em style=\"color:#5f6877;\">None recorded</em>";
    if (Array.isArray(j.parts_used)) {
      return j.parts_used
        .map((p) => `<li>${esc(typeof p === "string" ? p : JSON.stringify(p))}</li>`)
        .join("");
    }
    return esc(JSON.stringify(j.parts_used));
  })();
  const beforeImgs = (j.before_photos ?? [])
    .slice(0, 4)
    .map((u) => `<img src="${esc(u)}" style="width:120px;height:90px;object-fit:cover;border-radius:6px;border:1px solid #e6e8eb;margin:4px;" />`)
    .join("");
  const afterImgs = (j.after_photos ?? [])
    .slice(0, 4)
    .map((u) => `<img src="${esc(u)}" style="width:120px;height:90px;object-fit:cover;border-radius:6px;border:1px solid #e6e8eb;margin:4px;" />`)
    .join("");
  const amcLine = j.amc_contract_id
    ? `<div style="color:#5f6877;font-size:12px;margin-top:4px;">AMC visit #${esc(j.amc_visit_number ?? "—")}</div>`
    : "";
  return `<!doctype html>
<html><head>
<meta charset="utf-8"/>
<title>EquipSeva Service Report ${esc(j.job_number ?? j.id)}</title>
<meta name="viewport" content="width=device-width,initial-scale=1"/>
</head>
<body style="margin:0;padding:0;font-family:'Helvetica Neue',Arial,sans-serif;background:#f7f8fa;color:#111418;">
  <table style="width:100%;max-width:800px;margin:24px auto;background:#fff;border:1px solid #e6e8eb;border-radius:14px;overflow:hidden;">
    <tr><td style="background:linear-gradient(135deg,#0B6E4F,#075A40);padding:24px 28px;color:#fff;">
      <div style="font-size:12px;letter-spacing:.5px;opacity:.85;">EQUIPSEVA · SERVICE REPORT</div>
      <div style="font-size:22px;font-weight:700;margin-top:4px;">Job ${esc(j.job_number ?? j.id)}</div>
      <div style="font-size:13px;opacity:.85;margin-top:4px;">${esc(j.job_type ?? "Repair")} · ${esc(j.urgency ?? "")}</div>
      ${amcLine}
    </td></tr>

    <tr><td style="padding:20px 28px;">
      <table style="width:100%;font-size:13px;">
        <tr>
          <td style="vertical-align:top;width:50%;">
            <div style="font-weight:600;color:#5f6877;">Hospital</div>
            <div style="font-weight:600;font-size:14px;margin-top:2px;">${esc(args.hospitalName)}</div>
            <div style="color:#5f6877;">${esc(args.hospitalEmail)}</div>
            ${j.site_location ? `<div style="color:#5f6877;margin-top:6px;">${esc(j.site_location)}</div>` : ""}
          </td>
          <td style="vertical-align:top;width:50%;">
            <div style="font-weight:600;color:#5f6877;">Engineer</div>
            <div style="font-weight:600;font-size:14px;margin-top:2px;">${esc(args.engineerName)}</div>
            <div style="color:#5f6877;">${esc(args.engineerCity)}</div>
            <div style="color:#5f6877;margin-top:4px;">KYC: <span style="font-weight:600;color:#0B6E4F;">${esc(args.engineerVerification)}</span></div>
          </td>
        </tr>
      </table>

      <h3 style="font-size:14px;color:#075A40;border-bottom:1px solid #E6F2ED;padding-bottom:6px;margin-top:24px;">Equipment</h3>
      <table style="width:100%;font-size:13px;">
        <tr><td style="color:#5f6877;width:140px;padding:4px 0;">Type</td><td>${esc(j.equipment_type ?? "—")}</td></tr>
        <tr><td style="color:#5f6877;padding:4px 0;">Brand / Model</td><td>${esc(j.equipment_brand ?? "—")} ${esc(j.equipment_model ?? "")}</td></tr>
        <tr><td style="color:#5f6877;padding:4px 0;">Serial</td><td>${esc(j.equipment_serial ?? "—")}</td></tr>
      </table>

      <h3 style="font-size:14px;color:#075A40;border-bottom:1px solid #E6F2ED;padding-bottom:6px;margin-top:20px;">Issue reported</h3>
      <div style="font-size:13px;color:#222;white-space:pre-wrap;">${esc(j.issue_description ?? "—")}</div>

      ${j.diagnosis ? `<h3 style="font-size:14px;color:#075A40;border-bottom:1px solid #E6F2ED;padding-bottom:6px;margin-top:20px;">Diagnosis</h3><div style="font-size:13px;color:#222;white-space:pre-wrap;">${esc(j.diagnosis)}</div>` : ""}

      ${j.work_done ? `<h3 style="font-size:14px;color:#075A40;border-bottom:1px solid #E6F2ED;padding-bottom:6px;margin-top:20px;">Work performed</h3><div style="font-size:13px;color:#222;white-space:pre-wrap;">${esc(j.work_done)}</div>` : ""}

      <h3 style="font-size:14px;color:#075A40;border-bottom:1px solid #E6F2ED;padding-bottom:6px;margin-top:20px;">Parts replaced</h3>
      <ul style="font-size:13px;color:#222;margin:6px 0 0 18px;padding:0;">${partsBlock}</ul>

      ${beforeImgs ? `<h3 style="font-size:14px;color:#075A40;border-bottom:1px solid #E6F2ED;padding-bottom:6px;margin-top:20px;">Before</h3><div>${beforeImgs}</div>` : ""}
      ${afterImgs ? `<h3 style="font-size:14px;color:#075A40;border-bottom:1px solid #E6F2ED;padding-bottom:6px;margin-top:20px;">After</h3><div>${afterImgs}</div>` : ""}

      <h3 style="font-size:14px;color:#075A40;border-bottom:1px solid #E6F2ED;padding-bottom:6px;margin-top:20px;">Cost breakdown</h3>
      <table style="width:100%;font-size:13px;">
        <tr><td style="color:#5f6877;padding:4px 0;width:200px;">Parts</td><td style="text-align:right;">${formatRupee(j.actual_cost_parts ?? 0)}</td></tr>
        <tr><td style="color:#5f6877;padding:4px 0;">Labor</td><td style="text-align:right;">${formatRupee(j.actual_cost_labor ?? 0)}</td></tr>
        <tr><td style="color:#5f6877;padding:4px 0;">Total contracted</td><td style="text-align:right;font-weight:600;">${formatRupee(j.contracted_amount_rupees ?? j.actual_cost_total ?? 0)}</td></tr>
        ${j.platform_commission != null ? `<tr><td style="color:#5f6877;padding:4px 0;">Platform fee</td><td style="text-align:right;">${formatRupee(j.platform_commission)}</td></tr>` : ""}
      </table>

      <h3 style="font-size:14px;color:#075A40;border-bottom:1px solid #E6F2ED;padding-bottom:6px;margin-top:20px;">Timeline</h3>
      <table style="width:100%;font-size:13px;">
        <tr><td style="color:#5f6877;padding:4px 0;width:200px;">Scheduled</td><td>${esc(j.scheduled_date ?? "—")}</td></tr>
        <tr><td style="color:#5f6877;padding:4px 0;">Started</td><td>${esc(formatDate(j.started_at))}</td></tr>
        <tr><td style="color:#5f6877;padding:4px 0;">Completed</td><td>${esc(formatDate(j.completed_at))}</td></tr>
      </table>

      <div style="margin-top:32px;padding:14px 16px;background:#F5FAF7;border-left:3px solid #0B6E4F;border-radius:6px;font-size:12px;color:#3a4250;line-height:1.5;">
        Generated by <strong>EquipSeva</strong> as a digital service record for hospital compliance archives (NABH / JCI accreditation). Contains a complete audit trail of equipment work performed by a verified biomedical engineer. This document is generated electronically and does not require a wet signature.
      </div>
    </td></tr>
  </table>
</body></html>`;
}

serve(async (req) => {
  if (req.method !== "POST") return bad("bad_request", "POST only", 405);

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!supabaseUrl || !serviceKey) {
    return bad("server_error", "edge function not configured", 500);
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

  // Caller-scoped client — uses the user JWT, so RLS on repair_jobs
  // is what gates the SELECT. If the caller isn't the hospital or an
  // engineer participating in the job, the row simply won't be
  // returned and we 404 below.
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY");
  if (!anonKey) return bad("server_error", "anon key missing", 500);
  const callerClient = createClient(supabaseUrl, anonKey, {
    global: { headers: { Authorization: authHeader } },
  });

  const { data: job, error: jobErr } = await callerClient
    .from("repair_jobs")
    .select(
      "id, job_number, status, hospital_user_id, engineer_id, equipment_type, equipment_brand, equipment_model, equipment_serial, job_type, urgency, issue_description, diagnosis, work_done, parts_used, before_photos, after_photos, actual_cost_parts, actual_cost_labor, actual_cost_total, contracted_amount_rupees, platform_commission, engineer_payout, started_at, completed_at, scheduled_date, site_location, amc_contract_id, amc_visit_number",
    )
    .eq("id", jobId)
    .maybeSingle();

  if (jobErr || !job) {
    if (jobErr) console.error("generate_service_report: job fetch failed", jobErr.message);
    return bad("job_not_found", "missing or no access", 404);
  }
  if (job.status !== "completed") {
    return bad("not_completed", "report only available for completed jobs");
  }

  // Service-role client for follow-up reads (engineer KYC, profiles
  // outside the caller's RLS scope) and for the storage upload +
  // service_report_url update.
  const admin = createClient(supabaseUrl, serviceKey);

  const [{ data: hospital }, engineerLookup] = await Promise.all([
    admin
      .from("profiles")
      .select("full_name, email")
      .eq("id", job.hospital_user_id)
      .maybeSingle(),
    job.engineer_id
      ? admin
          .from("engineers")
          .select("city, verification_status, user_id")
          .eq("id", job.engineer_id)
          .maybeSingle()
      : Promise.resolve({ data: null }),
  ]);

  let engineerName = "Engineer";
  const engineerCity = (engineerLookup?.data as { city?: string } | null)?.city ?? "";
  const engineerVerification =
    (engineerLookup?.data as { verification_status?: string } | null)?.verification_status ?? "—";
  const engineerUserId =
    (engineerLookup?.data as { user_id?: string } | null)?.user_id ?? null;
  if (engineerUserId) {
    const { data: engProfile } = await admin
      .from("profiles")
      .select("full_name")
      .eq("id", engineerUserId)
      .maybeSingle();
    engineerName = engProfile?.full_name ?? engineerName;
  }

  const html = renderHtml({
    job: job as JobRow,
    hospitalName: hospital?.full_name ?? "Hospital",
    hospitalEmail: hospital?.email ?? "",
    engineerName,
    engineerCity,
    engineerVerification,
  });

  const path = `${jobId}.html`;
  const upload = await admin.storage
    .from("service-reports")
    .upload(path, new Blob([html], { type: "text/html" }), {
      upsert: true,
      contentType: "text/html",
    });
  if (upload.error) {
    console.error("generate_service_report: upload failed", upload.error);
    return bad("server_error", "report upload failed", 500);
  }

  const { data: signed, error: signErr } = await admin.storage
    .from("service-reports")
    .createSignedUrl(path, 60 * 60 * 24 * 30);

  if (signErr || !signed?.signedUrl) {
    console.error("generate_service_report: sign failed", signErr);
    return bad("server_error", "report sign failed", 500);
  }

  await admin
    .from("repair_jobs")
    .update({ service_report_url: signed.signedUrl })
    .eq("id", jobId);

  return json(200, {
    ok: true,
    service_report_url: signed.signedUrl,
  });
});
