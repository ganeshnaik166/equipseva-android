import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";

export const metadata = { title: "Founder engineer cross-zone fill-in tracker — r2406" };
export const dynamic = "force-dynamic";

type FillinRow = {
  id: string;
  engineer_user_id: string;
  engineer_email: string | null;
  absent_engineer_user_id: string | null;
  absent_engineer_email: string | null;
  home_zone: string;
  fillin_zone: string;
  fillin_date: string;
  jobs_covered: number;
  hours_worked: number;
  travel_km: number;
  base_rate_rupees: number;
  cross_zone_uplift_pct: number;
  billable_amount_rupees: number;
  fair_comp_rupees: number;
  fatigue_score: number;
  fatigue_flag: string;
  consecutive_fillin_days: number;
  status: string;
  notes: string | null;
  created_at: string;
};

type SummaryRow = {
  engineer_user_id: string;
  engineer_email: string | null;
  home_zone: string | null;
  fillin_count: number;
  total_jobs: number;
  total_hours: number;
  total_billable_rupees: number;
  total_fair_comp_rupees: number;
  avg_fatigue_score: number;
  current_consecutive_days: number;
  worst_fatigue_flag: string;
  last_fillin_date: string | null;
};

type ZonePairRow = {
  home_zone: string;
  fillin_zone: string;
  fillin_count: number;
  total_jobs: number;
  total_billable_rupees: number;
  total_fair_comp_rupees: number;
  avg_travel_km: number;
  unique_engineers: number;
};

type AlertRow = {
  id: string;
  engineer_user_id: string;
  engineer_email: string | null;
  alert_date: string;
  consecutive_days: number;
  total_hours_7d: number;
  fatigue_score: number;
  severity: string;
  recommended_rest_days: number;
  acknowledged: boolean;
  acknowledged_at: string | null;
  acknowledged_by_email: string | null;
  notes: string | null;
  created_at: string;
};

type StatsRow = {
  total_fillins: number;
  total_engineers: number;
  total_jobs_covered: number;
  total_hours_worked: number;
  total_billable_rupees: number;
  total_fair_comp_rupees: number;
  avg_uplift_pct: number;
  open_alerts: number;
  critical_alerts: number;
  pending_payouts: number;
  pending_payout_rupees: number;
};

function fmtDate(s: string | null): string {
  if (!s) return "—";
  try {
    return new Date(s).toISOString().slice(0, 10);
  } catch {
    return "—";
  }
}

function fmtRupees(n: number | null | undefined): string {
  if (n == null) return "—";
  return "₹" + Number(n).toLocaleString("en-IN");
}

function fatigueClass(flag: string): string {
  if (flag === "critical") return "text-red-700 font-semibold";
  if (flag === "high") return "text-orange-700 font-semibold";
  if (flag === "watch") return "text-amber-700";
  return "text-emerald-700";
}

function statusClass(status: string): string {
  if (status === "paid") return "text-emerald-700";
  if (status === "approved") return "text-blue-700";
  if (status === "logged") return "text-amber-700";
  if (status === "disputed") return "text-red-700";
  if (status === "cancelled") return "text-gray-500";
  return "";
}

function severityClass(s: string): string {
  if (s === "critical") return "text-red-700 font-semibold";
  if (s === "high") return "text-orange-700 font-semibold";
  if (s === "watch") return "text-amber-700";
  return "";
}

