// Supabase edge function: export_nabh_bundle
//
// Round 511 — v0.4 Phase 4 #5 backbone.
//
// Renders a NABH 5th-edition COP-6 audit bundle for a single piece of
// equipment as a downloadable ZIP. The ZIP contains:
//   - index.html       cover sheet (equipment ID + summary table)
//   - dsr_<n>.html     one page per DSR row returned by the RPC
//   - summary.json     machine-readable bundle metadata
//
// Caller flow:
//   1. Hospital (or founder) POSTs { hospital_user_id, equipment_serial, months }
//      with their JWT
//   2. We auth as the caller; nabh_bundle_for_equipment RPC gates access
//      (hospital can only pull their own equipment; founder any)
//   3. We render the ZIP server-side and upload to nabh-bundles bucket
//   4. Return a 60-min signed URL the client can fetch directly
//
// Required env: SUPABASE_URL, SUPABASE_ANON_KEY, SUPABASE_SERVICE_ROLE_KEY

import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.45.4";
import JSZip from "https://esm.sh/jszip@3.10.1";

const json = (status: number, body: unknown) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { "content-type": "application/json" },
  });

const bad = (code: string, message: string, status = 400) =>
  json(status, { ok: false, code, message });

interface NabhRow {
  dsr_id: string;
  repair_job_id: string;
  equipment_brand: string | null;
  equipment_model: string | null;
  equipment_type: string | null;
  engineer_signature_at: string | null;
  hospital_signature_at: string | null;
  hospital_signer_name: string | null;
  hospital_signer_role: string | null;
  iec_62353_passed: boolean | null;
  calibration_within_oem: boolean | null;
  pre_post_readings: unknown;
  parts_replaced: unknown;
  status: string;
}

const escapeHtml = (s: string | null | undefined): string =>
  String(s ?? "")
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;");

const fmtDate = (iso: string | null): string =>
  iso ? new Date(iso).toISOString().replace("T", " ").slice(0, 16) + " UTC" : "—";

const passBadge = (b: boolean | null): string =>
  b === true ? "PASS" : b === false ? "FAIL" : "—";

// round3786 — the footer below used to assert "Each DSR is countersigned
// per §65B Indian Evidence Act. Tampering detection via SHA-256 chain in
// evidence_ledger." Both halves were untrue, and this document is handed
// to hospital NABH auditors, so the claim was actively misleading.
//
// Verified against production: public.evidence_ledger has 0 rows, and the
// ONLY statement anywhere that inserts into it is register_evidence(),
// which has zero callers in app/, web/, supabase/functions/ or any other
// migration — so no SHA-256 chain has ever been maintained. There is also
// no signature-capture UI in the app at all. generate_65b_certificate()
// exists but unconditionally raises 'evidence_not_found' for the same
// reason, so no §65B certificate can currently be produced for anything.
//
// The footer now states only what the bundle actually substantiates. If
// a real chain of custody is ever wired up (see the evidence_ledger note
// in memory), this is the place to strengthen the wording again — but it
// must follow the capability, not precede it.
//
// RELATED, NOT CHANGED HERE (deliberately — it is a legal document and
// the founder's call, not mine): docs/CDSCO_REPRESENTATION_LETTER_DRAFT.md
// promises a regulator "Tamper-evident digital service logs for every
// visit ... retained for a minimum of five years". That is equally
// unbacked today and must not be sent as-is.
function renderIndex(
  serial: string,
  hospitalEmail: string,
  rows: NabhRow[],
  months: number,
): string {
  const tableRows = rows
    .map((r, i) => {
      const idx = i + 1;
      return `
        <tr>
          <td>${idx}</td>
          <td><a href="dsr_${idx}.html">${escapeHtml(r.dsr_id.slice(0, 8))}</a></td>
          <td>${escapeHtml(r.equipment_brand)} ${escapeHtml(r.equipment_model)}</td>
          <td>${fmtDate(r.engineer_signature_at)}</td>
          <td>${fmtDate(r.hospital_signature_at)}</td>
          <td>${passBadge(r.iec_62353_passed)}</td>
          <td>${passBadge(r.calibration_within_oem)}</td>
          <td>${escapeHtml(r.status)}</td>
        </tr>`;
    })
    .join("");

  return `<!doctype html>
<html><head><meta charset="utf-8"><title>NABH bundle — ${escapeHtml(serial)}</title>
<style>
  body { font: 14px/1.5 -apple-system, sans-serif; padding: 24px; color: #111; max-width: 1000px; margin: 0 auto; }
  h1 { font-size: 20px; margin: 0 0 4px; }
  h2 { font-size: 15px; color: #444; font-weight: normal; margin: 0 0 24px; }
  table { border-collapse: collapse; width: 100%; font-size: 13px; }
  th, td { border: 1px solid #ddd; padding: 6px 8px; text-align: left; }
  th { background: #f5f5f7; font-weight: 600; }
  tr:nth-child(even) { background: #fafafa; }
  .footer { margin-top: 32px; font-size: 11px; color: #777; }
</style></head><body>
<h1>NABH COP-6 service evidence bundle</h1>
<h2>Equipment serial: <code>${escapeHtml(serial)}</code> · Hospital: ${escapeHtml(hospitalEmail)} · Window: trailing ${months} months · Generated: ${fmtDate(new Date().toISOString())}</h2>

<table>
  <thead><tr>
    <th>#</th><th>DSR id</th><th>Equipment</th>
    <th>Engineer signed</th><th>Hospital signed</th>
    <th>IEC 62353</th><th>Calibration ≤ OEM</th><th>Status</th>
  </tr></thead>
  <tbody>${tableRows || '<tr><td colspan="8">No service reports in window.</td></tr>'}</tbody>
</table>

<div class="footer">
  Bundle generated by EquipSeva NABH Vault · Self-certified by hospital + assigned engineer ·
  Each service report records the submitting engineer and the hospital signatory, with
  timestamps. This is a self-certified export and carries no independent tamper-evidence
  attestation.
</div>
</body></html>`;
}

