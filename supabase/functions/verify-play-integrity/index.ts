// Supabase edge function: verify-play-integrity
//
// Server-side verifier for Google Play Integrity tokens. The Android client
// (see PlayIntegrityClient on the integration follow-up) requests an integrity
// token from the Play Integrity API and POSTs it here. We exchange it with
// Google's `decodeIntegrityToken` endpoint, extract the verdicts, log an audit
// row, and return a pass / fail decision the caller can gate sensitive flows on.
//
// We DO NOT trust the token client-side: a rooted device can stub
// PlayIntegrityClient and return "deviceIntegrity.deviceRecognitionVerdict =
// MEETS_DEVICE_INTEGRITY" without ever talking to Google. The only honest
// answer comes from the server -> Google decode call, which is what this
// function does.
//
// Required env:
//   PLAY_INTEGRITY_SERVICE_ACCOUNT_JSON — raw JSON of a Google Cloud service
//     account that has the "Play Integrity API" enabled and the
//     "Service Account User" + Play Integrity Verifier role on the package.
//     Set via:  supabase secrets set PLAY_INTEGRITY_SERVICE_ACCOUNT_JSON="$(cat sa.json)"
//   PLAY_INTEGRITY_PACKAGE_NAME — e.g. "com.equipseva.app"
//   SUPABASE_URL                — injected by Supabase
//   SUPABASE_ANON_KEY           — injected by Supabase
//   SUPABASE_SERVICE_ROLE_KEY   — injected by Supabase; used to insert the
//                                  audit row past RLS.
//
// Request body (JSON, POST, Bearer JWT):
//   { token: string, action?: string }
//
// Response 200:
//   { ok: true, pass: boolean, verdicts: {
//       device: string | null,
//       app: string | null,
//       licensing: string | null,
//     } }
//
// Errors: 400 bad_request, 401 unauthenticated, 502 google_error, 500 server_error

import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.45.4";

type ReqBody = { token?: string; action?: string };

type DecodedIntegrity = {
  tokenPayloadExternal?: {
    requestDetails?: {
      requestPackageName?: string;
      timestampMillis?: string;
      nonce?: string;
    };
    appIntegrity?: {
      appRecognitionVerdict?: string;
      packageName?: string;
      certificateSha256Digest?: string[];
      versionCode?: string;
    };
    deviceIntegrity?: {
      deviceRecognitionVerdict?: string[];
    };
    accountDetails?: {
      appLicensingVerdict?: string;
    };
  };
};

const json = (status: number, body: unknown) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { "content-type": "application/json" },
  });

const bad = (code: string, message: string, status = 400) =>
  json(status, { ok: false, code, message });

// ---- crypto helpers ------------------------------------------------------

