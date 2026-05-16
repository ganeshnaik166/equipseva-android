// Supabase edge function: request-call-session
//
// Bridges a hospital ↔ engineer call through Exotel's click-to-call API
// without exposing either party's real phone number. The hospital's
// device shows "Connecting your call…" while Exotel rings the
// hospital's MSISDN from EXOTEL_VIRTUAL_NUMBER, the hospital answers,
// then Exotel rings the engineer and bridges. Neither party's call log
// shows the other's number — both see EXOTEL_VIRTUAL_NUMBER.
//
// Anti-disintermediation: this is the moat that makes the v2 commission
// model viable. As long as the bridge is the only way to call, the
// hospital/engineer can't go off-app on subsequent jobs.
//
// Graceful "not configured" fallback: while Exotel onboarding is in
// flight (KYC + GST + signed MSA = 5-7 days external dep), the env
// vars EXOTEL_ACCOUNT_SID / EXOTEL_API_KEY / EXOTEL_API_TOKEN /
// EXOTEL_VIRTUAL_NUMBER are absent. Function returns 503
// `provider_not_configured` so the client can show "Calls coming soon"
// instead of crashing. The moment the four env vars land via
// `supabase secrets set`, the same client code lights up live.
//
// Request (JSON, POST, Bearer JWT):
//   { repair_job_id: uuid }
//
// Response 200:
//   { ok: true, mode: 'click_to_call', message: 'Connecting your call…',
//     call_sid: string }
//
// Errors:
//   400 bad_request                 — missing/malformed body
//   401 unauthenticated             — no bearer
//   403 not_participant             — caller isn't hospital or engineer of this job
//   404 job_not_found               — bad job id
//   422 missing_phone               — counterpart hasn't completed phone capture
//   429 rate_limited                — > 5 calls/job/day for this caller
//   502 exotel_error                — Exotel API failure
//   503 provider_not_configured     — Exotel env vars not set yet
//   500 server_error                — unexpected
//
// Server-side cap: max 5 calls per (job, caller) per day → 429.
// Reuses an unexpired ringing/answered session within 5 min for
// rapid retries (user tapped twice, network blip, etc).

import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.45.4";

const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

const json = (status: number, body: unknown) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { "content-type": "application/json" },
  });

const bad = (code: string, message: string, status = 400) =>
  json(status, { ok: false, code, message });

