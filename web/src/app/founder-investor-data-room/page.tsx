import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "Investor data room — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Summary = {
  total_folders: number;
  total_documents: number;
  active_documents: number;
  restricted_doc_count: number;
  total_grants: number;
  active_grants: number;
  expired_grants: number;
  exhausted_grants: number;
  revoked_grants: number;
  total_views_lifetime: number;
  views_last_30d: number;
  views_last_7d: number;
  blocked_attempts_30d: number;
  most_viewed_doc_label: string | null;
  most_viewed_doc_count: number;
  top_investor_firm: string | null;
  top_investor_views: number;
  generated_at: string;
};

type Grant = {
  id: string;
  investor_firm_name: string;
  investor_partner_name: string | null;
  status: string;
  view_count_total: number;
  max_views_total: number;
  expires_at: string;
  granted_at: string;
  days_until_expiry: number | null;
};

type LogEntry = {
  id: string;
  grant_investor_firm: string | null;
  document_label: string | null;
  action_kind: string;
  outcome: string;
  accessed_at: string;
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

function outcomeTone(o: string): "ok" | "warn" | "danger" | undefined {
  if (o === "ok") return "ok";
  if (o === "expired" || o === "exhausted") return "warn";
  if (o === "revoked" || o === "not_found" || o === "sensitivity_blocked") return "danger";
  return undefined;
}

export default async function FounderInvestorDataRoomPage() {
  await requireFounder();
  const sb = await getSupabaseServerClient();
  const [sRes, gRes, lRes] = await Promise.all([
    sb.rpc("founder_investor_data_room_summary"),
    sb.rpc("founder_investor_data_room_grants_recent", { p_limit: 50 }),
    sb.rpc("founder_investor_data_room_access_log_recent", { p_limit: 100 }),
  ]);
  if (sRes.error) throw new Error(`dr_summary: ${sRes.error.message}`);
  if (gRes.error) throw new Error(`dr_grants_recent: ${gRes.error.message}`);
  if (lRes.error) throw new Error(`dr_log_recent: ${lRes.error.message}`);
  const s = (sRes.data?.[0] ?? null) as Summary | null;
  const grants = (gRes.data ?? []) as Grant[];
  const logs = (lRes.data ?? []) as LogEntry[];

  return (
    <div className="mx-auto max-w-7xl space-y-6 p-6">
      <header>
        <h1 className="text-2xl font-semibold">Investor data room ★★★ v0.6 Phase 8 SHIPPED EARLY</h1>
        <p className="mt-1 text-sm text-[var(--color-muted)]">
          Token-gated investor diligence vault · 9-folder taxonomy (financials/legal/product/team/customers/traction/compliance/operations/risks) · 5 sensitivity bands (public/low/medium/high/restricted) · per-investor grant with max-views + expiry + sensitivity allowlist · every view audit-logged. Public surface: /share/data-room/[token].
        </p>
      </header>

      {s ? (
        <section className="grid grid-cols-2 gap-3 md:grid-cols-4 lg:grid-cols-6">
          <Card label="Folders" value={formatNumber(s.total_folders)} />
          <Card label="Documents" value={formatNumber(s.total_documents)} sub={`${s.active_documents} active`} />
          <Card label="Restricted docs" value={formatNumber(s.restricted_doc_count)} tone={s.restricted_doc_count > 0 ? "warn" : undefined} />
          <Card label="Total grants" value={formatNumber(s.total_grants)} />
          <Card label="Active grants" value={formatNumber(s.active_grants)} tone="ok" />
          <Card label="Expired grants" value={formatNumber(s.expired_grants)} />
          <Card label="Exhausted grants" value={formatNumber(s.exhausted_grants)} />
          <Card label="Revoked grants" value={formatNumber(s.revoked_grants)} tone={s.revoked_grants > 0 ? "danger" : undefined} />
          <Card label="Total views lifetime" value={formatNumber(s.total_views_lifetime)} />
          <Card label="Views 30d" value={formatNumber(s.views_last_30d)} />
          <Card label="Views 7d" value={formatNumber(s.views_last_7d)} />
          <Card label="Blocked attempts 30d" value={formatNumber(s.blocked_attempts_30d)} tone={s.blocked_attempts_30d > 0 ? "danger" : "ok"} />
          <Card label="Most viewed doc" value={s.most_viewed_doc_label ?? "—"} sub={`${s.most_viewed_doc_count} views`} />
          <Card label="Top investor firm" value={s.top_investor_firm ?? "—"} sub={`${s.top_investor_views} views`} />
        </section>
      ) : <p className="text-sm text-[var(--color-muted)]">No data.</p>}

      <section>
        <h2 className="mb-3 text-sm font-semibold uppercase tracking-wider text-[var(--color-muted)]">Recent grants ({grants.length})</h2>
        <div className="overflow-x-auto">
          <table className="w-full text-sm">
            <thead>
              <tr className="border-b border-[var(--color-border)] text-left text-xs uppercase tracking-wider text-[var(--color-muted)]">
                <th className="py-2 pr-3">Investor firm</th>
                <th className="py-2 pr-3">Partner</th>
                <th className="py-2 pr-3">Status</th>
                <th className="py-2 pr-3 text-right">Views</th>
                <th className="py-2 pr-3 text-right">Days until expiry</th>
                <th className="py-2">Granted</th>
              </tr>
            </thead>
            <tbody>
              {grants.map((g) => (
                <tr key={g.id} className="border-b border-[var(--color-border)]">
                  <td className="py-2 pr-3 text-xs font-medium">{g.investor_firm_name}</td>
                  <td className="py-2 pr-3 text-xs text-[var(--color-muted)]">{g.investor_partner_name ?? "—"}</td>
                  <td className={`py-2 pr-3 text-xs ${g.status === "active" ? "text-[var(--color-ok)]" : g.status === "revoked" ? "text-[var(--color-danger)]" : "text-[var(--color-warn)]"}`}>{g.status}</td>
                  <td className="py-2 pr-3 text-xs text-right tabular-nums">{formatNumber(g.view_count_total)}/{formatNumber(g.max_views_total)}</td>
                  <td className={`py-2 pr-3 text-xs text-right tabular-nums ${g.days_until_expiry !== null && g.days_until_expiry < 7 ? "text-[var(--color-danger)] font-semibold" : ""}`}>{g.days_until_expiry !== null ? `${g.days_until_expiry}d` : "—"}</td>
                  <td className="py-2 text-xs text-[var(--color-muted)]">{new Date(g.granted_at).toLocaleDateString("en-IN")}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </section>

      <section>
        <h2 className="mb-3 text-sm font-semibold uppercase tracking-wider text-[var(--color-muted)]">Access log ({logs.length})</h2>
        <div className="overflow-x-auto">
          <table className="w-full text-sm">
            <thead>
              <tr className="border-b border-[var(--color-border)] text-left text-xs uppercase tracking-wider text-[var(--color-muted)]">
                <th className="py-2 pr-3">When</th>
                <th className="py-2 pr-3">Investor firm</th>
                <th className="py-2 pr-3">Doc</th>
                <th className="py-2 pr-3">Action</th>
                <th className="py-2">Outcome</th>
              </tr>
            </thead>
            <tbody>
              {logs.map((l) => (
                <tr key={l.id} className="border-b border-[var(--color-border)]">
                  <td className="py-2 pr-3 text-xs font-mono text-[var(--color-muted)]">{new Date(l.accessed_at).toLocaleString("en-IN")}</td>
                  <td className="py-2 pr-3 text-xs">{l.grant_investor_firm ?? "—"}</td>
                  <td className="py-2 pr-3 text-xs text-[var(--color-muted)]">{l.document_label ?? "—"}</td>
                  <td className="py-2 pr-3 text-xs">{l.action_kind}</td>
                  <td className={`py-2 text-xs ${outcomeTone(l.outcome) === "ok" ? "text-[var(--color-ok)]" : outcomeTone(l.outcome) === "warn" ? "text-[var(--color-warn)]" : outcomeTone(l.outcome) === "danger" ? "text-[var(--color-danger)]" : ""}`}>{l.outcome}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </section>

      <p className="text-xs text-[var(--color-muted)]">
        Public surface: <code>/share/data-room/[token]</code> (anon-callable SECDEF RPC <code>investor_data_room_view(token_hash, document_id)</code>). 4 outcome states: ok / expired / exhausted / revoked / sensitivity_blocked / not_found. Every call logged.
      </p>
    </div>
  );
}
