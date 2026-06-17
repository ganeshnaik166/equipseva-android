import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { StatCard } from "@/components/StatCard";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "Security overview — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type SummaryRow = {
  window_label: string;
  total_checks: number;
  pass_count: number;
  fail_count: number;
  dirty_header: number;
  pass_pct: number;
};

type DirtyRow = {
  id: string;
  user_id: string;
  display_name: string;
  action: string;
  pass: boolean;
  device_verdict: string | null;
  client_header: string | null;
  created_at: string;
};

const LAYERS: { name: string; status: "ready" | "logs" | "live"; round?: string; desc: string }[] = [
  { name: "R8 minify + resource shrink", status: "live", desc: "release builds obfuscate Kotlin + drop unused resources" },
  { name: "Certificate pinning", status: "live", desc: "supabase.co + razorpay.com domains pinned to intermediate + root CA" },
  { name: "User-installed CAs rejected", status: "live", desc: "MITM via custom CA blocked; cleartext HTTP also blocked" },
  { name: "Signature SHA-256 check", status: "ready", round: "r482", desc: "boot-time; enforce when EXPECTED_CERT_SHA256 + TAMPER_ENFORCE set" },
  { name: "DeviceIntegrityCheck (root/emu/Frida)", status: "live", round: "r470", desc: "root + emulator + debugger + Frida probes at boot" },
  { name: "Dev-mode hard block", status: "live", round: "r470", desc: "USB debug or Developer Options on release = block UI" },
  { name: "Play Integrity API + server verify", status: "live", desc: "/verify-play-integrity edge fn server-validates Google attestation" },
  { name: "Encrypted session storage", status: "live", desc: "Keystore-backed AES256/GCM EncryptedSharedPreferences" },
  { name: "Manifest hardening", status: "live", desc: "extractNativeLibs=false + allowBackup=false" },
  { name: "Install source verifier", status: "ready", round: "r843", desc: "blocks sideloaded APKs (non-Play installer) when TAMPER_ENFORCE on" },
  { name: "RE tool detector", status: "ready", round: "r843", desc: "scans for Xposed/LSPosed/Magisk-mgr/Frida/Lucky Patcher packages" },
  { name: "Integrity header on every request", status: "live", round: "r844", desc: "X-Equipseva-Integrity stamped on every Supabase call" },
  { name: "Periodic 15-min re-verify", status: "ready", round: "r845", desc: "appScope coroutine catches mid-session compromise" },
  { name: "Client header captured server-side", status: "live", round: "r846", desc: "device_integrity_checks.client_integrity_header persisted on every Play Integrity call" },
];

export default async function SecurityOverviewPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const [summaryRes, dirtyRes] = await Promise.all([
    supabase.rpc("founder_integrity_summary"),
    supabase.rpc("founder_integrity_recent_dirty"),
  ]);
  if (summaryRes.error) throw new Error(`founder_integrity_summary: ${summaryRes.error.message}`);
  if (dirtyRes.error) throw new Error(`founder_integrity_recent_dirty: ${dirtyRes.error.message}`);
  const summary = (summaryRes.data ?? []) as SummaryRow[];
  const dirty = (dirtyRes.data ?? []) as DirtyRow[];

  const dirtyCols: Column<DirtyRow>[] = [
    { key: "t", header: "When", render: (r) => <span className="text-xs tabular-nums text-[var(--color-muted)]">{new Date(r.created_at).toLocaleString()}</span> },
    { key: "n", header: "User", render: (r) => <span className="text-xs">{r.display_name}</span> },
    { key: "a", header: "Action", render: (r) => <span className="text-xs font-semibold">{r.action}</span> },
    { key: "p", header: "Google",
      render: (r) => r.pass
        ? <span className="text-xs text-[var(--color-ok)]">pass</span>
        : <span className="text-xs text-[var(--color-danger)]">FAIL</span>
    },
    { key: "d", header: "Device verdict", render: (r) => <span className="text-xs text-[var(--color-muted)]">{r.device_verdict ?? "—"}</span> },
    { key: "h", header: "Client header", render: (r) => <span className="text-xs font-mono text-[var(--color-danger)]">{r.client_header ?? "—"}</span> },
  ];

  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Security overview</h1>
        <span className="text-xs text-[var(--color-muted)]">Anti-mod layer status · Play Integrity audit · dirty events</span>
      </header>

      <section>
        <h2 className="mb-2 text-xs font-medium uppercase tracking-wider text-[var(--color-muted)]">Play Integrity summary</h2>
        <div className="grid grid-cols-1 gap-3 md:grid-cols-3">
          {summary.map((s) => (
            <div key={s.window_label} className="rounded border border-[var(--color-border)] bg-white p-3">
              <div className="text-xs font-semibold uppercase tracking-wider text-[var(--color-muted)]">{s.window_label}</div>
              <div className="mt-2 grid grid-cols-2 gap-2">
                <StatCard label="Total checks" value={formatNumber(s.total_checks)} />
                <StatCard label="Pass %" value={`${s.pass_pct}%`} />
                <StatCard label="Failed" value={formatNumber(s.fail_count)} />
                <StatCard label="Dirty header" value={formatNumber(s.dirty_header)} />
              </div>
            </div>
          ))}
        </div>
      </section>

      <section>
        <h2 className="mb-2 text-xs font-medium uppercase tracking-wider text-[var(--color-muted)]">Defense layers</h2>
        <div className="grid grid-cols-1 gap-2 md:grid-cols-2">
          {LAYERS.map((l) => (
            <div key={l.name} className="rounded border border-[var(--color-border)] bg-white p-3">
              <div className="flex items-baseline justify-between">
                <span className="text-sm font-semibold">{l.name}</span>
                <span className={
                  l.status === "live" ? "text-xs text-[var(--color-ok)] font-semibold" :
                  l.status === "ready" ? "text-xs text-[var(--color-warn)] font-semibold" :
                  "text-xs text-[var(--color-muted)]"
                }>{l.status === "live" ? "LIVE" : l.status === "ready" ? "READY" : "logs"}</span>
              </div>
              <div className="mt-1 text-xs text-[var(--color-muted)]">{l.desc}{l.round ? ` · ${l.round}` : ""}</div>
            </div>
          ))}
        </div>
      </section>

      <section>
        <h2 className="mb-2 text-xs font-medium uppercase tracking-wider text-[var(--color-muted)]">Recent dirty events (last 50)</h2>
        <DataTable columns={dirtyCols} rows={dirty} rowKey={(r) => r.id} emptyMessage="No dirty events." />
      </section>

      <section className="rounded border border-[var(--color-border)] bg-white p-3 text-xs text-[var(--color-muted)]">
        <strong>To turn enforce ON:</strong> upload AAB to Play Console → grab Play App Signing SHA-256 → add to <code>EXPECTED_CERT_SHA256</code> in CI secret → set <code>TAMPER_ENFORCE=true</code>. Re-signed / sideloaded / RE-tool-installed APKs then hard-exit before any code runs.
      </section>
    </div>
  );
}