serve(async (req) => {
  if (req.method !== "POST") return bad("bad_request", "POST only", 405);

  // 1. Bearer JWT identity
  const authHeader = req.headers.get("authorization") ?? "";
  if (!authHeader.toLowerCase().startsWith("bearer ")) {
    return bad("unauthenticated", "missing bearer token", 401);
  }
  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY");
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!supabaseUrl || !anonKey || !serviceKey) {
    return bad("server_error", "supabase env not configured", 500);
  }

  // Identity-only client. Decoupled from the privileged client below
  // (mixing service_role + caller bearer on the same client is a
  // known supabase-js footgun).
  const identity = createClient(supabaseUrl, anonKey, {
    global: { headers: { Authorization: authHeader } },
  });
  const { data: userData, error: userErr } = await identity.auth.getUser();
  if (userErr || !userData?.user?.id) {
    return bad("unauthenticated", "invalid token", 401);
  }
  const callerId = userData.user.id;

  // 2. Parse body
  let body: any;
  try {
    body = await req.json();
  } catch {
    return bad("bad_request", "json body required");
  }
  const repairJobId = String(body?.repair_job_id ?? "").trim();
  if (!UUID_RE.test(repairJobId)) {
    return bad("bad_request", "repair_job_id must be a uuid");
  }

  // 3. Service-role lookup of participants + real phones. RLS blocks
  // direct profiles.phone reads from non-self callers, so we go
  // through the participants_for_repair_job RPC which is
  // service-role-only.
  const admin = createClient(supabaseUrl, serviceKey);
  const { data: participantsData, error: pErr } = await admin
    .rpc("participants_for_repair_job", { p_job_id: repairJobId });
  if (pErr) {
    // Don't echo raw PostgREST error — same log-leak pattern PR #686 /
    // #704 / #705 / #706 / #707 closed elsewhere. Log full detail
    // server-side; surface a stable code.
    console.error("request-call-session participants_lookup_failed", pErr);
    return bad("server_error", "participants_lookup_failed", 500);
  }
  const row = Array.isArray(participantsData) ? participantsData[0] : participantsData;
  if (!row) return bad("job_not_found", "no such repair job", 404);

  const isHospital = row.hospital_user_id === callerId;
  const isEngineer = row.engineer_user_id === callerId;
  if (!isHospital && !isEngineer) {
    return bad("not_participant", "you're not a party to this job", 403);
  }

  const callerPhone = isHospital ? row.hospital_phone : row.engineer_phone;
  const calleePhone = isHospital ? row.engineer_phone : row.hospital_phone;
  const calleeUserId = isHospital ? row.engineer_user_id : row.hospital_user_id;
  if (!callerPhone || !calleePhone) {
    return bad("missing_phone", "counterpart hasn't added a phone yet", 422);
  }

  // 4. Rate-limit: two concentric caps so a malicious caller can't
  // enumerate counterpart phones across many active jobs.
  //
  //   (a) per-(job, caller): 5/day. Catches a frustrated user
  //       hammering one bridge.
  //   (b) per-caller global: 20/day across all jobs. Catches a
  //       hostile caller iterating across N jobs to sweep up phones
  //       (without (b), 100 active jobs * 5/day = 500 enumeration
  //       attempts/day — high enough to harvest a directory).
  const dayAgo = new Date(Date.now() - 24 * 60 * 60 * 1000).toISOString();
  const callerCol = isHospital ? "hospital_user_id" : "engineer_user_id";
  const { count: recentCount } = await admin
    .from("virtual_call_sessions")
    .select("id", { count: "exact", head: true })
    .eq("repair_job_id", repairJobId)
    .eq(callerCol, callerId)
    .gte("created_at", dayAgo);
  if ((recentCount ?? 0) >= 5) {
    return bad(
      "rate_limited",
      "Too many call attempts today. Chat the counterpart instead.",
      429,
    );
  }
  const { count: globalCount } = await admin
    .from("virtual_call_sessions")
    .select("id", { count: "exact", head: true })
    .eq(callerCol, callerId)
    .gte("created_at", dayAgo);
  if ((globalCount ?? 0) >= 20) {
    return bad(
      "rate_limited",
      "Daily call limit reached. Use chat for now.",
      429,
    );
  }

  // 5. Reuse an in-flight session (5-min window) for rapid retries.
  const fiveMinAgo = new Date(Date.now() - 5 * 60 * 1000).toISOString();
  const { data: existing } = await admin
    .from("virtual_call_sessions")
    .select("id, exotel_call_sid, status, last_called_at")
    .eq("repair_job_id", repairJobId)
    .eq("hospital_user_id", row.hospital_user_id)
    .eq("engineer_user_id", row.engineer_user_id)
    .gte("last_called_at", fiveMinAgo)
    .in("status", ["pending", "ringing", "answered"])
    .order("last_called_at", { ascending: false })
    .limit(1);
  const reuse = existing?.[0];

  // 6. Provider config check. If env not set (Exotel onboarding still
  // pending), return 503 with a clear code; client shows "Calls
  // coming soon". The session table + RLS + RPC are all live so
  // flipping the four env vars is the only step left.
  const exotelSid = Deno.env.get("EXOTEL_ACCOUNT_SID");
  const exotelKey = Deno.env.get("EXOTEL_API_KEY");
  const exotelToken = Deno.env.get("EXOTEL_API_TOKEN");
  const exotelCallerId = Deno.env.get("EXOTEL_VIRTUAL_NUMBER");
  if (!exotelSid || !exotelKey || !exotelToken || !exotelCallerId) {
    return json(503, {
      ok: false,
      code: "provider_not_configured",
      message:
        "Calls are coming soon. Use chat for now — your details stay private.",
    });
  }

  if (reuse) {
    // Reuse — bump call_count + last_called_at without redialing
    // Exotel (the previous bridge is still ringing or just hung up).
    await admin
      .from("virtual_call_sessions")
      .update({
        call_count: (reuse as any).call_count
          ? (reuse as any).call_count + 1
          : 1,
        last_called_at: new Date().toISOString(),
      })
      .eq("id", (reuse as any).id);
    return json(200, {
      ok: true,
      mode: "click_to_call",
      message: "Reconnecting your call…",
      call_sid: (reuse as any).exotel_call_sid ?? null,
    });
  }

  // 7. Exotel /Calls/connect — bridges the two MSISDNs from
  // EXOTEL_VIRTUAL_NUMBER. Both legs see the ExoPhone in their call
  // log; neither sees the other's real number. Record=false (DPDP
  // posture: no recording without explicit consent UI).
  const exotelUrl = `https://api.exotel.com/v1/Accounts/${exotelSid}/Calls/connect`;
  const form = new URLSearchParams();
  form.set("From", callerPhone);
  form.set("To", calleePhone);
  form.set("CallerId", exotelCallerId);
  form.set("Record", "false");
  form.set("CustomField", repairJobId);

  const auth = "Basic " + btoa(`${exotelKey}:${exotelToken}`);
  let exotelResp: Response;
  try {
    // Cap Exotel wait at 10s — bridge connect typically lands in
    // ~500ms but a hung upstream would otherwise tie up the function
    // for the full 300s execution budget while the hospital stares
    // at the connecting dialog.
    exotelResp = await fetch(exotelUrl, {
      method: "POST",
      headers: {
        Authorization: auth,
        "Content-Type": "application/x-www-form-urlencoded",
      },
      body: form.toString(),
      signal: AbortSignal.timeout(10_000),
    });
  } catch (e) {
    // Don't surface raw network/Exotel error text to the client — it can echo
    // the From=/To= MSISDNs we sent in the form body or internal diagnostics.
    // Log full detail server-side; return generic code to caller.
    console.error("request-call-session: exotel network error", e);
    return bad("exotel_error", "call provider unavailable", 502);
  }
  if (!exotelResp.ok) {
    const txt = await exotelResp.text().catch(() => "");
    // Exotel error bodies can echo back the From=/To= MSISDNs we sent
    // in the form body. Redact 10-digit blocks before logging so even
    // server-side logs don't carry caller phone numbers (CodeRabbit
    // PR #321 follow-up).
    const redacted = txt.replace(/[6-9]\d{9}/g, "[REDACTED_MSISDN]").slice(0, 400);
    console.error("request-call-session: exotel non-2xx", exotelResp.status, redacted);
    return bad("exotel_error", "call provider unavailable", 502);
  }
  let exotelJson: any = null;
  try {
    exotelJson = await exotelResp.json();
  } catch {
    // Some Exotel responses are XML; we don't need to parse — Sid
    // ends up in the headers or body. For now, treat absence of Sid
    // as success-with-no-tracking.
  }
  const callSid: string | null =
    exotelJson?.Call?.Sid ?? exotelJson?.Sid ?? null;

  // 8. Persist the session row for analytics + the exotel-status
  // callback (Phase 2) which will flip status to answered/completed.
  const nowIso = new Date().toISOString();
  await admin
    .from("virtual_call_sessions")
    .insert({
      repair_job_id: repairJobId,
      hospital_user_id: row.hospital_user_id,
      engineer_user_id: row.engineer_user_id,
      provider: "exotel",
      exotel_call_sid: callSid,
      status: "ringing",
      last_called_at: nowIso,
      call_count: 1,
    });

  return json(200, {
    ok: true,
    mode: "click_to_call",
    message: "Connecting your call…",
    call_sid: callSid,
  });
});
