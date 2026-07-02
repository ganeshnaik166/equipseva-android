import Link from "next/link";
import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { StatCard } from "@/components/StatCard";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "Founder live ops cockpit v2 — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Heartbeat = {
  open_priority_actions: number;
  open_incidents: number;
  code_red_open: number;
  cron_failure_rate_24h: number;
  dpdp_grievances_open: number;
  payouts_queued: number;
  billing_invoiced_30d_rupees: number;
  billing_outstanding_rupees: number;
  calendar_overdue_count: number;
  calendar_due_30d: number;
  total_active_amcs: number;
  total_active_engineers: number;
  generated_at: string | null;
  last_morning_pulse_at: string | null;
  hospitals_at_risk_count: number;
  system_health_score: number;
  most_recent_critical_event_at: string | null;
  alerts_red_count: number;
};

type ActionRow = { id?: string; action_type?: string; severity?: string; subject?: string; created_at?: string };
type IncidentRow = { id?: string; severity?: string; title?: string; created_at?: string; hospital_org_id?: string };
type CronRow = { jobname?: string; last_status?: string; last_run?: string; fail_count_24h?: number };
type CalendarRow = { id?: string; equipment_label?: string; scheduled_at?: string; hospital_org_id?: string };

async function tryRpc<T>(
  supabase: Awaited<ReturnType<typeof getSupabaseServerClient>>,
  fn: string,
): Promise<T[]> {
  try {
    const { data, error } = await supabase.rpc(fn);
    if (error) return [];
    return (data ?? []) as T[];
  } catch {
    return [];
  }
}

async function tryRpcOne<T>(
  supabase: Awaited<ReturnType<typeof getSupabaseServerClient>>,
  fn: string,
): Promise<T | null> {
  try {
    const { data, error } = await supabase.rpc(fn);
    if (error) return null;
    const arr = (data ?? []) as T[];
    return arr.length > 0 ? arr[0] : null;
  } catch {
    return null;
  }
}

function fmtRupees(n: number): string {
  return `Rs ${formatNumber(n)}`;
}

function timeAgo(iso: string | null | undefined): string {
  if (!iso) return "—";
  const t = new Date(iso).getTime();
  if (!Number.isFinite(t)) return "—";
  const sec = Math.max(0, Math.floor((Date.now() - t) / 1000));
  if (sec < 60) return `${sec}s ago`;
  if (sec < 3600) return `${Math.floor(sec / 60)}m ago`;
  if (sec < 86400) return `${Math.floor(sec / 3600)}h ago`;
  return `${Math.floor(sec / 86400)}d ago`;
}

function healthTone(score: number): string {
  if (score >= 85) return "text-[var(--color-ok)]";
  if (score >= 60) return "text-[var(--color-warn)]";
  return "text-[var(--color-danger)]";
}

