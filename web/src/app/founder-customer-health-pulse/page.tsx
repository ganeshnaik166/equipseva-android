import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";

export const metadata = { title: "Founder customer health pulse — r1754" };
export const dynamic = "force-dynamic";

type PulseRow = {
  week_start: string;
  total_active_hospitals: number;
  churned_this_week: number;
  nps_score: number | null;
  open_critical_tickets: number;
  repeat_rate_pct: number | null;
  health_index_score: number | null;
  recorded_at: string;
};

type AlertRow = {
  id: string;
  week_start: string;
  alert_type: string;
  alert_severity: string;
  alert_text: string;
  raised_at: string;
  acknowledged: boolean;
  acked_at: string | null;
};

type TrendRow = {
  week_start: string;
  health_index_score: number | null;
  nps_score: number | null;
  repeat_rate_pct: number | null;
  churned_this_week: number;
};

type CriticalRow = {
  id: string;
  week_start: string;
  alert_type: string;
  alert_text: string;
  raised_at: string;
  acknowledged: boolean;
};

function fmtDate(s: string | null): string {
  if (!s) return "—";
  try {
    return new Date(s).toISOString().slice(0, 10);
  } catch {
    return "—";
  }
}

function fmtNum(n: number | null, digits = 1): string {
  if (n === null || n === undefined) return "—";
  return Number(n).toFixed(digits);
}

function severityClass(sev: string): string {
  if (sev === "critical") return "text-red-700 font-semibold";
  if (sev === "warning") return "text-amber-700";
  if (sev === "info") return "text-sky-700";
  return "";
}

function healthClass(score: number | null): string {
  if (score === null || score === undefined) return "";
  if (score >= 80) return "text-emerald-700 font-semibold";
  if (score >= 60) return "text-amber-700";
  return "text-red-700 font-semibold";
}

