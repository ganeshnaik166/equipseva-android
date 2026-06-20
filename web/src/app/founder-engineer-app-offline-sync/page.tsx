import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "Engineer app offline sync — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Summary = {
  total_events_30d: number;
  total_events_lifetime: number;
  pending_count: number;
  applied_count: number;
  conflict_count: number;
  rejected_count: number;
  superseded_count: number;
  conflicts_unresolved: number;
  sync_lag_p50_seconds: number;
  sync_lag_p95_seconds: number;
  bytes_transferred_30d: number;
  active_engineers_30d: number;
  sessions_30d: number;
  top_event_kind: string | null;
  top_event_kind_count: number;
  top_network_kind: string | null;
  generated_at: string;
};

type EventRow = {
  id: string;
  engineer_user_id: string;
  client_event_uuid: string;
  event_kind: string;
  sync_status: string;
  conflict_reason: string | null;
  captured_at_client: string;
  received_at_server: string;
  applied_at: string | null;
  lag_seconds: number;
};

type ConflictRow = {
  id: string;
  offline_event_id: string;
  event_kind: string | null;
  engineer_user_id: string | null;
  conflict_kind: string;
  resolution_kind: string;
  resolved_at: string | null;
  created_at: string;
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
  if (s === "applied") return "ok";
  if (s === "pending" || s === "superseded") return "warn";
  if (s === "conflict" || s === "rejected") return "danger";
  return undefined;
}

function resolutionTone(r: string): "ok" | "warn" | "danger" | undefined {
  if (r === "client_wins" || r === "server_wins" || r === "auto_reconciled") return "ok";
  if (r === "manual_review") return "warn";
  if (r === "unresolved") return "danger";
  return undefined;
}

