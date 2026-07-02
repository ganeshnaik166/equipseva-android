import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type Kpis = {
  total_complaints: number;
  open_count: number;
  fixed_count: number;
  critical_count: number;
  avg_cost_rupees: number;
  satisfied_pct: number;
};

type Complaint = {
  id: string;
  reported_on: string;
  hospital_name: string;
  equipment_model: string;
  complaint_kind: string;
  severity: string;
  root_cause: string;
  fix_action: string;
  fix_status: string;
  follow_up_on: string | null;
  cost_rupees: number;
};

type SeverityRow = { severity: string; cnt: number; avg_cost: number; fixed_pct: number };
type CauseRow = { root_cause: string; cnt: number; total_cost: number; fixed_pct: number };
type TrendRow = {
  trend_month: string;
  equipment_family: string;
  complaints_count: number;
  fixed_count: number;
  avg_resolution_days: number | null;
  recurrence_pct: number | null;
  status: string;
  recommended_action: string | null;
};
type FollowUp = {
  id: string;
  hospital_name: string;
  equipment_model: string;
  severity: string;
  fix_status: string;
  follow_up_on: string | null;
  days_remaining: number | null;
  engineer_assigned: string | null;
};
type Workload = {
  engineer_assigned: string;
  cases: number;
  open_cases: number;
  fixed_cases: number;
  total_cost: number;
};
type Hotspot = {
  equipment_model: string;
  cases: number;
  critical_cases: number;
  avg_db: number | null;
  avg_vib: number | null;
  total_cost: number;
};

function fmtRupees(n: number | null | undefined): string {
  if (n === null || n === undefined) return '-';
  return 'Rs ' + Number(n).toLocaleString('en-IN');
}

