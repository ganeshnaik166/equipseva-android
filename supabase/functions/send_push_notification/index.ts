// Supabase edge function: send_push_notification
//
// Fan-out push delivery for `public.notifications`. Triggered by a Supabase
// Database Webhook (or pg_net trigger) on INSERT into `public.notifications`.
// Looks up the recipient's `device_tokens` rows (max 10) and pushes the
// notification via FCM HTTP v1. Token deletion is held until a versioned
// server claim can distinguish a stale FCM result from a new owner.
//
// Webhook payload shape (Supabase DB webhook):
//   { type: "INSERT" | "UPDATE" | "DELETE", table, schema, record, old_record }
//
// Required env (set via `supabase secrets set`):
//   - FCM_PROJECT_ID            : Firebase project id (e.g. equipseva-prod)
//   - FCM_SERVICE_ACCOUNT_JSON  : Service-account JSON (full string) with
//                                 firebase.messaging.send permission. The
//                                 private key inside MUST be PKCS8 PEM.
//   - SUPABASE_URL              : auto-injected by the Supabase runtime
//   - SUPABASE_SERVICE_ROLE_KEY : auto-injected by the Supabase runtime
//
// Auth: this function is invoked by Supabase webhooks/triggers, so we accept
// either:
//   - a service-role bearer token (webhook signed with the service-role JWT),
//   - or the `x-webhook-secret` header matching `PUSH_WEBHOOK_SECRET`.
// We never trust the request body's user_id without re-fetching the
// notification row server-side (defence-in-depth — even though the row was
// just written, we re-read by id under service role to confirm it exists).
//
// Log aggregate counts only, never token fragments, recipient IDs or content.

import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.45.4";
import {
  deliverNotification,
  sendToFcm,
} from "./push_contract.ts";

const FCM_SCOPE = "https://www.googleapis.com/auth/firebase.messaging";
const GOOGLE_TOKEN_URL = "https://oauth2.googleapis.com/token";
const MAX_TOKENS_PER_USER = 10;

interface WebhookPayload {
  type?: string;
  table?: string;
  schema?: string;
  record?: {
    id?: string;
    user_id?: string;
    title?: string | null;
    body?: string | null;
    data?: Record<string, unknown> | null;
    kind?: string | null;
  };
  old_record?: unknown;
}

interface ServiceAccount {
  client_email: string;
  private_key: string;
  token_uri?: string;
  // Round 447: cross-check against FCM_PROJECT_ID env to catch
  // staging↔prod cred mix-ups before they produce opaque 404s.
  project_id?: string;
}

const json = (status: number, body: unknown) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { "content-type": "application/json" },
  });

// Constant-time string compare so a timing oracle can't recover the
// shared secret / service-key one byte at a time.
function timingSafeEqual(a: string, b: string): boolean {
  if (a.length !== b.length) return false;
  let diff = 0;
  for (let i = 0; i < a.length; i++) diff |= a.charCodeAt(i) ^ b.charCodeAt(i);
  return diff === 0;
}

// ---------- JWT signing ----------

function b64urlEncode(bytes: Uint8Array): string {
  let bin = "";
  for (let i = 0; i < bytes.length; i++) bin += String.fromCharCode(bytes[i]);
  return btoa(bin).replaceAll("+", "-").replaceAll("/", "_").replaceAll("=", "");
}

function b64urlEncodeStr(s: string): string {
  return b64urlEncode(new TextEncoder().encode(s));
}

function pemToPkcs8(pem: string): Uint8Array<ArrayBuffer> {
  const cleaned = pem
    .replace(/-----BEGIN PRIVATE KEY-----/g, "")
    .replace(/-----END PRIVATE KEY-----/g, "")
    .replace(/\\n/g, "\n")
    .replace(/\s+/g, "");
  const raw = atob(cleaned);
  // WebCrypto's BufferSource requires an ArrayBuffer-backed view. Explicitly
  // allocate one so newer Deno types do not widen this to SharedArrayBuffer.
  const out = new Uint8Array(new ArrayBuffer(raw.length));
  for (let i = 0; i < raw.length; i++) out[i] = raw.charCodeAt(i);
  return out;
}

