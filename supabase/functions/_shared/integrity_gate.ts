// Shared integrity gate. Reads the X-Equipseva-Integrity header (r844)
// the Android client stamps on every Supabase / Edge Function request,
// and (when EDGE_INTEGRITY_ENFORCE=true) refuses calls from clients
// self-reporting a dirty state.
//
// Why this is useful: even though a tampered client can lie about the
// header, most lazy mods patch ONE if-block in onCreate without
// stripping the snapshot — so this header still flags a lot of real
// tampering. Pair with the verify-play-integrity Google attestation
// for high-stakes ops (payment, KYC, payout) where the Google verdict
// is the final word.
//
// Failure modes:
//   - HEADER ABSENT  → returns null (allow). Old client versions before
//                       r844 didn't send it; we don't want to break them.
//   - HEADER PRESENT WITH 'sig=tampered'    → returns 'tampered'
//   - HEADER PRESENT WITH 'install=sideloaded' → returns 'sideloaded'
//   - HEADER PRESENT WITH 'root=1'/'frida=1'  → returns 'instrumented'
//   - HEADER PRESENT, CLEAN                   → returns null (allow)
//
// The caller decides whether to BLOCK (return 403) or LOG-ONLY based on
// the EDGE_INTEGRITY_ENFORCE env var (default off so the layer can
// soak in production audit-only before flipping).

export type IntegrityVerdict =
  | "tampered"      // sig=tampered
  | "sideloaded"    // install=sideloaded
  | "instrumented"; // root=1 / frida=1 / dbg=1 in release

export interface IntegrityCheckResult {
  /** raw header value, or null if missing. */
  header: string | null;
  /** verdict label, or null when clean / missing. */
  verdict: IntegrityVerdict | null;
  /** whether the caller should reject this request given enforce mode. */
  shouldBlock: boolean;
}

export function checkClientIntegrity(req: Request): IntegrityCheckResult {
  let header = req.headers.get("x-equipseva-integrity");
  if (header && header.length > 512) header = header.slice(0, 512);

  if (!header) {
    return { header: null, verdict: null, shouldBlock: false };
  }

  // Quick substring checks. The header is comma-separated like:
  // sig=tampered,install=sideloaded,re=2,root=1,frida=1,dbg=1
  let verdict: IntegrityVerdict | null = null;
  if (header.includes("sig=tampered")) verdict = "tampered";
  else if (header.includes("install=sideloaded")) verdict = "sideloaded";
  else if (
    header.includes("root=1") ||
    header.includes("frida=1") ||
    header.includes("dbg=1")
  ) verdict = "instrumented";

  const enforce = (Deno.env.get("EDGE_INTEGRITY_ENFORCE") ?? "false")
    .toLowerCase() === "true";
  const shouldBlock = enforce && verdict !== null;

  return { header, verdict, shouldBlock };
}

/** Convenience: returns a 403 Response when shouldBlock, else null. */
export function maybeBlockIntegrity(req: Request): Response | null {
  const r = checkClientIntegrity(req);
  if (!r.shouldBlock) return null;
  return new Response(
    JSON.stringify({
      ok: false,
      code: "integrity_blocked",
      message: "Couldn't verify your install. Please reinstall from Google Play.",
      verdict: r.verdict,
    }),
    { status: 403, headers: { "content-type": "application/json" } },
  );
}