function fmtPct(n: number | null | undefined): string {
  if (n === null || n === undefined) return '-';
  return Number(n).toFixed(1) + '%';
}

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    kpisRes,
    recentRes,
    severityRes,
    causesRes,
    trendRes,
    followupRes,
    workloadRes,
    hotspotRes,
  ] = await Promise.all([
    supabase.rpc('founder_r2716_kpis'),
    supabase.rpc('founder_r2716_recent_complaints', { p_limit: 50 }),
    supabase.rpc('founder_r2716_severity_breakdown'),
    supabase.rpc('founder_r2716_top_causes', { p_limit: 10 }),
    supabase.rpc('founder_r2716_monthly_trend'),
    supabase.rpc('founder_r2716_pending_followups'),
    supabase.rpc('founder_r2716_engineer_workload'),
    supabase.rpc('founder_r2716_equipment_hotspots'),
  ]);

  const kpis: Kpis = (kpisRes.data && kpisRes.data[0]) || {
    total_complaints: 0,
    open_count: 0,
    fixed_count: 0,
    critical_count: 0,
    avg_cost_rupees: 0,
    satisfied_pct: 0,
  };
  const complaints: Complaint[] = recentRes.data || [];
  const severity: SeverityRow[] = severityRes.data || [];
  const causes: CauseRow[] = causesRes.data || [];
  const trend: TrendRow[] = trendRes.data || [];
  const followups: FollowUp[] = followupRes.data || [];
  const workload: Workload[] = workloadRes.data || [];
  const hotspots: Hotspot[] = hotspotRes.data || [];

  return (
    <div className="p-6 space-y-6">
      <header>
        <h1 className="text-2xl font-bold">Customer Monthly Noise & Vibration Complaints</h1>
        <p className="text-sm text-gray-600">
          Round 2716 — equipment × complaint kind × severity × cause × fix action × follow-up
        </p>
      </header>

      <section className="grid grid-cols-2 md:grid-cols-6 gap-3">
        <KpiCard label="Total complaints" value={String(kpis.total_complaints)} />
        <KpiCard label="Open" value={String(kpis.open_count)} />
        <KpiCard label="Fixed" value={String(kpis.fixed_count)} />
        <KpiCard label="Critical" value={String(kpis.critical_count)} tone="danger" />
        <KpiCard label="Avg cost" value={fmtRupees(kpis.avg_cost_rupees)} />
        <KpiCard label="Customer satisfied" value={fmtPct(kpis.satisfied_pct)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Recent complaints</h2>
        <DataTable
          rows={complaints}
          rowKey={(r, i) => String(r.id ?? i)}
          emptyMessage="No data"
          columns={[
            { key: 'reported_on', header: 'Date', render: (r: Complaint) => <span>{r.reported_on}</span> },
            { key: 'hospital_name', header: 'Hospital', render: (r: Complaint) => <span>{r.hospital_name}</span> },
            { key: 'equipment_model', header: 'Equipment', render: (r: Complaint) => <span>{r.equipment_model}</span> },
            { key: 'complaint_kind', header: 'Kind', render: (r: Complaint) => <span>{r.complaint_kind}</span> },
            { key: 'severity', header: 'Severity', render: (r: Complaint) => <SeverityBadge s={r.severity} /> },
            { key: 'root_cause', header: 'Root cause', render: (r: Complaint) => <span>{r.root_cause}</span> },
            { key: 'fix_action', header: 'Fix action', render: (r: Complaint) => <span>{r.fix_action}</span> },
            { key: 'fix_status', header: 'Status', render: (r: Complaint) => <span>{r.fix_status}</span> },
            { key: 'follow_up_on', header: 'Follow-up', render: (r: Complaint) => <span>{r.follow_up_on ?? '-'}</span> },
            { key: 'cost_rupees', header: 'Cost', render: (r: Complaint) => <span>{fmtRupees(r.cost_rupees)}</span> },
          ]}
        />
      </section>

      <section className="grid grid-cols-1 md:grid-cols-2 gap-6">
        <div>
          <h2 className="text-lg font-semibold mb-2">Severity breakdown</h2>
          <DataTable
            rows={severity}
            rowKey={(r, i) => String(r.severity ?? i)}
            emptyMessage="No data"
            columns={[
              { key: 'severity', header: 'Severity', render: (r: SeverityRow) => <SeverityBadge s={r.severity} /> },
              { key: 'cnt', header: 'Count', render: (r: SeverityRow) => <span>{r.cnt}</span> },
              { key: 'avg_cost', header: 'Avg cost', render: (r: SeverityRow) => <span>{fmtRupees(r.avg_cost)}</span> },
              { key: 'fixed_pct', header: 'Fixed %', render: (r: SeverityRow) => <span>{fmtPct(r.fixed_pct)}</span> },
            ]}
          />
        </div>

        <div>
          <h2 className="text-lg font-semibold mb-2">Top root causes</h2>
          <DataTable
            rows={causes}
            rowKey={(r, i) => String(r.root_cause ?? i)}
            emptyMessage="No data"
            columns={[
              { key: 'root_cause', header: 'Root cause', render: (r: CauseRow) => <span>{r.root_cause}</span> },
              { key: 'cnt', header: 'Cases', render: (r: CauseRow) => <span>{r.cnt}</span> },
              { key: 'total_cost', header: 'Total cost', render: (r: CauseRow) => <span>{fmtRupees(r.total_cost)}</span> },
              { key: 'fixed_pct', header: 'Fixed %', render: (r: CauseRow) => <span>{fmtPct(r.fixed_pct)}</span> },
            ]}
          />
        </div>
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Monthly trend</h2>
        <p className="text-xs text-gray-500 mb-2">
          recurrence % &lt;= 10 = stable; &gt; 15 needs attention
        </p>
        <DataTable
          rows={trend}
          rowKey={(r, i) => String(r.trend_month + '-' + r.equipment_family + '-' + i)}
          emptyMessage="No data"
          columns={[
            { key: 'trend_month', header: 'Month', render: (r: TrendRow) => <span>{r.trend_month}</span> },
            { key: 'equipment_family', header: 'Family', render: (r: TrendRow) => <span>{r.equipment_family}</span> },
            { key: 'complaints_count', header: 'Complaints', render: (r: TrendRow) => <span>{r.complaints_count}</span> },
            { key: 'fixed_count', header: 'Fixed', render: (r: TrendRow) => <span>{r.fixed_count}</span> },
            { key: 'avg_resolution_days', header: 'Avg days', render: (r: TrendRow) => <span>{r.avg_resolution_days ?? '-'}</span> },
            { key: 'recurrence_pct', header: 'Recurrence %', render: (r: TrendRow) => <span>{fmtPct(r.recurrence_pct ?? undefined)}</span> },
            { key: 'status', header: 'Status', render: (r: TrendRow) => <span>{r.status}</span> },
            { key: 'recommended_action', header: 'Recommend', render: (r: TrendRow) => <span>{r.recommended_action ?? '-'}</span> },
          ]}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Pending follow-ups</h2>
        <DataTable
          rows={followups}
          rowKey={(r, i) => String(r.id ?? i)}
          emptyMessage="No data"
          columns={[
            { key: 'hospital_name', header: 'Hospital', render: (r: FollowUp) => <span>{r.hospital_name}</span> },
            { key: 'equipment_model', header: 'Equipment', render: (r: FollowUp) => <span>{r.equipment_model}</span> },
            { key: 'severity', header: 'Severity', render: (r: FollowUp) => <SeverityBadge s={r.severity} /> },
            { key: 'fix_status', header: 'Status', render: (r: FollowUp) => <span>{r.fix_status}</span> },
            { key: 'follow_up_on', header: 'Follow-up', render: (r: FollowUp) => <span>{r.follow_up_on ?? '-'}</span> },
            { key: 'days_remaining', header: 'Days left', render: (r: FollowUp) => <span>{r.days_remaining ?? '-'}</span> },
            { key: 'engineer_assigned', header: 'Engineer', render: (r: FollowUp) => <span>{r.engineer_assigned ?? 'unassigned'}</span> },
          ]}
        />
      </section>

      <section className="grid grid-cols-1 md:grid-cols-2 gap-6">
        <div>
          <h2 className="text-lg font-semibold mb-2">Engineer workload</h2>
          <DataTable
            rows={workload}
            rowKey={(r, i) => String(r.engineer_assigned ?? i)}
            emptyMessage="No data"
            columns={[
              { key: 'engineer_assigned', header: 'Engineer', render: (r: Workload) => <span>{r.engineer_assigned}</span> },
              { key: 'cases', header: 'Cases', render: (r: Workload) => <span>{r.cases}</span> },
              { key: 'open_cases', header: 'Open', render: (r: Workload) => <span>{r.open_cases}</span> },
              { key: 'fixed_cases', header: 'Fixed', render: (r: Workload) => <span>{r.fixed_cases}</span> },
              { key: 'total_cost', header: 'Total cost', render: (r: Workload) => <span>{fmtRupees(r.total_cost)}</span> },
            ]}
          />
        </div>

        <div>
          <h2 className="text-lg font-semibold mb-2">Equipment hotspots</h2>
          <DataTable
            rows={hotspots}
            rowKey={(r, i) => String(r.equipment_model ?? i)}
            emptyMessage="No data"
            columns={[
              { key: 'equipment_model', header: 'Equipment', render: (r: Hotspot) => <span>{r.equipment_model}</span> },
              { key: 'cases', header: 'Cases', render: (r: Hotspot) => <span>{r.cases}</span> },
              { key: 'critical_cases', header: 'Critical', render: (r: Hotspot) => <span>{r.critical_cases}</span> },
              { key: 'avg_db', header: 'Avg dB', render: (r: Hotspot) => <span>{r.avg_db ?? '-'}</span> },
              { key: 'avg_vib', header: 'Avg mm/s', render: (r: Hotspot) => <span>{r.avg_vib ?? '-'}</span> },
              { key: 'total_cost', header: 'Total cost', render: (r: Hotspot) => <span>{fmtRupees(r.total_cost)}</span> },
            ]}
          />
        </div>
      </section>
    </div>
  );
}

function KpiCard({ label, value, tone }: { label: string; value: string; tone?: 'danger' }) {
  const cls =
    tone === 'danger'
      ? 'border border-red-300 bg-red-50'
      : 'border border-gray-200 bg-white';
  return (
    <div className={'rounded-lg p-3 ' + cls}>
      <div className="text-xs text-gray-600">{label}</div>
      <div className="text-xl font-semibold mt-1">{value}</div>
    </div>
  );
}

function SeverityBadge({ s }: { s: string }) {
  const map: Record<string, string> = {
    critical: 'bg-red-100 text-red-800',
    high: 'bg-orange-100 text-orange-800',
    medium: 'bg-yellow-100 text-yellow-800',
    low: 'bg-green-100 text-green-800',
  };
  const cls = map[s] ?? 'bg-gray-100 text-gray-800';
  return <span className={'px-2 py-0.5 rounded text-xs ' + cls}>{s}</span>;
}