export default async function FounderCrossZoneFillinTrackerPage() {
  const sb = await getSupabaseServerClient();
  const [fillinsRes, summaryRes, zoneRes, alertsRes, statsRes] = await Promise.all([
    sb.rpc("list_cross_zone_fillins_r2406"),
    sb.rpc("engineer_fillin_summary_r2406"),
    sb.rpc("zone_pair_flow_r2406"),
    sb.rpc("open_fatigue_alerts_r2406"),
    sb.rpc("cross_zone_console_stats_r2406"),
  ]);

  if (fillinsRes.error) throw new Error(`list_cross_zone_fillins_r2406: ${fillinsRes.error.message}`);
  if (summaryRes.error) throw new Error(`engineer_fillin_summary_r2406: ${summaryRes.error.message}`);
  if (zoneRes.error) throw new Error(`zone_pair_flow_r2406: ${zoneRes.error.message}`);
  if (alertsRes.error) throw new Error(`open_fatigue_alerts_r2406: ${alertsRes.error.message}`);
  if (statsRes.error) throw new Error(`cross_zone_console_stats_r2406: ${statsRes.error.message}`);

  const fillins = (fillinsRes.data ?? []) as FillinRow[];
  const summary = (summaryRes.data ?? []) as SummaryRow[];
  const zonePairs = (zoneRes.data ?? []) as ZonePairRow[];
  const alerts = (alertsRes.data ?? []) as AlertRow[];
  const stats = ((statsRes.data ?? [])[0] ?? null) as StatsRow | null;

  const fillinColumns: Column<FillinRow>[] = [
    { key: "fillin_date", header: "Date", render: (r: any) => fmtDate(r.fillin_date) },
    { key: "engineer_email", header: "Engineer", render: (r: any) => <span className="font-medium">{r.engineer_email ?? "—"}</span> },
    { key: "home_zone", header: "Home", render: (r: any) => r.home_zone },
    { key: "fillin_zone", header: "Filled in", render: (r: any) => <span className="font-medium">{r.fillin_zone}</span> },
    { key: "absent_engineer_email", header: "Covering for", render: (r: any) => r.absent_engineer_email ?? "—" },
    { key: "jobs_covered", header: "Jobs", render: (r: any) => String(r.jobs_covered) },
    { key: "hours_worked", header: "Hours", render: (r: any) => Number(r.hours_worked).toFixed(1) },
    { key: "travel_km", header: "Travel km", render: (r: any) => Number(r.travel_km).toFixed(0) },
    { key: "cross_zone_uplift_pct", header: "Uplift %", render: (r: any) => Number(r.cross_zone_uplift_pct).toFixed(1) + "%" },
    { key: "billable_amount_rupees", header: "Billable", render: (r: any) => fmtRupees(r.billable_amount_rupees) },
    { key: "fair_comp_rupees", header: "Fair comp", render: (r: any) => <span className="font-medium">{fmtRupees(r.fair_comp_rupees)}</span> },
    { key: "consecutive_fillin_days", header: "Streak", render: (r: any) => String(r.consecutive_fillin_days) + "d" },
    { key: "fatigue_flag", header: "Fatigue", render: (r: any) => <span className={fatigueClass(r.fatigue_flag)}>{r.fatigue_flag} ({r.fatigue_score})</span> },
    { key: "status", header: "Status", render: (r: any) => <span className={statusClass(r.status)}>{r.status}</span> },
  ];

  const summaryColumns: Column<SummaryRow>[] = [
    { key: "engineer_email", header: "Engineer", render: (r: any) => <span className="font-medium">{r.engineer_email ?? "—"}</span> },
    { key: "home_zone", header: "Home zone", render: (r: any) => r.home_zone ?? "—" },
    { key: "fillin_count", header: "Fill-ins", render: (r: any) => String(r.fillin_count) },
    { key: "total_jobs", header: "Jobs", render: (r: any) => String(r.total_jobs) },
    { key: "total_hours", header: "Hours", render: (r: any) => Number(r.total_hours).toFixed(1) },
    { key: "total_billable_rupees", header: "Total billable", render: (r: any) => fmtRupees(r.total_billable_rupees) },
    { key: "total_fair_comp_rupees", header: "Total fair comp", render: (r: any) => <span className="font-medium">{fmtRupees(r.total_fair_comp_rupees)}</span> },
    { key: "avg_fatigue_score", header: "Avg fatigue", render: (r: any) => Number(r.avg_fatigue_score).toFixed(0) },
    { key: "current_consecutive_days", header: "Max streak", render: (r: any) => String(r.current_consecutive_days) + "d" },
    { key: "worst_fatigue_flag", header: "Worst flag", render: (r: any) => <span className={fatigueClass(r.worst_fatigue_flag)}>{r.worst_fatigue_flag}</span> },
    { key: "last_fillin_date", header: "Last fill-in", render: (r: any) => fmtDate(r.last_fillin_date) },
  ];

  const zoneColumns: Column<ZonePairRow>[] = [
    { key: "home_zone", header: "From (home)", render: (r: any) => <span className="font-medium">{r.home_zone}</span> },
    { key: "fillin_zone", header: "To (covered)", render: (r: any) => <span className="font-medium">{r.fillin_zone}</span> },
    { key: "fillin_count", header: "Fill-ins", render: (r: any) => String(r.fillin_count) },
    { key: "unique_engineers", header: "Unique engs", render: (r: any) => String(r.unique_engineers) },
    { key: "total_jobs", header: "Jobs", render: (r: any) => String(r.total_jobs) },
    { key: "avg_travel_km", header: "Avg travel km", render: (r: any) => Number(r.avg_travel_km).toFixed(0) },
    { key: "total_billable_rupees", header: "Billable", render: (r: any) => fmtRupees(r.total_billable_rupees) },
    { key: "total_fair_comp_rupees", header: "Fair comp", render: (r: any) => fmtRupees(r.total_fair_comp_rupees) },
  ];

  const alertColumns: Column<AlertRow>[] = [
    { key: "alert_date", header: "Alert date", render: (r: any) => fmtDate(r.alert_date) },
    { key: "engineer_email", header: "Engineer", render: (r: any) => <span className="font-medium">{r.engineer_email ?? "—"}</span> },
    { key: "severity", header: "Severity", render: (r: any) => <span className={severityClass(r.severity)}>{r.severity}</span> },
    { key: "fatigue_score", header: "Score", render: (r: any) => String(r.fatigue_score) },
    { key: "consecutive_days", header: "Streak days", render: (r: any) => String(r.consecutive_days) + "d" },
    { key: "total_hours_7d", header: "Hours 7d", render: (r: any) => Number(r.total_hours_7d).toFixed(1) },
    { key: "recommended_rest_days", header: "Rest days", render: (r: any) => String(r.recommended_rest_days) },
    { key: "acknowledged", header: "Acked", render: (r: any) => (r.acknowledged ? "yes" : "no") },
    { key: "acknowledged_by_email", header: "Acked by", render: (r: any) => r.acknowledged_by_email ?? "—" },
    { key: "notes", header: "Notes", render: (r: any) => r.notes ?? "—" },
  ];

  return (
    <div className="space-y-6 p-6">
      <header>
        <h1 className="text-xl font-semibold">Founder engineer cross-zone fill-in tracker — r2406</h1>
        <p className="mt-1 text-xs text-gray-500">
          When engineers fill in for absent peers in other zones, log billable rate uplift, fair compensation, and
          fatigue indicator. Critical fatigue =&gt; mandatory rest before next cross-zone shift.
        </p>
      </header>

      <section className="grid grid-cols-2 gap-3 md:grid-cols-6">
        <div className="rounded border border-gray-200 bg-white p-3">
          <div className="text-xs text-gray-500">Total fill-ins</div>
          <div className="mt-1 text-lg font-semibold">{stats?.total_fillins ?? 0}</div>
        </div>
        <div className="rounded border border-gray-200 bg-white p-3">
          <div className="text-xs text-gray-500">Engineers involved</div>
          <div className="mt-1 text-lg font-semibold">{stats?.total_engineers ?? 0}</div>
        </div>
        <div className="rounded border border-gray-200 bg-white p-3">
          <div className="text-xs text-gray-500">Jobs covered</div>
          <div className="mt-1 text-lg font-semibold">{stats?.total_jobs_covered ?? 0}</div>
        </div>
        <div className="rounded border border-gray-200 bg-white p-3">
          <div className="text-xs text-gray-500">Total billable</div>
          <div className="mt-1 text-lg font-semibold">{fmtRupees(stats?.total_billable_rupees ?? 0)}</div>
        </div>
        <div className="rounded border border-gray-200 bg-white p-3">
          <div className="text-xs text-gray-500">Fair comp paid+owed</div>
          <div className="mt-1 text-lg font-semibold">{fmtRupees(stats?.total_fair_comp_rupees ?? 0)}</div>
        </div>
        <div className="rounded border border-gray-200 bg-white p-3">
          <div className="text-xs text-gray-500">Avg uplift %</div>
          <div className="mt-1 text-lg font-semibold">{Number(stats?.avg_uplift_pct ?? 0).toFixed(1)}%</div>
        </div>
      </section>

      <section className="grid grid-cols-2 gap-3 md:grid-cols-4">
        <div className="rounded border border-gray-200 bg-white p-3">
          <div className="text-xs text-gray-500">Open fatigue alerts</div>
          <div className="mt-1 text-lg font-semibold text-amber-700">{stats?.open_alerts ?? 0}</div>
        </div>
        <div className="rounded border border-red-200 bg-red-50 p-3">
          <div className="text-xs text-red-600">Critical alerts</div>
          <div className="mt-1 text-lg font-semibold text-red-700">{stats?.critical_alerts ?? 0}</div>
        </div>
        <div className="rounded border border-gray-200 bg-white p-3">
          <div className="text-xs text-gray-500">Pending payouts (count)</div>
          <div className="mt-1 text-lg font-semibold">{stats?.pending_payouts ?? 0}</div>
        </div>
        <div className="rounded border border-gray-200 bg-white p-3">
          <div className="text-xs text-gray-500">Pending payout ₹</div>
          <div className="mt-1 text-lg font-semibold">{fmtRupees(stats?.pending_payout_rupees ?? 0)}</div>
        </div>
      </section>

      <section className="space-y-3">
        <h2 className="text-base font-semibold">Open fatigue alerts</h2>
        <p className="text-xs text-gray-500">
          Fatigue score &gt;= 60 =&gt; watch, &gt;= 75 =&gt; high, &gt;= 90 =&gt; critical. Critical engineers must rest
          before next cross-zone shift. Founder acks each alert and records intervention.
        </p>
        <DataTable
          rows={alerts}
          columns={alertColumns}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
          emptyMessage="No open fatigue alerts."
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-base font-semibold">Per-engineer summary</h2>
        <p className="text-xs text-gray-500">
          Cumulative billable &amp; fair comp per engineer, ranked by total billable amount. Watch worst-flag column
          for repeat critical-fatigue engineers.
        </p>
        <DataTable
          rows={summary}
          columns={summaryColumns}
          rowKey={(r: any, i: number) => String(r.engineer_user_id ?? i)}
          emptyMessage="No fill-ins logged yet."
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-base font-semibold">Zone-pair flow</h2>
        <p className="text-xs text-gray-500">
          From (home zone) =&gt; To (filled-in zone). Pairs with high fill-in counts =&gt; structural under-staffing in
          the destination zone; consider permanent hire.
        </p>
        <DataTable
          rows={zonePairs}
          columns={zoneColumns}
          rowKey={(r: any, i: number) => r.home_zone + "_" + r.fillin_zone + "_" + i}
          emptyMessage="No zone-pair flow data yet."
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-base font-semibold">All fill-in events</h2>
        <p className="text-xs text-gray-500">
          Latest 500 fill-in events. Billable amount = base rate * (1 + uplift%). Fair comp =&gt; what engineer actually
          receives after platform cut. Streak &gt;= 5d typically triggers fatigue watch.
        </p>
        <DataTable
          rows={fillins}
          columns={fillinColumns}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
          emptyMessage="No cross-zone fill-ins logged yet."
        />
      </section>
    </div>
  );
}