async function signJwtRs256(sa: ServiceAccount): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  const header = { alg: "RS256", typ: "JWT" };
  const claim = {
    iss: sa.client_email,
    scope: FCM_SCOPE,
    aud: sa.token_uri ?? GOOGLE_TOKEN_URL,
    iat: now,
    exp: now + 3600,
  };
  const signingInput = `${b64urlEncodeStr(JSON.stringify(header))}.${b64urlEncodeStr(JSON.stringify(claim))}`;

  const keyData = pemToPkcs8(sa.private_key);
  const key = await crypto.subtle.importKey(
    "pkcs8",
    keyData,
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const sig = await crypto.subtle.sign(
    "RSASSA-PKCS1-v1_5",
    key,
    new TextEncoder().encode(signingInput),
  );
  return `${signingInput}.${b64urlEncode(new Uint8Array(sig))}`;
}

// ---------- Access-token cache ----------
// The function instance can stay warm across multiple invocations; cache the
// OAuth access token until ~60s before expiry to avoid re-signing on every
// webhook firing.
let cachedToken: { token: string; expiresAt: number } | null = null;

async function getAccessToken(sa: ServiceAccount): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  if (cachedToken && cachedToken.expiresAt - 60 > now) {
    return cachedToken.token;
  }
  const jwt = await signJwtRs256(sa);
  // Cap Google OAuth wait at 10s — a hung token endpoint would
  // otherwise tie up the push pipeline for the full execution budget.
  const res = await fetch(sa.token_uri ?? GOOGLE_TOKEN_URL, {
    method: "POST",
    headers: { "content-type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion: jwt,
    }),
    signal: AbortSignal.timeout(10_000),
  });
  if (!res.ok) {
    throw new Error(`google_oauth_failed:${res.status}`);
  }
  const body = await res.json() as { access_token: string; expires_in: number };
  cachedToken = {
    token: body.access_token,
    expiresAt: now + (body.expires_in ?? 3600),
  };
  return cachedToken.token;
}

// ---------- HTTP handler ----------