function renderDsrPage(idx: number, r: NabhRow, serial: string): string {
  const safe = (v: unknown) => escapeHtml(JSON.stringify(v ?? {}, null, 2));
  return `<!doctype html>
<html><head><meta charset="utf-8"><title>DSR ${idx} — ${escapeHtml(serial)}</title>
<style>
  body { font: 14px/1.5 -apple-system, sans-serif; padding: 24px; max-width: 900px; margin: 0 auto; color: #111; }
  h1 { font-size: 18px; } h2 { font-size: 14px; color: #555; font-weight: normal; margin-top: 0; }
  dl { display: grid; grid-template-columns: 200px 1fr; gap: 6px 12px; font-size: 13px; }
  dt { color: #555; } dd { margin: 0; }
  pre { background: #fafafa; border: 1px solid #ddd; padding: 12px; font-size: 12px; overflow: auto; }
</style></head><body>
<p><a href="index.html">&larr; back to index</a></p>
<h1>Digital Service Report #${idx}</h1>
<h2>DSR id <code>${escapeHtml(r.dsr_id)}</code> · Repair job <code>${escapeHtml(r.repair_job_id)}</code></h2>

<dl>
  <dt>Equipment</dt><dd>${escapeHtml(r.equipment_brand)} ${escapeHtml(r.equipment_model)} (${escapeHtml(r.equipment_type)})</dd>
  <dt>Engineer signed at</dt><dd>${fmtDate(r.engineer_signature_at)}</dd>
  <dt>Hospital signed at</dt><dd>${fmtDate(r.hospital_signature_at)}</dd>
  <dt>Hospital signer</dt><dd>${escapeHtml(r.hospital_signer_name)} (${escapeHtml(r.hospital_signer_role)})</dd>
  <dt>IEC 62353 electrical safety</dt><dd>${passBadge(r.iec_62353_passed)}</dd>
  <dt>Calibration within OEM spec</dt><dd>${passBadge(r.calibration_within_oem)}</dd>
  <dt>Status</dt><dd>${escapeHtml(r.status)}</dd>
</dl>

<h3>Pre/post readings</h3>
<pre>${safe(r.pre_post_readings)}</pre>

<h3>Parts replaced</h3>
<pre>${safe(r.parts_replaced)}</pre>
</body></html>`;
}