export default async function FounderCustomerHealthPulsePage() {
  const sb = await getSupabaseServerClient();
  const [pulseRes, alertsRes, trendRes, criticalRes] = await Promise.all([
    sb.rpc("list_pulse_r1754"),
    sb.rpc("list_alerts_r1754"),
    sb.rpc("pulse_trend_r1754"),
    sb.rpc("critical_alerts_r1754"),
  ]);

  if (pulseRes.error) throw new Error(`list_pulse_r1754: ${pulseRes.error.message}`);
  if (alertsRes.error) throw new Error(`list_alerts_r1754: ${alertsRes.error.message}`);
  if (trendRes.error) throw new Error(`pulse_trend_r1754: ${trendRes.error.message}`);
  if (criticalRes.error) throw new Error(`critical_alerts_r1754: ${criticalRes.error.message}`);

  const pulses = (pulseRes.data ?? []) as PulseRow[];
  const alerts = (alertsRes.data ?? []) as AlertRow[];
  const trends = (trendRes.data ?? []) as TrendRow[];
  const criticals = (criticalRes.data ?? []) as CriticalRow[];

  const latest = pulses[0] ?? null;
  const totalWeeks = pulses.length;
  const openAlertCount = alerts.filter((a) => !a.acknowledged).length;
  const criticalOpen = criticals.filter((c) => !c.acknowledged).length;
  const avgHealth =
    pulses.length > 0
      ? pulses
          .filter((p) => p.health_index_score !== null)
          .reduce((acc, p) => acc + (p.health_index_score ?? 0), 0) /
        Math.max(1, pulses.filter((p) => p.health_index_score !== null).length)
      : 0;

  const pulseColumns: Column<PulseRow>[] = [
    { key: "week_start", header: "Week start", render: (r: any) => fmtDate(r.week_start) },
    { key: "total_active_hospitals", header: "Active hospitals", render: (r: any) => String(r.total_active_hospitals) },
    { key: "churned_this_week", header: "Churned", render: (r: any) => String(r.churned_this_week) },
    { key: "nps_score", header: "NPS", render: (r: any) => fmtNum(r.nps_score, 1) },
    { key: "open_critical_tickets", header: "Critical tix", render: (r: any) => String(r.open_critical_tickets) },
    { key: "repeat_rate_pct", header: "Repeat %", render: (r: any) => fmtNum(r.repeat_rate_pct, 1) },
    { key: "health_index_score", header: "Health idx", render: (r: any) => <span className={healthClass(r.health_index_score)}>{r.health_index_score ?? "—"}</span> },
    { key: "recorded_at", header: "Recorded", render: (r: any) => fmtDate(r.recorded_at) },
  ];

  const alertColumns: Column<AlertRow>[] = [
    { key: "week_start", header: "Week", render: (r: any) => fmtDate(r.week_start) },
    { key: "alert_type", header: "Type", render: (r: any) => r.alert_type },
    { key: "alert_severity", header: "Severity", render: (r: any) => <span className={severityClass(r.alert_severity)}>{r.alert_severity}</span> },
    { key: "alert_text", header: "Detail", render: (r: any) => r.alert_text },
    { key: "raised_at", header: "Raised", render: (r: any) => fmtDate(r.raised_at) },
    { key: "acknowledged", header: "Acked", render: (r: any) => (r.acknowledged ? "yes" : "no") },
    { key: "acked_at", header: "Acked at", render: (r: any) => fmtDate(r.acked_at) },
  ];

  const trendColumns: Column<TrendRow>[] = [
    { key: "week_start", header: "Week", render: (r: any) => fmtDate(r.week_start) },
    { key: "health_index_score", header: "Health idx", render: (r: any) => <span className={healthClass(r.health_index_score)}>{r.health_index_score ?? "—"}</span> },
    { key: "nps_score", header: "NPS", render: (r: any) => fmtNum(r.nps_score, 1) },
    { key: "repeat_rate_pct", header: "Repeat %", render: (r: any) => fmtNum(r.repeat_rate_pct, 1) },
    { key: "churned_this_week", header: "Churned", render: (r: any) => String(r.churned_this_week) },
  ];

  const criticalColumns: Column<CriticalRow>[] = [
    { key: "week_start", header: "Week", render: (r: any) => fmtDate(r.week_start) },
    { key: "alert_type", header: "Type", render: (r: any) => r.alert_type },
    { key: "alert_text", header: "Detail", render: (r: any) => <span className="text-red-700">{r.alert_text}</span> },
    { key: "raised_at", header: "Raised", render: (r: any) => fmtDate(r.raised_at) },
    { key: "acknowledged", header: "Acked", render: (r: any) => (r.acknowledged ? "yes" : "no") },
  ];

  return (
    <div className="p-6 space-y-8 max-w-7xl mx-auto">
      <header className="space-y-1">
        <h1 className="text-2xl font-semibold">Customer health pulse</h1>
        <p className="text-sm text-gray-600">
          Weekly composite of NPS, churn, ticket load, and repeat rate. Health index combines all four signals.
        </p>
      </header>

      <section className="grid grid-cols-2 md:grid-cols-4 gap-3">
        <div className="rounded border p-3">
          <div className="text-xs text-gray-500">Weeks recorded</div>
          <div className="text-2xl font-semibold">{totalWeeks}</div>
        </div>
        <div className="rounded border p-3">
          <div className="text-xs text-gray-500">Latest health idx</div>
          <div className={`text-2xl font-semibold ${healthClass(latest?.health_index_score ?? null)}`}>
            {latest?.health_index_score ?? "—"}
          </div>
        </div>
        <div className="rounded border p-3">
          <div className="text-xs text-gray-500">Open alerts</div>
          <div className="text-2xl font-semibold">{openAlertCount}</div>
        </div>
        <div className="rounded border p-3">
          <div className="text-xs text-gray-500">Critical unacked</div>
          <div className={`text-2xl font-semibold ${criticalOpen > 0 ? "text-red-700" : ""}`}>{criticalOpen}</div>
        </div>
      </section>

      {latest ? (
        <section className="rounded border p-4 bg-gray-50">
          <h2 className="text-sm font-semibold mb-2">Latest week snapshot ({fmtDate(latest.week_start)})</h2>
          <div className="grid grid-cols-2 md:grid-cols-6 gap-3 text-sm">
            <div>
              <div className="text-xs text-gray-500">Hospitals</div>
              <div className="font-medium">{latest.total_active_hospitals}</div>
            </div>
            <div>
              <div className="text-xs text-gray-500">Churned</div>
              <div className="font-medium">{latest.churned_this_week}</div>
            </div>
            <div>
              <div className="text-xs text-gray-500">NPS</div>
              <div className="font-medium">{fmtNum(latest.nps_score, 1)}</div>
            </div>
            <div>
              <div className="text-xs text-gray-500">Crit tix</div>
              <div className="font-medium">{latest.open_critical_tickets}</div>
            </div>
            <div>
              <div className="text-xs text-gray-500">Repeat %</div>
              <div className="font-medium">{fmtNum(latest.repeat_rate_pct, 1)}</div>
            </div>
            <div>
              <div className="text-xs text-gray-500">Avg health (all weeks)</div>
              <div className="font-medium">{fmtNum(avgHealth, 1)}</div>
            </div>
          </div>
        </section>
      ) : null}

      <section className="space-y-2">
        <h2 className="text-lg font-semibold">Weekly pulse history</h2>
        <p className="text-sm text-gray-600">
          Score band: 80+ healthy, 60 to 79 watch, below 60 at risk.
        </p>
        <DataTable rows={pulses} columns={pulseColumns} rowKey={(r: PulseRow, i: number) => String(r.week_start ?? i)} />
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-semibold">12-week trend</h2>
        <DataTable rows={trends} columns={trendColumns} rowKey={(r: TrendRow, i: number) => String(r.week_start ?? i)} />
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-semibold">All alerts</h2>
        <p className="text-sm text-gray-600">Types: churn_spike, nps_drop, ticket_surge, repeat_decline.</p>
        <DataTable rows={alerts} columns={alertColumns} rowKey={(r: AlertRow, i: number) => String(r.id ?? i)} />
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-semibold">Critical alerts (latest 50)</h2>
        <DataTable rows={criticals} columns={criticalColumns} rowKey={(r: CriticalRow, i: number) => String(r.id ?? i)} />
      </section>
    </div>
  );
}