export default async function FounderEngineerAppOfflineSyncPage() {
  await requireFounder();
  const sb = await getSupabaseServerClient();
  const [sRes, eRes, cRes] = await Promise.all([
    sb.rpc("founder_engineer_app_offline_sync_summary"),
    sb.rpc("founder_engineer_app_offline_events_recent", { p_limit: 100 }),
    sb.rpc("founder_engineer_app_offline_conflicts_recent", { p_limit: 50 }),
  ]);
  if (sRes.error) throw new Error(`offline_sync_summary: ${sRes.error.message}`);
  if (eRes.error) throw new Error(`offline_events_recent: ${eRes.error.message}`);
  if (cRes.error) throw new Error(`offline_conflicts_recent: ${cRes.error.message}`);
  const s = (sRes.data?.[0] ?? null) as Summary | null;
  const events = (eRes.data ?? []) as EventRow[];
  const conflicts = (cRes.data ?? []) as ConflictRow[];

  const eventKindCounts: Record<string, number> = {};
  for (const e of events) eventKindCounts[e.event_kind] = (eventKindCounts[e.event_kind] ?? 0) + 1;
  const maxKindCount = Math.max(1, ...Object.values(eventKindCounts));

  return (
    <div className="mx-auto max-w-7xl space-y-6 p-6">
      <header>
        <h1 className="text-2xl font-semibold">Engineer app offline sync queue {"★★★★"} v0.6 Phase 3</h1>
        <p className="mt-1 text-sm text-[var(--color-muted)]">
          Engineer Android app captures events offline (rural BMC sites, 2G/satellite). Client UUIDs dedupe on replay. Server applies, rejects, or flags conflicts. Founder resolves disputes manually or auto-reconciles. p50/p95 sync-lag tracked; 90d retention on applied events.
        </p>
      </header>

      {s ? (
        <section className="grid grid-cols-2 gap-3 md:grid-cols-4 lg:grid-cols-6">
          <Card label="Events 30d" value={formatNumber(s.total_events_30d)} sub={`${formatNumber(s.total_events_lifetime)} lifetime`} />
          <Card label="Pending" value={formatNumber(s.pending_count)} tone={s.pending_count > 100 ? "warn" : undefined} />
          <Card label="Applied" value={formatNumber(s.applied_count)} tone="ok" />
          <Card label="Conflicts" value={formatNumber(s.conflict_count)} tone={s.conflict_count > 0 ? "warn" : undefined} />
          <Card label="Rejected" value={formatNumber(s.rejected_count)} tone={s.rejected_count > 0 ? "danger" : undefined} />
          <Card label="Superseded" value={formatNumber(s.superseded_count)} />
          <Card label="Unresolved conflicts" value={formatNumber(s.conflicts_unresolved)} tone={s.conflicts_unresolved > 0 ? "danger" : "ok"} />
          <Card label="Sync lag p50" value={`${formatNumber(s.sync_lag_p50_seconds)}s`} />
          <Card label="Sync lag p95" value={`${formatNumber(s.sync_lag_p95_seconds)}s`} tone={s.sync_lag_p95_seconds > 600 ? "warn" : undefined} />
          <Card label="Bytes 30d" value={formatNumber(s.bytes_transferred_30d)} sub="payload size" />
          <Card label="Active engineers 30d" value={formatNumber(s.active_engineers_30d)} />
          <Card label="Sync sessions 30d" value={formatNumber(s.sessions_30d)} />
          <Card label="Top event kind" value={s.top_event_kind ?? "—"} sub={`${formatNumber(s.top_event_kind_count)} events`} />
          <Card label="Top network" value={s.top_network_kind ?? "—"} />
          <Card label="Lifetime events" value={formatNumber(s.total_events_lifetime)} />
          <Card label="Generated" value={new Date(s.generated_at).toLocaleTimeString("en-IN")} />
        </section>
      ) : <p className="text-sm text-[var(--color-muted)]">No data.</p>}

      <section>
        <h2 className="mb-3 text-sm font-semibold uppercase tracking-wider text-[var(--color-muted)]">Event kind breakdown (last 100)</h2>
        <div className="space-y-2 rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-4">
          {Object.entries(eventKindCounts).sort((a, b) => b[1] - a[1]).map(([k, n]) => (
            <div key={k} className="flex items-center gap-3">
              <div className="w-44 text-xs font-mono">{k}</div>
              <div className="flex-1 h-4 bg-[var(--color-border)] rounded overflow-hidden">
                <div className="h-full bg-[var(--color-ok)]" style={{ width: `${(n / maxKindCount) * 100}%` }} />
              </div>
              <div className="w-12 text-right text-xs tabular-nums">{formatNumber(n)}</div>
            </div>
          ))}
          {Object.keys(eventKindCounts).length === 0 ? <p className="text-xs text-[var(--color-muted)]">No events yet.</p> : null}
        </div>
      </section>

      <section>
        <h2 className="mb-3 text-sm font-semibold uppercase tracking-wider text-[var(--color-muted)]">Recent events ({events.length})</h2>
        <div className="overflow-x-auto">
          <table className="w-full text-sm">
            <thead>
              <tr className="border-b border-[var(--color-border)] text-left text-xs uppercase tracking-wider text-[var(--color-muted)]">
                <th className="py-2 pr-3">Received</th>
                <th className="py-2 pr-3">Engineer</th>
                <th className="py-2 pr-3">Event kind</th>
                <th className="py-2 pr-3">Client UUID</th>
                <th className="py-2 pr-3">Status</th>
                <th className="py-2 pr-3 text-right">Lag (s)</th>
                <th className="py-2">Conflict reason</th>
              </tr>
            </thead>
            <tbody>
              {events.map((e) => {
                const t = statusTone(e.sync_status);
                return (
                  <tr key={e.id} className="border-b border-[var(--color-border)]">
                    <td className="py-2 pr-3 text-xs font-mono text-[var(--color-muted)]">{new Date(e.received_at_server).toLocaleString("en-IN")}</td>
                    <td className="py-2 pr-3 text-xs font-mono">{e.engineer_user_id.slice(0, 8)}</td>
                    <td className="py-2 pr-3 text-xs">{e.event_kind}</td>
                    <td className="py-2 pr-3 text-xs font-mono text-[var(--color-muted)]">{e.client_event_uuid.slice(0, 10)}</td>
                    <td className={`py-2 pr-3 text-xs ${t === "ok" ? "text-[var(--color-ok)]" : t === "warn" ? "text-[var(--color-warn)]" : t === "danger" ? "text-[var(--color-danger)]" : ""}`}>{e.sync_status}</td>
                    <td className={`py-2 pr-3 text-xs text-right tabular-nums ${e.lag_seconds > 600 ? "text-[var(--color-warn)]" : ""}`}>{formatNumber(e.lag_seconds)}</td>
                    <td className="py-2 text-xs text-[var(--color-muted)]">{e.conflict_reason ?? "—"}</td>
                  </tr>
                );
              })}
            </tbody>
          </table>
        </div>
      </section>

      <section>
        <h2 className="mb-3 text-sm font-semibold uppercase tracking-wider text-[var(--color-muted)]">Conflicts ({conflicts.length})</h2>
        <div className="overflow-x-auto">
          <table className="w-full text-sm">
            <thead>
              <tr className="border-b border-[var(--color-border)] text-left text-xs uppercase tracking-wider text-[var(--color-muted)]">
                <th className="py-2 pr-3">When</th>
                <th className="py-2 pr-3">Event kind</th>
                <th className="py-2 pr-3">Engineer</th>
                <th className="py-2 pr-3">Conflict kind</th>
                <th className="py-2 pr-3">Resolution</th>
                <th className="py-2">Resolved</th>
              </tr>
            </thead>
            <tbody>
              {conflicts.map((c) => {
                const t = resolutionTone(c.resolution_kind);
                return (
                  <tr key={c.id} className="border-b border-[var(--color-border)]">
                    <td className="py-2 pr-3 text-xs font-mono text-[var(--color-muted)]">{new Date(c.created_at).toLocaleString("en-IN")}</td>
                    <td className="py-2 pr-3 text-xs">{c.event_kind ?? "—"}</td>
                    <td className="py-2 pr-3 text-xs font-mono">{c.engineer_user_id ? c.engineer_user_id.slice(0, 8) : "—"}</td>
                    <td className="py-2 pr-3 text-xs">{c.conflict_kind}</td>
                    <td className={`py-2 pr-3 text-xs ${t === "ok" ? "text-[var(--color-ok)]" : t === "warn" ? "text-[var(--color-warn)]" : t === "danger" ? "text-[var(--color-danger)]" : ""}`}>{c.resolution_kind}</td>
                    <td className="py-2 text-xs text-[var(--color-muted)]">{c.resolved_at ? new Date(c.resolved_at).toLocaleString("en-IN") : "—"}</td>
                  </tr>
                );
              })}
              {conflicts.length === 0 ? (
                <tr><td colSpan={6} className="py-3 text-xs text-[var(--color-muted)]">No conflicts logged.</td></tr>
              ) : null}
            </tbody>
          </table>
        </div>
      </section>

      <p className="text-xs text-[var(--color-muted)]">
        Engineer client: <code>engineer_app_offline_submit_event(client_event_uuid, event_kind, payload, captured_at_client)</code> · ON CONFLICT dedupes via (engineer_user_id, client_event_uuid). Sessions opened via <code>engineer_app_offline_start_sync_session</code>, closed via <code>engineer_app_offline_close_sync_session</code> with totals. Founder resolves conflicts via <code>log_founder_engineer_app_resolve_conflict</code>. Cron purges applied events older than 90 days via <code>engineer_app_offline_sync_purge_old_applied</code>.
      </p>
    </div>
  );
}