function b64urlEncode(bytes: Uint8Array): string {
  let bin = "";
  for (let i = 0; i < bytes.length; i++) bin += String.fromCharCode(bytes[i]);
  return btoa(bin).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

function b64urlEncodeStr(str: string): string {
  return b64urlEncode(new TextEncoder().encode(str));
}

// PEM (PKCS#8) -> raw DER bytes for crypto.subtle.importKey.
function pemToDer(pem: string): Uint8Array {
  const stripped = pem
    .replace(/-----BEGIN [^-]+-----/g, "")
    .replace(/-----END [^-]+-----/g, "")
    .replace(/\s+/g, "");
  const bin = atob(stripped);
  const out = new Uint8Array(bin.length);
  for (let i = 0; i < bin.length; i++) out[i] = bin.charCodeAt(i);
  return out;
}

async function sha256Hex(input: string): Promise<string> {
  const digest = await crypto.subtle.digest(
    "SHA-256",
    new TextEncoder().encode(input),
  );
  return Array.from(new Uint8Array(digest))
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("");
}

// Sign a Google service-account JWT (RS256) and exchange it for an OAuth2
// access token. We could use googleapis Node SDK but raw fetch + WebCrypto is
// simpler in a Deno edge function and avoids the import bloat.
async function getGoogleAccessToken(serviceAccountJson: string): Promise<string> {
  let sa: { client_email: string; private_key: string; token_uri?: string };
  try {
    sa = JSON.parse(serviceAccountJson);
  } catch (e) {
    throw new Error(`PLAY_INTEGRITY_SERVICE_ACCOUNT_JSON is not valid JSON: ${e}`);
  }
  if (!sa.client_email || !sa.private_key) {
    throw new Error("service account JSON missing client_email or private_key");
  }
  const tokenUri = sa.token_uri ?? "https://oauth2.googleapis.com/token";

  const now = Math.floor(Date.now() / 1000);
  const header = { alg: "RS256", typ: "JWT" };
  const claim = {
    iss: sa.client_email,
    scope: "https://www.googleapis.com/auth/playintegrity",
    aud: tokenUri,
    iat: now,
    exp: now + 3600,
  };

  const signingInput = `${b64urlEncodeStr(JSON.stringify(header))}.${b64urlEncodeStr(JSON.stringify(claim))}`;

  // Service account private_key is PEM PKCS#8; literal "\n" inside JSON-loaded
  // strings is fine since JSON.parse already turned them into real newlines.
  const keyDer = pemToDer(sa.private_key);
  const cryptoKey = await crypto.subtle.importKey(
    "pkcs8",
    keyDer,
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const sigBuf = await crypto.subtle.sign(
    "RSASSA-PKCS1-v1_5",
    cryptoKey,
    new TextEncoder().encode(signingInput),
  );
  const jwt = `${signingInput}.${b64urlEncode(new Uint8Array(sigBuf))}`;

  const tokenRes = await fetch(tokenUri, {
    method: "POST",
    headers: { "content-type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion: jwt,
    }),
  });
  const tokenBody = await tokenRes.text();
  if (!tokenRes.ok) {
    throw new Error(`google oauth2 failed: ${tokenRes.status} ${tokenBody}`);
  }
  const parsed = JSON.parse(tokenBody) as { access_token?: string };
  if (!parsed.access_token) {
    throw new Error(`google oauth2 returned no access_token: ${tokenBody}`);
  }
  return parsed.access_token;
}

// ---- verdict evaluation --------------------------------------------------

// What we consider a "pass". The exact policy is intentionally lenient at v1
// because we want to *log* before we *block*. Tighten this later by promoting
// failures from soft-warn to hard-fail in calling sites.
//
// Pass requires:
//   * deviceIntegrity contains at least MEETS_DEVICE_INTEGRITY (or stronger)
//   * appIntegrity.appRecognitionVerdict is PLAY_RECOGNIZED
//   * accountDetails.appLicensingVerdict is LICENSED (only if present)
function evaluatePass(
  device: string[] | undefined,
  app: string | undefined,
  licensing: string | undefined,
): boolean {
  const deviceOk = !!device && device.some((v) =>
    v === "MEETS_DEVICE_INTEGRITY" ||
    v === "MEETS_STRONG_INTEGRITY" ||
    v === "MEETS_VIRTUAL_INTEGRITY"
  );
  const appOk = app === "PLAY_RECOGNIZED";
  // If accountDetails was omitted by Google, treat as pass — some integrations
  // don't request the licensing verdict and that's fine.
  const licensingOk = !licensing || licensing === "LICENSED";
  return deviceOk && appOk && licensingOk;
}

// ---- handler -------------------------------------------------------------

serve(async (req) => {
  if (req.method !== "POST") return bad("bad_request", "POST only", 405);

  const authHeader = req.headers.get("authorization") ?? "";
  if (!authHeader.toLowerCase().startsWith("bearer ")) {
    return bad("unauthenticated", "missing bearer token", 401);
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY");
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  const saJson = Deno.env.get("PLAY_INTEGRITY_SERVICE_ACCOUNT_JSON");
  const packageName = Deno.env.get("PLAY_INTEGRITY_PACKAGE_NAME");
  if (!supabaseUrl || !anonKey || !serviceKey || !saJson || !packageName) {
    return bad("server_error", "edge function not configured", 500);
  }

  // Identity check uses an anon-key client carrying the caller's bearer
  // header so the JWT is decoded under the role it was issued for. We do
  // NOT mix the service-role key with the caller's header — see
  // verify-razorpay-payment for the rationale.
  const identityClient = createClient(supabaseUrl, anonKey, {
    global: { headers: { Authorization: authHeader } },
  });
  const { data: userData, error: userErr } = await identityClient.auth.getUser();
  if (userErr || !userData?.user?.id) {
    return bad("unauthenticated", "invalid token", 401);
  }
  const userId = userData.user.id;

  let body: ReqBody;
  try {
    body = await req.json();
  } catch {
    return bad("bad_request", "invalid json");
  }

  const token = body.token;
  if (!token || typeof token !== "string") {
    return bad("bad_request", "token missing");
  }
  // Play Integrity tokens are JWE blobs; size in practice is ~1-4 KB. Cap to
  // 16 KB to avoid a malicious caller burning Google quota with junk strings.
  if (token.length > 16384) {
    return bad("bad_request", "token too large");
  }

  const action = (body.action ?? "default").toString();
  if (action.length === 0 || action.length > 64) {
    return bad("bad_request", "action must be 1..64 chars");
  }

  // Hash the token once up front so we can write the audit row even if the
  // Google call fails (still useful to know an attempt happened).
  const tokenHash = await sha256Hex(token);

  let device: string[] | undefined;
  let app: string | undefined;
  let licensing: string | undefined;
  let googleErr: string | null = null;

  try {
    const accessToken = await getGoogleAccessToken(saJson);
    const decodeUrl =
      `https://playintegrity.googleapis.com/v1/${encodeURIComponent(packageName)}:decodeIntegrityToken`;
    const decodeRes = await fetch(decodeUrl, {
      method: "POST",
      headers: {
        authorization: `Bearer ${accessToken}`,
        "content-type": "application/json",
      },
      body: JSON.stringify({ integrityToken: token }),
    });
    const decodeBody = await decodeRes.text();
    if (!decodeRes.ok) {
      googleErr = `decode failed: ${decodeRes.status} ${decodeBody}`;
    } else {
      const decoded = JSON.parse(decodeBody) as DecodedIntegrity;
      const payload = decoded.tokenPayloadExternal ?? {};

      // Defense-in-depth: package name in the decoded token must match what
      // we configured. Otherwise an attacker could submit a valid token
      // belonging to a different (perhaps friendlier) package.
      const tokenPkg = payload.requestDetails?.requestPackageName;
      if (tokenPkg && tokenPkg !== packageName) {
        googleErr = `package_name mismatch: expected ${packageName} got ${tokenPkg}`;
      } else {
        device = payload.deviceIntegrity?.deviceRecognitionVerdict;
        app = payload.appIntegrity?.appRecognitionVerdict;
        licensing = payload.accountDetails?.appLicensingVerdict;
      }
    }
  } catch (e) {
    googleErr = e instanceof Error ? e.message : String(e);
  }

  const pass = googleErr === null && evaluatePass(device, app, licensing);

  // Audit row — service-role bypasses RLS. We log on every call (including
  // googleErr) so we can see attack patterns even when Google is down.
  const admin = createClient(supabaseUrl, serviceKey);
  const { error: auditErr } = await admin
    .from("device_integrity_checks")
    .insert({
      user_id: userId,
      action,
      device_verdict: device && device.length > 0 ? device.join(",") : null,
      app_verdict: app ?? null,
      licensing_verdict: licensing ?? null,
      raw_token_hash: tokenHash,
      pass,
    });
  if (auditErr) {
    // Log but don't fail the call — the verdict itself is still useful.
    console.error("device_integrity_checks insert failed", auditErr);
  }

  if (googleErr) {
    return json(502, {
      ok: false,
      code: "google_error",
      message: googleErr,
      pass: false,
    });
  }

  return json(200, {
    ok: true,
    pass,
    verdicts: {
      device: device && device.length > 0 ? device.join(",") : null,
      app: app ?? null,
      licensing: licensing ?? null,
    },
  });
});