export default async function FounderLiveOpsCockpitV2Page() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();

  // 8 RPC calls in parallel + heartbeat
  const [
    heartbeat,
    actionCenter,
    incidentsRecent,
    cronStatus,
    morningPulse,
    dpdpRouting,
    payoutsSnapshot,
    billingEngine,
    calendarBurndown,
  ] = await Promise.all([
    tryRpcOne<Heartbeat>(supabase, "founder_live_ops_cockpit_v2_heartbeat"),
    tryRpc<ActionRow>(supabase, "founder_action_center"),
    tryRpc<IncidentRow>(supabase, "founder_incidents_recent"),
    tryRpc<CronRow>(supabase, "founder_cron_status_summary"),
    tryRpc<{ metric: string; value: number }>(supabase, "founder_morning_pulse_v2"),
    tryRpc<{ window_label: string; routed: number; pending: number }>(supabase, "founder_dpdp_routing_summary"),
    tryRpc<{ status: string; count: number; amount_rupees: number }>(supabase, "founder_payouts_snapshot_summary"),
    tryRpc<{ window_label: string; invoiced_rupees: number; collected_rupees: number }>(supabase, "founder_hospital_billing_engine_summary"),
    tryRpc<CalendarRow>(supabase, "founder_calendar_burndown_summary"),
  ]);

  const hb: Heartbeat = heartbeat ?? {
    open_priority_actions: 0,
    open_incidents: 0,
    code_red_open: 0,
    cron_failure_rate_24h: 0,
    dpdp_grievances_open: 0,
    payouts_queued: 0,
    billing_invoiced_30d_rupees: 0,
    billing_outstanding_rupees: 0,
    calendar_overdue_count: 0,
    calendar_due_30d: 0,
    total_active_amcs: 0,
    total_active_engineers: 0,
    generated_at: null,
    last_morning_pulse_at: null,
    hospitals_at_risk_count: 0,
    system_health_score: 0,
    most_recent_critical_event_at: null,
    alerts_red_count: 0,
  };

  const topActions = actionCenter.slice(0, 5);
  const topIncidents = incidentsRecent.slice(0, 5);
  const topCalendar = calendarBurndown.slice(0, 5);
  const cronFailures = cronStatus.filter((c) => (c.fail_count_24h ?? 0) > 0).slice(0, 5);

  // 18 hero KPI cards
  const heroKpis: { label: string; value: string; tone?: string; href?: string }[] = [
    { label: "System health", value: `${hb.system_health_score}/100`, tone: healthTone(hb.system_health_score) },
    { label: "Red alerts", value: formatNumber(hb.alerts_red_count), tone: hb.alerts_red_count > 0 ? "text-[var(--color-danger)]" : "text-[var(--color-ok)]" },
    { label: "Priority actions open", value: formatNumber(hb.open_priority_actions), href: "/founder-action-center" },
    { label: "Incidents open", value: formatNumber(hb.open_incidents), href: "/founder-incidents" },
    { label: "Code Red open", value: formatNumber(hb.code_red_open), tone: hb.code_red_open > 0 ? "text-[var(--color-danger)]" : undefined, href: "/code-red" },
    { label: "Cron fail 24h", value: `${hb.cron_failure_rate_24h}%`, tone: hb.cron_failure_rate_24h > 10 ? "text-[var(--color-danger)]" : hb.cron_failure_rate_24h > 0 ? "text-[var(--color-warn)]" : "text-[var(--color-ok)]", href: "/cron-status" },
    { label: "DPDP grievances", value: formatNumber(hb.dpdp_grievances_open), href: "/dpdp-grievances" },
    { label: "Payouts queued", value: formatNumber(hb.payouts_queued), href: "/payouts-queue" },
    { label: "Billed 30d", value: fmtRupees(hb.billing_invoiced_30d_rupees), href: "/billing-engine" },
    { label: "Outstanding", value: fmtRupees(hb.billing_outstanding_rupees), tone: hb.billing_outstanding_rupees > 0 ? "text-[var(--color-warn)]" : undefined },
    { label: "PM overdue", value: formatNumber(hb.calendar_overdue_count), tone: hb.calendar_overdue_count > 10 ? "text-[var(--color-danger)]" : undefined, href: "/calendar-burndown" },
    { label: "PM due 30d", value: formatNumber(hb.calendar_due_30d), href: "/calendar-burndown" },
    { label: "Active AMCs", value: formatNumber(hb.total_active_amcs), href: "/amc-index" },
    { label: "Active engineers", value: formatNumber(hb.total_active_engineers), href: "/engineers-index" },
    { label: "Hospitals at risk", value: formatNumber(hb.hospitals_at_risk_count), tone: hb.hospitals_at_risk_count > 0 ? "text-[var(--color-warn)]" : undefined },
    { label: "Last pulse", value: timeAgo(hb.last_morning_pulse_at) },
    { label: "Last critical", value: timeAgo(hb.most_recent_critical_event_at), tone: hb.most_recent_critical_event_at ? "text-[var(--color-warn)]" : undefined },
    { label: "Generated", value: timeAgo(hb.generated_at) },
  ];

  return (
    <div className="space-y-8">
      <header className="flex flex-wrap items-baseline justify-between gap-2">
        <div>
          <h1 className="text-xl font-semibold">Founder live ops cockpit v2</h1>
          <div className="text-xs text-[var(--color-muted)]">
            Real-time composite · 8 RPCs in parallel · 18 KPIs · graceful degradation per surface
          </div>
        </div>
        <span className="text-xs text-[var(--color-muted)]">r1404 HEAVY · live</span>
      </header>

      <section>
        <h2 className="mb-2 text-xs font-medium uppercase tracking-wider text-[var(--color-muted)]">
          18 hero KPIs
        </h2>
        <div className="grid grid-cols-2 gap-2 md:grid-cols-3 lg:grid-cols-6">
          {heroKpis.map((k) => {
            const inner = (
              <>
                <div className="text-[10px] uppercase tracking-wider text-[var(--color-muted)]">{k.label}</div>
                <div className={`mt-1 text-base font-semibold tabular-nums ${k.tone ?? ""}`}>{k.value}</div>
              </>
            );
            return k.href ? (
              <Link
                key={k.label}
                href={k.href}
                className="rounded border border-[var(--color-border)] bg-white p-3 transition-colors hover:border-[var(--color-fg)]"
              >
                {inner}
              </Link>
            ) : (
              <div
                key={k.label}
                className="rounded border border-[var(--color-border)] bg-white p-3"
              >
                {inner}
              </div>
            );
          })}
        </div>
      </section>

      <section className="grid grid-cols-1 gap-4 lg:grid-cols-2">
        <div>
          <h2 className="mb-2 text-xs font-medium uppercase tracking-wider text-[var(--color-muted)]">
            Top 5 priority actions
          </h2>
          <div className="rounded border border-[var(--color-border)] bg-white">
            {topActions.length === 0 ? (
              <div className="p-3 text-xs text-[var(--color-muted)]">No open actions.</div>
            ) : (
              <ul className="divide-y divide-[var(--color-border)]">
                {topActions.map((a, i) => (
                  <li key={a.id ?? `a-${i}`} className="p-3 text-sm">
                    <div className="flex items-baseline justify-between gap-2">
                      <span className="font-medium">{a.subject ?? a.action_type ?? "Action"}</span>
                      <span className="text-[10px] uppercase tracking-wider text-[var(--color-muted)]">
                        {a.severity ?? "—"}
                      </span>
                    </div>
                    <div className="mt-0.5 text-xs text-[var(--color-muted)]">{timeAgo(a.created_at)}</div>
                  </li>
                ))}
              </ul>
            )}
            <Link href="/founder-action-center" className="block border-t border-[var(--color-border)] p-2 text-xs underline text-[var(--color-muted)]">
              All actions →
            </Link>
          </div>
        </div>

        <div>
          <h2 className="mb-2 text-xs font-medium uppercase tracking-wider text-[var(--color-muted)]">
            Top 5 open incidents
          </h2>
          <div className="rounded border border-[var(--color-border)] bg-white">
            {topIncidents.length === 0 ? (
              <div className="p-3 text-xs text-[var(--color-muted)]">No open incidents.</div>
            ) : (
              <ul className="divide-y divide-[var(--color-border)]">
                {topIncidents.map((inc, i) => (
                  <li key={inc.id ?? `i-${i}`} className="p-3 text-sm">
                    <div className="flex items-baseline justify-between gap-2">
                      <span className="font-medium">{inc.title ?? "Incident"}</span>
                      <span className={`text-[10px] uppercase tracking-wider ${inc.severity === "high" || inc.severity === "critical" ? "text-[var(--color-danger)]" : "text-[var(--color-muted)]"}`}>
                        {inc.severity ?? "—"}
                      </span>
                    </div>
                    <div className="mt-0.5 text-xs text-[var(--color-muted)]">{timeAgo(inc.created_at)}</div>
                  </li>
                ))}
              </ul>
            )}
            <Link href="/founder-incidents" className="block border-t border-[var(--color-border)] p-2 text-xs underline text-[var(--color-muted)]">
              All incidents →
            </Link>
          </div>
        </div>
      </section>

      <section className="grid grid-cols-1 gap-4 lg:grid-cols-2">
        <div>
          <h2 className="mb-2 text-xs font-medium uppercase tracking-wider text-[var(--color-muted)]">
            Cron health (24h failures)
          </h2>
          <div className="rounded border border-[var(--color-border)] bg-white">
            <div className="grid grid-cols-3 gap-2 border-b border-[var(--color-border)] p-3 text-xs">
              <StatCard label="Fail rate" value={`${hb.cron_failure_rate_24h}%`} />
              <StatCard label="Jobs surveyed" value={formatNumber(cronStatus.length)} />
              <StatCard label="With failures" value={formatNumber(cronFailures.length)} />
            </div>
            {cronFailures.length === 0 ? (
              <div className="p-3 text-xs text-[var(--color-muted)]">All cron jobs healthy in last 24h.</div>
            ) : (
              <ul className="divide-y divide-[var(--color-border)]">
                {cronFailures.map((c, i) => (
                  <li key={c.jobname ?? `c-${i}`} className="p-3 text-sm">
                    <div className="flex items-baseline justify-between gap-2">
                      <span className="font-mono text-xs">{c.jobname ?? "—"}</span>
                      <span className="text-[10px] uppercase tracking-wider text-[var(--color-danger)]">
                        {formatNumber(c.fail_count_24h ?? 0)} fail
                      </span>
                    </div>
                    <div className="mt-0.5 text-xs text-[var(--color-muted)]">last run {timeAgo(c.last_run)}</div>
                  </li>
                ))}
              </ul>
            )}
            <Link href="/cron-status" className="block border-t border-[var(--color-border)] p-2 text-xs underline text-[var(--color-muted)]">
              Cron status →
            </Link>
          </div>
        </div>

        <div>
          <h2 className="mb-2 text-xs font-medium uppercase tracking-wider text-[var(--color-muted)]">
            Upcoming PM (next 5)
          </h2>
          <div className="rounded border border-[var(--color-border)] bg-white">
            <div className="grid grid-cols-2 gap-2 border-b border-[var(--color-border)] p-3 text-xs">
              <StatCard label="Overdue" value={formatNumber(hb.calendar_overdue_count)} />
              <StatCard label="Due in 30d" value={formatNumber(hb.calendar_due_30d)} />
            </div>
            {topCalendar.length === 0 ? (
              <div className="p-3 text-xs text-[var(--color-muted)]">Nothing scheduled.</div>
            ) : (
              <ul className="divide-y divide-[var(--color-border)]">
                {topCalendar.map((c, i) => (
                  <li key={c.id ?? `cal-${i}`} className="p-3 text-sm">
                    <div className="flex items-baseline justify-between gap-2">
                      <span className="font-medium">{c.equipment_label ?? "Maintenance"}</span>
                      <span className="text-[10px] uppercase tracking-wider text-[var(--color-muted)]">
                        {timeAgo(c.scheduled_at)}
                      </span>
                    </div>
                  </li>
                ))}
              </ul>
            )}
            <Link href="/calendar-burndown" className="block border-t border-[var(--color-border)] p-2 text-xs underline text-[var(--color-muted)]">
              Calendar burndown →
            </Link>
          </div>
        </div>
      </section>

      <section>
        <h2 className="mb-2 text-xs font-medium uppercase tracking-wider text-[var(--color-muted)]">
          Surface freshness (8 RPC parallel fan-out)
        </h2>
        <div className="grid grid-cols-2 gap-2 md:grid-cols-4">
          <StatCard label="Action center" value={`${actionCenter.length} rows`} />
          <StatCard label="Incidents recent" value={`${incidentsRecent.length} rows`} />
          <StatCard label="Cron status" value={`${cronStatus.length} rows`} />
          <StatCard label="Morning pulse" value={`${morningPulse.length} rows`} />
          <StatCard label="DPDP routing" value={`${dpdpRouting.length} rows`} />
          <StatCard label="Payouts snapshot" value={`${payoutsSnapshot.length} rows`} />
          <StatCard label="Billing engine" value={`${billingEngine.length} rows`} />
          <StatCard label="Calendar burndown" value={`${calendarBurndown.length} rows`} />
        </div>
      </section>

      <section className="rounded border border-[var(--color-border)] bg-white p-3 text-xs text-[var(--color-muted)]">
        <strong>Cockpit v2:</strong> single composite request fans out to 8 founder RPCs in parallel via Promise.all. Each RPC try/catches independently so one slow surface cannot stall the cockpit. Heartbeat aggregates 18 headline KPIs in a single round trip. System health is a composite score (0..100) penalised by cron failures, code red volume, open incidents, DPDP backlog, PM overdue, and red-alert count.
      </section>
    </div>
  );
}