serve(async (req) => {
  if (req.method !== "POST") {
    return json(405, { ok: false, code: "method_not_allowed" });
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  const fcmProjectId = Deno.env.get("FCM_PROJECT_ID");
  const fcmSaRaw = Deno.env.get("FCM_SERVICE_ACCOUNT_JSON");
  const webhookSecret = Deno.env.get("PUSH_WEBHOOK_SECRET");
  if (!supabaseUrl || !serviceKey || !fcmProjectId || !fcmSaRaw) {
    return json(500, { ok: false, code: "server_error", message: "edge function not configured" });
  }

  // Webhook auth: accept either service-role bearer (Supabase webhook signs
  // with the service-role JWT) or x-webhook-secret matching PUSH_WEBHOOK_SECRET.
  // Both compares are constant-time so a timing oracle can't recover either
  // secret byte-by-byte.
  const authHeader = req.headers.get("authorization") ?? "";
  const presentedSecret = req.headers.get("x-webhook-secret") ?? "";
  const bearer = authHeader.toLowerCase().startsWith("bearer ")
    ? authHeader.slice(7).trim()
    : "";
  const bearerOk = timingSafeEqual(bearer, serviceKey);
  const secretOk = !!webhookSecret && timingSafeEqual(presentedSecret, webhookSecret);
  if (!bearerOk && !secretOk) {
    return json(401, { ok: false, code: "unauthenticated" });
  }

  let payload: WebhookPayload;
  try {
    payload = await req.json();
  } catch {
    return json(400, { ok: false, code: "bad_request", message: "invalid json" });
  }

  if (
    payload.type !== "INSERT" ||
    payload.table !== "notifications" ||
    payload.schema !== "public"
  ) {
    // Not for us — ack so the webhook doesn't retry.
    return json(200, { ok: true, skipped: true });
  }
  const rec = payload.record;
  if (!rec?.id || !rec.user_id) {
    return json(400, { ok: false, code: "bad_request", message: "record missing id/user_id" });
  }

  let sa: ServiceAccount;
  try {
    sa = JSON.parse(fcmSaRaw) as ServiceAccount;
  } catch {
    return json(500, { ok: false, code: "server_error", message: "service account json invalid" });
  }
  if (!sa.client_email || !sa.private_key) {
    return json(500, { ok: false, code: "server_error", message: "service account incomplete" });
  }
  // Round 447: cross-check that FCM_PROJECT_ID env matches the service
  // account's project_id. Mismatched config (e.g. SA from project A,
  // FCM_PROJECT_ID points at project B from staging-prod copy-paste)
  // produces opaque 404 NOT_FOUND / 403 PERMISSION_DENIED from FCM
  // far downstream. Surface up front with a clear error.
  if (sa.project_id && sa.project_id !== fcmProjectId) {
    console.error("send_push_notification fcm_project_mismatch");
    return json(500, {
      ok: false,
      code: "server_error",
      message: "fcm project mismatch",
    });
  }

  const admin = createClient(supabaseUrl, serviceKey);

  // Re-fetch under service role to avoid trusting the webhook body blindly.
  const { data: notif, error: notifErr } = await admin
    .from("notifications")
    .select("id, user_id, title, body, data, kind")
    .eq("id", rec.id)
    .maybeSingle();
  if (notifErr) {
    // Don't echo PostgREST raw error in the response — webhook
    // response is captured to function logs which carry the SQL
    // hints / table names. Same pattern as PR #686 / PR #704.
    console.error("send_push_notification notif_fetch_failed");
    return json(500, { ok: false, code: "server_error", message: "notif_fetch_failed" });
  }
  if (!notif) return json(200, { ok: true, skipped: true, reason: "row_gone" });

  const { data: tokens, error: tokensErr } = await admin
    .from("device_tokens")
    .select("id, token")
    .eq("user_id", notif.user_id)
    .order("updated_at", { ascending: false })
    .limit(MAX_TOKENS_PER_USER);
  if (tokensErr) {
    console.error("send_push_notification tokens_fetch_failed");
    return json(500, { ok: false, code: "server_error", message: "tokens_fetch_failed" });
  }
  if (!tokens || tokens.length === 0) {
    return json(200, { ok: true, sent: 0, reason: "no_devices" });
  }

  let accessToken: string;
  try {
    accessToken = await getAccessToken(sa);
  } catch {
    // OAuth errors can contain account metadata. Log only the fixed code.
    console.error("send_push_notification fcm_auth_failed");
    return json(502, { ok: false, code: "fcm_auth_failed", message: "fcm_auth_failed" });
  }

  // A DB webhook's record and even notifications.data are selectors, never
  // outbound payloads. The fetched row supplies the recipient; the pure
  // contract builds generic text and an allow-listed route for Android taps.
  const outcome = await deliverNotification(
    notif,
    tokens.map((t) => t.token),
    (message) => sendToFcm(fcmProjectId, accessToken, message),
  );

  // Never DELETE by token: a delayed UNREGISTERED for A can remove B's fresh
  // claim after a shared device switches accounts. Count old rows until the
  // versioned claim/reap API is deployed; operations must watch this count.
  console.log(JSON.stringify({
    devices: tokens.length,
    sent: outcome.sent,
    failed: outcome.failed,
    unregistered_count: outcome.unregistered,
    transport_failure: outcome.transportFailure,
  }));

  // Preserve the old non-2xx response for transport exceptions. Whether the
  // webhook dispatcher retries is deployment-specific and unverified here.
  // A replay can duplicate successful siblings; exactly-once needs a ledger.
  if (outcome.transportFailure) {
    return json(502, {
      ok: false,
      code: "fcm_transport_failure",
      sent: outcome.sent,
      failed: outcome.failed,
      reaped: 0,
    });
  }
  return json(200, {
    ok: true,
    sent: outcome.sent,
    failed: outcome.failed,
    reaped: 0,
  });
});
