import { requireFounder } from '@/lib/auth/requireFounder';
import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type Kpi = { label: string; value: string };

function fmtNum(n: any): string {
  if (n === null || n === undefined) return '—';
  const v = Number(n);
  if (!isFinite(v)) return '—';
  return v.toLocaleString('en-IN');
}

function fmtPct(n: any): string {
  if (n === null || n === undefined) return '—';
  return `${Number(n).toFixed(1)}%`;
}

function fmtDate(d: any): string {
  if (!d) return '—';
  try { return new Date(d).toLocaleDateString('en-IN'); } catch { return '—'; }
}

function fmtDateTime(d: any): string {
  if (!d) return '—';
  try { return new Date(d).toLocaleString('en-IN'); } catch { return '—'; }
}

export default async function FounderHospitalQbrOutcomePage() {
  await requireFounder();
  const sb = await getSupabaseServerClient();

  let kpis: any = null;
  let outcomes: any[] = [];
  let overdue: any[] = [];
  let trend: any[] = [];
  let breakdown: any[] = [];

  try {
    const { data } = await sb.rpc('founder_qbr_outcome_kpis');
    kpis = Array.isArray(data) ? data[0] : data;
  } catch (e) { kpis = null; }

  try {
    const { data } = await sb.rpc('founder_qbr_recent_outcomes');
    outcomes = Array.isArray(data) ? data : [];
  } catch (e) { outcomes = []; }

  try {
    const { data } = await sb.rpc('founder_qbr_overdue_actions');
    overdue = Array.isArray(data) ? data : [];
  } catch (e) { overdue = []; }

  try {
    const { data } = await sb.rpc('founder_qbr_hospital_trend');
    trend = Array.isArray(data) ? data : [];
  } catch (e) { trend = []; }

  try {
    const { data } = await sb.rpc('founder_qbr_action_breakdown');
    breakdown = Array.isArray(data) ? data : [];
  } catch (e) { breakdown = []; }

  const k = kpis ?? {};
  const kpiCards: Kpi[] = [
    { label: 'QBRs (90d)', value: fmtNum(k.total_qbrs_90d) },
    { label: 'Unique Hospitals (90d)', value: fmtNum(k.unique_hospitals_90d) },
    { label: 'QBRs This Month', value: fmtNum(k.qbrs_this_month) },
    { label: 'Avg NPS Delta (90d)', value: fmtNum(k.avg_nps_delta_90d) },
    { label: 'Delighted', value: fmtNum(k.delighted_count) },
    { label: 'Satisfied', value: fmtNum(k.satisfied_count) },
    { label: 'Neutral', value: fmtNum(k.neutral_count) },
    { label: 'Concerned', value: fmtNum(k.concerned_count) },
    { label: 'At Risk', value: fmtNum(k.at_risk_count) },
    { label: 'Total Action Items', value: fmtNum(k.total_action_items) },
    { label: 'Open Items', value: fmtNum(k.open_action_items) },
    { label: 'Overdue Items', value: fmtNum(k.overdue_action_items) },
    { label: 'Done Items', value: fmtNum(k.done_action_items) },
    { label: 'Missed Items', value: fmtNum(k.missed_action_items) },
    { label: 'SLA Compliance', value: fmtPct(k.sla_compliance_pct) },
    { label: 'Avg Resolution (hrs)', value: fmtNum(k.avg_resolution_hours) },
  ];

  const outcomeCols: Column<any>[] = [
    { key: 'qbr_date', header: 'QBR Date', render: (r: any) => fmtDate(r.qbr_date) },
    { key: 'hospital_name', header: 'Hospital', render: (r: any) => r.hospital_name ?? '—' },
    { key: 'satisfaction_signal', header: 'Signal', render: (r: any) => r.satisfaction_signal ?? '—' },
    { key: 'nps_before', header: 'NPS Before', render: (r: any) => fmtNum(r.nps_before) },
    { key: 'nps_after', header: 'NPS After', render: (r: any) => fmtNum(r.nps_after) },
    { key: 'nps_delta', header: 'Delta', render: (r: any) => fmtNum(r.nps_delta) },
    { key: 'action_item_count', header: 'Items', render: (r: any) => fmtNum(r.action_item_count) },
    { key: 'open_items', header: 'Open', render: (r: any) => fmtNum(r.open_items) },
    { key: 'recorded_at', header: 'Recorded', render: (r: any) => fmtDateTime(r.recorded_at) },
  ];

  const overdueCols: Column<any>[] = [
    { key: 'hospital_name', header: 'Hospital', render: (r: any) => r.hospital_name ?? '—' },
    { key: 'item_type', header: 'Type', render: (r: any) => r.item_type ?? '—' },
    { key: 'description', header: 'Description', render: (r: any) => r.description ?? '—' },
    { key: 'priority', header: 'P', render: (r: any) => `P${r.priority ?? '—'}` },
    { key: 'sla_due_at', header: 'SLA Due', render: (r: any) => fmtDateTime(r.sla_due_at) },
    { key: 'hours_overdue', header: 'Hrs Overdue', render: (r: any) => fmtNum(r.hours_overdue) },
    { key: 'status', header: 'Status', render: (r: any) => r.status ?? '—' },
  ];

  const trendCols: Column<any>[] = [
    { key: 'hospital_name', header: 'Hospital', render: (r: any) => r.hospital_name ?? '—' },
    { key: 'qbr_count', header: 'QBRs', render: (r: any) => fmtNum(r.qbr_count) },
    { key: 'latest_signal', header: 'Latest Signal', render: (r: any) => r.latest_signal ?? '—' },
    { key: 'latest_nps_delta', header: 'Latest Delta', render: (r: any) => fmtNum(r.latest_nps_delta) },
    { key: 'avg_nps_delta', header: 'Avg Delta', render: (r: any) => fmtNum(r.avg_nps_delta) },
    { key: 'open_action_items', header: 'Open Items', render: (r: any) => fmtNum(r.open_action_items) },
    { key: 'last_qbr_date', header: 'Last QBR', render: (r: any) => fmtDate(r.last_qbr_date) },
  ];

  const breakdownCols: Column<any>[] = [
    { key: 'item_type', header: 'Type', render: (r: any) => r.item_type ?? '—' },
    { key: 'total_count', header: 'Total', render: (r: any) => fmtNum(r.total_count) },
    { key: 'open_count', header: 'Open', render: (r: any) => fmtNum(r.open_count) },
    { key: 'done_count', header: 'Done', render: (r: any) => fmtNum(r.done_count) },
    { key: 'missed_count', header: 'Missed', render: (r: any) => fmtNum(r.missed_count) },
    { key: 'avg_resolution_hours', header: 'Avg Hrs', render: (r: any) => fmtNum(r.avg_resolution_hours) },
  ];

  return (
    <main className="p-6 space-y-8">
      <header className="space-y-1">
        <h1 className="text-2xl font-semibold">Hospital QBR Outcome Tracker</h1>
        <p className="text-sm text-gray-600">Round r1567 — log QBR outcomes, NPS deltas, and founder follow-up SLA per action item.</p>
      </header>

      <section className="grid grid-cols-2 md:grid-cols-4 gap-3">
        {kpiCards.map((c) => (
          <div key={c.label} className="border rounded-lg p-3 bg-white">
            <div className="text-xs text-gray-500">{c.label}</div>
            <div className="text-lg font-semibold mt-1">{c.value}</div>
          </div>
        ))}
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-semibold">Recent QBR Outcomes</h2>
        <DataTable columns={outcomeCols} rows={outcomes} rowKey={(r: any) => r.id} />
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-semibold">Overdue Action Items</h2>
        <DataTable columns={overdueCols} rows={overdue} rowKey={(r: any) => r.id} />
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-semibold">Hospital Satisfaction Trend</h2>
        <DataTable columns={trendCols} rows={trend} rowKey={(r: any) => r.hospital_org_id} />
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-semibold">Action Item Type Breakdown</h2>
        <DataTable columns={breakdownCols} rows={breakdown} rowKey={(r: any) => r.item_type} />
      </section>
    </main>
  );
}
