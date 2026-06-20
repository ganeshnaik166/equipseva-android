import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "Customer reference permission tracker — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Summary = {
  total_permissions: number;
  not_requested_count: number;
  requested_count: number;
  granted_count: number;
  denied_count: number;
  expired_count: number;
  revoked_count: number;
  expiring_30d_count: number;
  total_usage_events: number;
  usage_last_30d: number;
  pitch_deck_logo_granted: number;
  website_logo_granted: number;
  case_study_granted: number;
  press_quote_granted: number;
  video_testimonial_granted: number;
  reference_call_granted: number;
};

type Permission = {
  id: string;
  hospital_user_id: string | null;
  reference_kind: string;
  permission_status: string;
  permission_signed_by: string | null;
  permission_signed_at: string | null;
  permission_expires_at: string | null;
  scope_text: string | null;
  can_use_name: boolean;
  can_use_logo: boolean;
  can_use_metrics: boolean;
  can_use_quote: boolean;
  can_use_executive_attribution: boolean;
  notes: string | null;
  created_at: string;
  updated_at: string;
};

type UsageEvent = {
  id: string;
  permission_id: string;
  reference_kind: string | null;
  permission_status: string | null;
  usage_kind: string;
  used_at: string;
  context_summary: string | null;
  used_by: string | null;
  created_at: string;
};

type Expiring = {
  id: string;
  hospital_user_id: string | null;
  reference_kind: string;
  permission_status: string;
  permission_signed_by: string | null;
  permission_expires_at: string | null;
  days_until_expiry: number | null;
  scope_text: string | null;
};

function Card({ label, value, sub, tone }: { label: string; value: string; sub?: string; tone?: "ok" | "warn" | "danger" }) {
  const t = tone === "ok" ? "text-[var(--color-ok)]" : tone === "warn" ? "text-[var(--color-warn)]" : tone === "danger" ? "text-[var(--color-danger)]" : "";
  return (
    <div className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-4">
      <div className="text-xs uppercase tracking-wider text-[var(--color-muted)]">{label}</div>
      <div className={`mt-1 text-2xl font-semibold tabular-nums ${t}`}>{value}</div>
      {sub ? <div className="text-xs text-[var(--color-muted)]">{sub}</div> : null}
    </div>
  );
}

function statusTone(s: string): "ok" | "warn" | "danger" | undefined {
  if (s === "granted") return "ok";
  if (s === "requested" || s === "not_requested") return "warn";
  if (s === "denied" || s === "expired" || s === "revoked") return "danger";
  return undefined;
}

function StatusPill({ s }: { s: string }) {
  const t = statusTone(s);
  const cls = t === "ok" ? "text-[var(--color-ok)] border-[var(--color-ok)]" : t === "warn" ? "text-[var(--color-warn)] border-[var(--color-warn)]" : t === "danger" ? "text-[var(--color-danger)] border-[var(--color-danger)]" : "text-[var(--color-muted)] border-[var(--color-border)]";
  return <span className={`inline-block rounded-full border px-2 py-0.5 text-xs ${cls}`}>{s}</span>;
}

function KindPill({ k }: { k: string }) {
  return <span className="inline-block rounded-full border border-[var(--color-border)] px-2 py-0.5 text-xs text-[var(--color-muted)]">{k}</span>;
}

function fmtDate(s: string | null): string {
  if (!s) return "—";
  try { return new Date(s).toISOString().slice(0, 10); } catch { return "—"; }
}

function fmtScopes(p: Permission): string {
  const flags: string[] = [];
  if (p.can_use_name) flags.push("name");
  if (p.can_use_logo) flags.push("logo");
  if (p.can_use_metrics) flags.push("metrics");
  if (p.can_use_quote) flags.push("quote");
  if (p.can_use_executive_attribution) flags.push("exec");
  return flags.length === 0 ? "—" : flags.join(" · ");
}