serve(async (req) => {
  if (req.method !== "POST") {
    return bad("method_not_allowed", "POST only", 405);
  }

  const url = Deno.env.get("SUPABASE_URL");
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY");
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!url || !anonKey || !serviceKey) {
    return bad("misconfigured", "Supabase env missing", 500);
  }

  const authHeader = req.headers.get("authorization") ?? "";
  if (!authHeader.toLowerCase().startsWith("bearer ")) {
    return bad("unauthorized", "bearer token required", 401);
  }

  let payload: {
    hospital_user_id?: string;
    equipment_serial?: string;
    months?: number;
  };
  try {
    payload = await req.json();
  } catch {
    return bad("invalid_body", "JSON body required");
  }

  const { hospital_user_id, equipment_serial, months = 24 } = payload;
  if (!hospital_user_id || !equipment_serial) {
    return bad("missing_params", "hospital_user_id and equipment_serial required");
  }

  // Caller-scoped client — relies on nabh_bundle_for_equipment SECDEF + auth.uid()
  const caller = createClient(url, anonKey, {
    global: { headers: { Authorization: authHeader } },
  });

  // r522 (audit-11 fix) — rate limit (5/min, 50/day per user; founder bypass).
  // Reserve a slot BEFORE doing any work so a 429 caller can't spam render.
  const { error: rateErr } = await caller.rpc("check_and_reserve_nabh_export");
  if (rateErr) {
    if (rateErr.code === "53400") {
      return bad("rate_limited", rateErr.message, 429);
    }
    if (rateErr.code === "42501") {
      return bad("unauthorized", rateErr.message, 401);
    }
    return bad("rate_check_failed", rateErr.message, 500);
  }

  const { data: rows, error: rpcErr } = await caller.rpc(
    "nabh_bundle_for_equipment",
    {
      p_hospital_user_id: hospital_user_id,
      p_equipment_serial: equipment_serial,
      p_months: months,
    },
  );

  if (rpcErr) {
    if (rpcErr.code === "42501") return bad("forbidden", rpcErr.message, 403);
    return bad("rpc_failed", rpcErr.message, 500);
  }

  const dsrRows = (rows ?? []) as NabhRow[];

  // Get caller email for the cover sheet — best-effort.
  const { data: callerUser } = await caller.auth.getUser();
  const hospitalEmail = callerUser?.user?.email ?? hospital_user_id;

  // Build ZIP
  const zip = new JSZip();
  zip.file("index.html", renderIndex(equipment_serial, hospitalEmail, dsrRows, months));
  dsrRows.forEach((r, i) => {
    zip.file(`dsr_${i + 1}.html`, renderDsrPage(i + 1, r, equipment_serial));
  });
  zip.file(
    "summary.json",
    JSON.stringify(
      {
        equipment_serial,
        hospital_user_id,
        months_window: months,
        generated_at: new Date().toISOString(),
        dsr_count: dsrRows.length,
        dsrs: dsrRows.map((r) => ({
          dsr_id: r.dsr_id,
          repair_job_id: r.repair_job_id,
          engineer_signed: r.engineer_signature_at,
          hospital_signed: r.hospital_signature_at,
          iec_62353_passed: r.iec_62353_passed,
          calibration_within_oem: r.calibration_within_oem,
          status: r.status,
        })),
      },
      null,
      2,
    ),
  );

  const zipBytes = await zip.generateAsync({
    type: "uint8array",
    compression: "DEFLATE",
    compressionOptions: { level: 6 },
  });

  // Upload via service-role
  const admin = createClient(url, serviceKey, { auth: { persistSession: false } });
  const safeSerial = equipment_serial.replace(/[^a-zA-Z0-9._-]/g, "_").slice(0, 64);
  const stamp = new Date().toISOString().replace(/[:.]/g, "-");
  const objectPath = `${hospital_user_id}/${safeSerial}_${stamp}.zip`;

  const { error: upErr } = await admin.storage
    .from("nabh-bundles")
    .upload(objectPath, zipBytes, {
      contentType: "application/zip",
      upsert: false,
    });
  if (upErr) return bad("upload_failed", upErr.message, 500);

  const { data: signed, error: sErr } = await admin.storage
    .from("nabh-bundles")
    .createSignedUrl(objectPath, 60 * 60);
  if (sErr || !signed?.signedUrl) {
    return bad("sign_failed", sErr?.message ?? "no url", 500);
  }

  return json(200, {
    ok: true,
    object_path: objectPath,
    signed_url: signed.signedUrl,
    expires_in_seconds: 60 * 60,
    dsr_count: dsrRows.length,
    bytes: zipBytes.length,
  });
});
