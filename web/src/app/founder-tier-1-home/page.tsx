import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { formatNumber } from "@/lib/format";
import Link from "next/link";

export const metadata = { title: "Founder Tier-1 Home · EquipSeva" };
export const dynamic = "force-dynamic";

type Metadata = {
  last_action_at: string | null;
  total_open_incidents: number;
  total_critical_alerts: number;
  cron_failure_rate_24h_pct: number;
  generated_at: string;
};

async function safeCall<T>(fn: () => Promise<T>): Promise<T | null> {
  try {
    return await fn();
  } catch {
    return null;
  }
}

export default async function FounderTier1HomePage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();

  const [metaRes, actionsRes, incidentsRes, cronRes, pulseRes, dpdpRes, payoutsRes] = await Promise.all([
    safeCall(async () => {
      const { data, error } = await supabase.rpc("founder_tier_1_home_metadata");
      if (error) throw error;
      return (data as Metadata[] | null)?.[0] ?? null;
    }),
    safeCall(async () => {
      const { data, error } = await supabase.rpc("founder_action_center", { p_limit: 20 });
      if (error) throw error;
      return data as Array<Record<string, unknown>> | null;
    }),
    safeCall(async () => {
      const { data, error } = await supabase.rpc("founder_incidents_recent", { p_limit: 20 });
      if (error) throw error;
      return data as Array<Record<string, unknown>> | null;
    }),
    safeCall(async () => {
      const { data, error } = await supabase.rpc("founder_cron_status_summary");
      if (error) throw error;
      return data as Array<Record<string, unknown>> | null;
    }),
    safeCall(async () => {
      const { data, error } = await supabase.rpc("founder_morning_pulse_v2");
      if (error) throw error;
      return data as Array<Record<string, unknown>> | null;
    }),
    safeCall(async () => {
      const { data, error } = await supabase.rpc("founder_dpdp_routing_summary");
      if (error) throw error;
      return data as Array<Record<string, unknown>> | null;
    }),
    safeCall(async () => {
      const { data, error } = await supabase.rpc("founder_payouts_snapshot_summary");
      if (error) throw error;
      return data as Array<Record<string, unknown>> | null;
    }),
  ]);

  const meta = metaRes;
  const actions = (actionsRes ?? []).slice(0, 5);
  const incidents = (incidentsRes ?? []).slice(0, 5);
  const cron = cronRes ?? [];
  const pulse = pulseRes?.[0] as Record<string, unknown> | undefined;
  const dpdp = dpdpRes?.[0] as Record<string, unknown> | undefined;
  const payouts = payoutsRes?.[0] as Record<string, unknown> | undefined;

  const fmtTs = (ts: string | null | undefined) => {
    if (!ts) return "—";
    try { return new Date(ts).toLocaleString("en-IN", { dateStyle: "medium", timeStyle: "short" }); }
    catch { return ts; }
  };

  return (
    <main className="mx-auto max-w-7xl px-4 py-6 space-y-6">
      <header className="flex flex-wrap items-end justify-between gap-2 border-b border-[var(--color-border)] pb-3">
        <div>
          <h1 className="text-2xl font-semibold">Founder Tier-1 Home</h1>
          <p className="text-sm text-[var(--color-muted)]">Composite view: actions, incidents, cron, DPDP, payouts.</p>
        </div>
        <div className="text-xs text-[var(--color-muted)]">
          Generated {fmtTs(meta?.generated_at)}
        </div>
      </header>

      <section>
        <h2 className="mb-2 text-sm font-semibold text-[var(--color-muted)]">Headline numbers</h2>
        <div className="grid grid-cols-2 gap-3 md:grid-cols-4">
          <div className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-4">
            <div className="text-xs text-[var(--color-muted)]">Last action</div>
            <div className="mt-1 text-lg font-semibold">{fmtTs(meta?.last_action_at ?? null)}</div>
          </div>
          <div className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-4">
            <div className="text-xs text-[var(--color-muted)]">Open incidents (30d)</div>
            <div className="mt-1 text-2xl font-semibold">{formatNumber(meta?.total_open_incidents ?? 0)}</div>
          </div>
          <div className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-4">
            <div className="text-xs text-[var(--color-muted)]">Critical alerts</div>
            <div className={`mt-1 text-2xl font-semibold ${(meta?.total_critical_alerts ?? 0) > 0 ? "text-[var(--color-danger)]" : ""}`}>
              {formatNumber(meta?.total_critical_alerts ?? 0)}
            </div>
          </div>
          <div className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-4">
            <div className="text-xs text-[var(--color-muted)]">Cron fail rate 24h</div>
            <div className={`mt-1 text-2xl font-semibold ${(meta?.cron_failure_rate_24h_pct ?? 0) > 5 ? "text-[var(--color-warn)]" : "text-[var(--color-ok)]"}`}>
              {meta ? `${meta.cron_failure_rate_24h_pct}%` : "—"}
            </div>
          </div>
        </div>
      </section>

      <section>
        <div className="mb-2 flex items-center justify-between">
          <h2 className="text-sm font-semibold text-[var(--color-muted)]">Top priority actions</h2>
          <Link href="/founder-action-center" className="text-xs text-[var(--color-accent)]">View all →</Link>
        </div>
        <div className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] overflow-hidden">
          {actionsRes === null ? (
            <div className="p-4 text-sm text-[var(--color-muted)]">Not available.</div>
          ) : actions.length === 0 ? (
            <div className="p-4 text-sm text-[var(--color-muted)]">No open priority actions.</div>
          ) : (
            <ul className="divide-y divide-[var(--color-border)]">
              {actions.map((a, i) => (
                <li key={i} className="flex items-start justify-between gap-3 p-3 text-sm">
                  <div className="min-w-0 flex-1">
                    <div className="truncate font-medium">{String(a.title ?? a.action_type ?? "action")}</div>
                    <div className="truncate text-xs text-[var(--color-muted)]">{String(a.summary ?? a.description ?? "")}</div>
                  </div>
                  <div className="shrink-0 text-xs text-[var(--color-muted)]">{String(a.priority ?? a.severity ?? "")}</div>
                </li>
              ))}
            </ul>
          )}
        </div>
      </section>

      <section>
        <div className="mb-2 flex items-center justify-between">
          <h2 className="text-sm font-semibold text-[var(--color-muted)]">Open incidents</h2>
          <Link href="/founder-incidents-board" className="text-xs text-[var(--color-accent)]">View all →</Link>
        </div>
        <div className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] overflow-hidden">
          {incidentsRes === null ? (
            <div className="p-4 text-sm text-[var(--color-muted)]">Not available.</div>
          ) : incidents.length === 0 ? (
            <div className="p-4 text-sm text-[var(--color-muted)]">No open incidents.</div>
          ) : (
            <ul className="divide-y divide-[var(--color-border)]">
              {incidents.map((inc, i) => (
                <li key={i} className="flex items-start justify-between gap-3 p-3 text-sm">
                  <div className="min-w-0 flex-1">
                    <div className="truncate font-medium">{String(inc.title ?? inc.incident_kind ?? "incident")}</div>
                    <div className="truncate text-xs text-[var(--color-muted)]">{fmtTs(String(inc.created_at ?? ""))}</div>
                  </div>
                  <div className={`shrink-0 text-xs ${String(inc.severity) === "critical" ? "text-[var(--color-danger)]" : "text-[var(--color-muted)]"}`}>
                    {String(inc.severity ?? "")}
                  </div>
                </li>
              ))}
            </ul>
          )}
        </div>
      </section>

      <section>
        <h2 className="mb-2 text-sm font-semibold text-[var(--color-muted)]">Cron health</h2>
        {cronRes === null ? (
          <div className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-4 text-sm text-[var(--color-muted)]">Not available.</div>
        ) : (
          <div className="grid grid-cols-1 gap-3 md:grid-cols-3">
            {cron.slice(0, 3).map((c, i) => (
              <div key={i} className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-4">
                <div className="text-xs text-[var(--color-muted)]">{String(c.jobname ?? c.job_name ?? `Job ${i + 1}`)}</div>
                <div className="mt-1 text-lg font-semibold">{String(c.last_status ?? c.status ?? "—")}</div>
                <div className="mt-1 text-xs text-[var(--color-muted)]">Last run {fmtTs(String(c.last_run_at ?? c.last_start_time ?? ""))}</div>
              </div>
            ))}
          </div>
        )}
      </section>

      <section>
        <h2 className="mb-2 text-sm font-semibold text-[var(--color-muted)]">DPDP routing</h2>
        {dpdpRes === null ? (
          <div className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-4 text-sm text-[var(--color-muted)]">Not available.</div>
        ) : (
          <div className="grid grid-cols-2 gap-3 md:grid-cols-4">
            <div className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-4">
              <div className="text-xs text-[var(--color-muted)]">Open grievances</div>
              <div className="mt-1 text-2xl font-semibold">{formatNumber(Number(dpdp?.open_count ?? 0))}</div>
            </div>
            <div className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-4">
              <div className="text-xs text-[var(--color-muted)]">In review</div>
              <div className="mt-1 text-2xl font-semibold">{formatNumber(Number(dpdp?.in_review_count ?? 0))}</div>
            </div>
            <div className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-4">
              <div className="text-xs text-[var(--color-muted)]">Resolved 30d</div>
              <div className="mt-1 text-2xl font-semibold">{formatNumber(Number(dpdp?.resolved_30d ?? 0))}</div>
            </div>
            <div className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-4">
              <div className="text-xs text-[var(--color-muted)]">SLA breached</div>
              <div className="mt-1 text-2xl font-semibold text-[var(--color-warn)]">{formatNumber(Number(dpdp?.sla_breached ?? 0))}</div>
            </div>
          </div>
        )}
      </section>

      <section>
        <h2 className="mb-2 text-sm font-semibold text-[var(--color-muted)]">Snapshot summaries</h2>
        <div className="grid grid-cols-1 gap-3 md:grid-cols-2">
          <div className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-4">
            <div className="text-xs text-[var(--color-muted)]">Morning pulse</div>
            {pulseRes === null ? (
              <div className="mt-1 text-sm text-[var(--color-muted)]">Not available.</div>
            ) : (
              <div className="mt-1 text-sm">
                Revenue today: <span className="font-semibold">{formatNumber(Number(pulse?.revenue_today_rupees ?? 0))}</span>
                <span className="text-[var(--color-muted)]"> · Jobs open: {formatNumber(Number(pulse?.open_jobs ?? 0))}</span>
              </div>
            )}
          </div>
          <div className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-4">
            <div className="text-xs text-[var(--color-muted)]">Payouts snapshot</div>
            {payoutsRes === null ? (
              <div className="mt-1 text-sm text-[var(--color-muted)]">Not available.</div>
            ) : (
              <div className="mt-1 text-sm">
                Queued: <span className="font-semibold">{formatNumber(Number(payouts?.queued_count ?? 0))}</span>
                <span className="text-[var(--color-muted)]"> · Paid 7d: {formatNumber(Number(payouts?.paid_7d_count ?? 0))}</span>
              </div>
            )}
          </div>
        </div>
      </section>

      <section>
        <h2 className="mb-2 text-sm font-semibold text-[var(--color-muted)]">Deep links</h2>
        <div className="grid grid-cols-2 gap-2 text-sm md:grid-cols-3">
          <Link href="/founder-action-center" className="rounded border border-[var(--color-border)] bg-[var(--color-surface)] p-3 hover:bg-[var(--color-surface-2)]">Action center</Link>
          <Link href="/founder-incidents-board" className="rounded border border-[var(--color-border)] bg-[var(--color-surface)] p-3 hover:bg-[var(--color-surface-2)]">Incidents board</Link>
          <Link href="/founder-cron-status" className="rounded border border-[var(--color-border)] bg-[var(--color-surface)] p-3 hover:bg-[var(--color-surface-2)]">Cron status</Link>
          <Link href="/founder-morning-pulse-v2" className="rounded border border-[var(--color-border)] bg-[var(--color-surface)] p-3 hover:bg-[var(--color-surface-2)]">Morning pulse v2</Link>
          <Link href="/dpdp-grievance-routing" className="rounded border border-[var(--color-border)] bg-[var(--color-surface)] p-3 hover:bg-[var(--color-surface-2)]">DPDP routing</Link>
          <Link href="/payouts-queue" className="rounded border border-[var(--color-border)] bg-[var(--color-surface)] p-3 hover:bg-[var(--color-surface-2)]">Payouts queue</Link>
        </div>
      </section>
    </main>
  );
}