export default async function FounderCustomerReferencePermissionTrackerPage() {
  await requireFounder();
  const sb = await getSupabaseServerClient();
  const [sRes, pRes, uRes, eRes] = await Promise.all([
    sb.rpc("founder_reference_permission_summary"),
    sb.rpc("founder_reference_permissions_recent"),
    sb.rpc("founder_reference_usage_events_recent"),
    sb.rpc("founder_reference_permissions_expiring_soon"),
  ]);
  if (sRes.error) throw new Error(`ref_summary: ${sRes.error.message}`);
  if (pRes.error) throw new Error(`ref_perms: ${pRes.error.message}`);
  if (uRes.error) throw new Error(`ref_usage: ${uRes.error.message}`);
  if (eRes.error) throw new Error(`ref_expiring: ${eRes.error.message}`);
  const s = (sRes.data?.[0] ?? null) as Summary | null;
  const perms = (pRes.data ?? []) as Permission[];
  const usage = (uRes.data ?? []) as UsageEvent[];
  const expiring = (eRes.data ?? []) as Expiring[];
  const expiringCount = s?.expiring_30d_count ?? 0;

  return (
    <main className="mx-auto max-w-7xl px-4 py-6 sm:px-6 lg:px-8">
      <header className="mb-6">
        <div className="text-xs uppercase tracking-wider text-[var(--color-muted)]">r1446 · founder console</div>
        <h1 className="mt-1 text-2xl font-semibold">Customer reference permission tracker</h1>
        <p className="mt-1 text-sm text-[var(--color-muted)]">
          Track explicit hospital permissions to use their name, logo, metrics, and quotes across pitch deck, website, press, and sales. Prevent unauthorized usage; renew before expiry.
        </p>
      </header>

      {expiringCount > 0 ? (
        <section className="mb-6 rounded-lg border border-[var(--color-warn)] bg-[var(--color-surface)] p-4">
          <div className="text-xs uppercase tracking-wider text-[var(--color-warn)]">Expiring soon</div>
          <div className="mt-1 text-base font-medium">{formatNumber(expiringCount)} permission{expiringCount === 1 ? "" : "s"} expire in the next 30 days. Renew before usage stops.</div>
        </section>
      ) : null}

      <section className="mb-8">
        <h2 className="mb-3 text-sm font-semibold uppercase tracking-wider text-[var(--color-muted)]">Permission KPIs</h2>
        <div className="grid grid-cols-2 gap-3 sm:grid-cols-3 lg:grid-cols-4">
          <Card label="Total permissions" value={formatNumber(s?.total_permissions ?? 0)} />
          <Card label="Not requested" value={formatNumber(s?.not_requested_count ?? 0)} tone="warn" />
          <Card label="Requested" value={formatNumber(s?.requested_count ?? 0)} tone="warn" />
          <Card label="Granted" value={formatNumber(s?.granted_count ?? 0)} tone="ok" />
          <Card label="Denied" value={formatNumber(s?.denied_count ?? 0)} tone="danger" />
          <Card label="Expired" value={formatNumber(s?.expired_count ?? 0)} tone="danger" />
          <Card label="Revoked" value={formatNumber(s?.revoked_count ?? 0)} tone="danger" />
          <Card label="Expiring 30d" value={formatNumber(s?.expiring_30d_count ?? 0)} tone="warn" />
          <Card label="Usage events" value={formatNumber(s?.total_usage_events ?? 0)} />
          <Card label="Usage 30d" value={formatNumber(s?.usage_last_30d ?? 0)} sub="recent reuse" />
          <Card label="Pitch deck logo" value={formatNumber(s?.pitch_deck_logo_granted ?? 0)} tone="ok" />
          <Card label="Website logo" value={formatNumber(s?.website_logo_granted ?? 0)} tone="ok" />
          <Card label="Case study" value={formatNumber(s?.case_study_granted ?? 0)} tone="ok" />
          <Card label="Press quote" value={formatNumber(s?.press_quote_granted ?? 0)} tone="ok" />
          <Card label="Video testimonial" value={formatNumber(s?.video_testimonial_granted ?? 0)} tone="ok" />
          <Card label="Reference call" value={formatNumber(s?.reference_call_granted ?? 0)} tone="ok" />
        </div>
      </section>

      <section className="mb-8">
        <h2 className="mb-3 text-sm font-semibold uppercase tracking-wider text-[var(--color-muted)]">Expiring in next 30 days</h2>
        <div className="overflow-x-auto rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)]">
          <table className="min-w-full text-sm">
            <thead className="border-b border-[var(--color-border)] text-left text-xs uppercase tracking-wider text-[var(--color-muted)]">
              <tr>
                <th className="px-3 py-2">Kind</th>
                <th className="px-3 py-2">Signed by</th>
                <th className="px-3 py-2">Expires</th>
                <th className="px-3 py-2">Days left</th>
                <th className="px-3 py-2">Scope</th>
              </tr>
            </thead>
            <tbody>
              {expiring.length === 0 ? (
                <tr><td colSpan={5} className="px-3 py-6 text-center text-[var(--color-muted)]">No permissions expiring in next 30 days.</td></tr>
              ) : expiring.map((e) => (
                <tr key={e.id} className="border-b border-[var(--color-border)]/40 last:border-0">
                  <td className="px-3 py-2"><KindPill k={e.reference_kind} /></td>
                  <td className="px-3 py-2">{e.permission_signed_by ?? "—"}</td>
                  <td className="px-3 py-2 tabular-nums">{fmtDate(e.permission_expires_at)}</td>
                  <td className="px-3 py-2 tabular-nums">{e.days_until_expiry ?? "—"}</td>
                  <td className="px-3 py-2 text-[var(--color-muted)]">{e.scope_text ?? "—"}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </section>

      <section className="mb-8">
        <h2 className="mb-3 text-sm font-semibold uppercase tracking-wider text-[var(--color-muted)]">Permission ledger (50 most recent)</h2>
        <div className="overflow-x-auto rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)]">
          <table className="min-w-full text-sm">
            <thead className="border-b border-[var(--color-border)] text-left text-xs uppercase tracking-wider text-[var(--color-muted)]">
              <tr>
                <th className="px-3 py-2">Kind</th>
                <th className="px-3 py-2">Status</th>
                <th className="px-3 py-2">Signed by</th>
                <th className="px-3 py-2">Signed</th>
                <th className="px-3 py-2">Expires</th>
                <th className="px-3 py-2">Scope flags</th>
                <th className="px-3 py-2">Scope text</th>
                <th className="px-3 py-2">Updated</th>
              </tr>
            </thead>
            <tbody>
              {perms.length === 0 ? (
                <tr><td colSpan={8} className="px-3 py-6 text-center text-[var(--color-muted)]">No permissions registered yet.</td></tr>
              ) : perms.map((p) => (
                <tr key={p.id} className="border-b border-[var(--color-border)]/40 last:border-0">
                  <td className="px-3 py-2"><KindPill k={p.reference_kind} /></td>
                  <td className="px-3 py-2"><StatusPill s={p.permission_status} /></td>
                  <td className="px-3 py-2">{p.permission_signed_by ?? "—"}</td>
                  <td className="px-3 py-2 tabular-nums">{fmtDate(p.permission_signed_at)}</td>
                  <td className="px-3 py-2 tabular-nums">{fmtDate(p.permission_expires_at)}</td>
                  <td className="px-3 py-2 text-[var(--color-muted)]">{fmtScopes(p)}</td>
                  <td className="px-3 py-2 text-[var(--color-muted)]">{p.scope_text ?? "—"}</td>
                  <td className="px-3 py-2 tabular-nums">{fmtDate(p.updated_at)}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </section>

      <section className="mb-8">
        <h2 className="mb-3 text-sm font-semibold uppercase tracking-wider text-[var(--color-muted)]">Usage event feed (50 most recent)</h2>
        <div className="overflow-x-auto rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)]">
          <table className="min-w-full text-sm">
            <thead className="border-b border-[var(--color-border)] text-left text-xs uppercase tracking-wider text-[var(--color-muted)]">
              <tr>
                <th className="px-3 py-2">Usage kind</th>
                <th className="px-3 py-2">Linked permission</th>
                <th className="px-3 py-2">Perm status</th>
                <th className="px-3 py-2">Used at</th>
                <th className="px-3 py-2">Context</th>
              </tr>
            </thead>
            <tbody>
              {usage.length === 0 ? (
                <tr><td colSpan={5} className="px-3 py-6 text-center text-[var(--color-muted)]">No usage events recorded yet.</td></tr>
              ) : usage.map((e) => (
                <tr key={e.id} className="border-b border-[var(--color-border)]/40 last:border-0">
                  <td className="px-3 py-2"><KindPill k={e.usage_kind} /></td>
                  <td className="px-3 py-2">{e.reference_kind ? <KindPill k={e.reference_kind} /> : "—"}</td>
                  <td className="px-3 py-2">{e.permission_status ? <StatusPill s={e.permission_status} /> : "—"}</td>
                  <td className="px-3 py-2 tabular-nums">{fmtDate(e.used_at)}</td>
                  <td className="px-3 py-2 text-[var(--color-muted)]">{e.context_summary ?? "—"}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </section>

      <footer className="mt-10 border-t border-[var(--color-border)] pt-4 text-xs text-[var(--color-muted)]">
        r1446 · founder-only · is_founder() gate on all 7 RPCs · register {"->"} requested {"->"} granted {"->"} (expired | revoked) · usage events guarded against ungranted permissions
      </footer>
    </main>
  );
}
