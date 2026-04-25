// Supabase edge function: send_push_notification
//
// Fan-out push delivery for `public.notifications`. Triggered by a Supabase
// Database Webhook (or pg_net trigger) on INSERT into `public.notifications`.
// Looks up the recipient's `device_tokens` rows (max 10) and pushes the
// notification via FCM HTTP v1. Dead tokens (404 / UNREGISTERED) are deleted.
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
// We deliberately log only counts / token-suffixes — never title, body, or
// user_id — to keep PII out of edge function logs.

import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.45.4";

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
}

const json = (status: number, body: unknown) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { "content-type": "application/json" },
  });

// ---------- JWT signing ----------

function b64urlEncode(bytes: Uint8Array): string {
  let bin = "";
  for (let i = 0; i < bytes.length; i++) bin += String.fromCharCode(bytes[i]);
  return btoa(bin).replaceAll("+", "-").replaceAll("/", "_").replaceAll("=", "");
}

function b64urlEncodeStr(s: string): string {
  return b64urlEncode(new TextEncoder().encode(s));
}

function pemToPkcs8(pem: string): Uint8Array {
  const cleaned = pem
    .replace(/-----BEGIN PRIVATE KEY-----/g, "")
    .replace(/-----END PRIVATE KEY-----/g, "")
    .replace(/\\n/g, "\n")
    .replace(/\s+/g, "");
  const raw = atob(cleaned);
  const out = new Uint8Array(raw.length);
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
  const res = await fetch(sa.token_uri ?? GOOGLE_TOKEN_URL, {
    method: "POST",
    headers: { "content-type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion: jwt,
    }),
  });
  if (!res.ok) {
    const txt = await res.text();
    throw new Error(`google_oauth_failed: ${res.status} ${txt.slice(0, 200)}`);
  }
  const body = await res.json() as { access_token: string; expires_in: number };
  cachedToken = {
    token: body.access_token,
    expiresAt: now + (body.expires_in ?? 3600),
  };
  return cachedToken.token;
}

// ---------- FCM send ----------

interface SendResult {
  token: string;
  ok: boolean;
  status: number;
  unregistered: boolean;
}

async function sendOne(
  projectId: string,
  accessToken: string,
  token: string,
  title: string | null,
  body: string | null,
  data: Record<string, unknown>,
): Promise<SendResult> {
  // FCM v1 requires `data` values to be strings.
  const dataStr: Record<string, string> = {};
  for (const [k, v] of Object.entries(data ?? {})) {
    if (v === null || v === undefined) continue;
    dataStr[k] = typeof v === "string" ? v : JSON.stringify(v);
  }

  const message: Record<string, unknown> = {
    token,
    data: dataStr,
  };
  if (title || body) {
    message.notification = {
      title: title ?? "",
      body: body ?? "",
    };
  }

  const res = await fetch(
    `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`,
    {
      method: "POST",
      headers: {
        "content-type": "application/json",
        authorization: `Bearer ${accessToken}`,
      },
      body: JSON.stringify({ message }),
    },
  );

  let unregistered = false;
  if (!res.ok) {
    const txt = await res.text();
    // FCM v1 surfaces dead tokens as 404 + status UNREGISTERED, or 400 with
    // INVALID_ARGUMENT for malformed tokens. Treat both as deletable.
    if (
      res.status === 404 ||
      txt.includes("UNREGISTERED") ||
      txt.includes("registration-token-not-registered")
    ) {
      unregistered = true;
    }
  }
  return { token, ok: res.ok, status: res.status, unregistered };
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
  const authHeader = req.headers.get("authorization") ?? "";
  const presentedSecret = req.headers.get("x-webhook-secret") ?? "";
  const bearer = authHeader.toLowerCase().startsWith("bearer ")
    ? authHeader.slice(7).trim()
    : "";
  const bearerOk = bearer === serviceKey;
  const secretOk = !!webhookSecret && presentedSecret === webhookSecret;
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

  const admin = createClient(supabaseUrl, serviceKey);

  // Re-fetch under service role to avoid trusting the webhook body blindly.
  const { data: notif, error: notifErr } = await admin
    .from("notifications")
    .select("id, user_id, title, body, data, kind")
    .eq("id", rec.id)
    .maybeSingle();
  if (notifErr) return json(500, { ok: false, code: "server_error", message: notifErr.message });
  if (!notif) return json(200, { ok: true, skipped: true, reason: "row_gone" });

  const { data: tokens, error: tokensErr } = await admin
    .from("device_tokens")
    .select("id, token")
    .eq("user_id", notif.user_id)
    .order("updated_at", { ascending: false })
    .limit(MAX_TOKENS_PER_USER);
  if (tokensErr) {
    return json(500, { ok: false, code: "server_error", message: tokensErr.message });
  }
  if (!tokens || tokens.length === 0) {
    return json(200, { ok: true, sent: 0, reason: "no_devices" });
  }

  let accessToken: string;
  try {
    accessToken = await getAccessToken(sa);
  } catch (e) {
    return json(502, { ok: false, code: "fcm_auth_failed", message: String(e).slice(0, 200) });
  }

  const data = (notif.data ?? {}) as Record<string, unknown>;
  // Tag deep-link metadata for the Android click handler.
  if (notif.kind && typeof data.kind === "undefined") {
    data.kind = notif.kind;
  }
  if (typeof data.notification_id === "undefined") {
    data.notification_id = notif.id;
  }

  const results = await Promise.all(
    tokens.map((t) => sendOne(fcmProjectId, accessToken, t.token, notif.title, notif.body, data)),
  );

  // Reap dead tokens.
  const dead = results.filter((r) => r.unregistered).map((r) => r.token);
  if (dead.length > 0) {
    await admin.from("device_tokens").delete().in("token", dead);
  }

  const sent = results.filter((r) => r.ok).length;
  // No PII in logs — token suffix only, for grep-by-device debugging.
  console.log(JSON.stringify({
    notification_id: notif.id,
    devices: tokens.length,
    sent,
    failed: results.length - sent,
    dead_count: dead.length,
    token_suffixes: results.map((r) => r.token.slice(-8)),
  }));

  return json(200, { ok: true, sent, failed: results.length - sent, reaped: dead.length });
});
