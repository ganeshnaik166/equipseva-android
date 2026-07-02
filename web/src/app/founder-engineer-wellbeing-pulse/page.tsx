import { requireFounder } from '@/lib/auth/requireFounder';
import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type Kpi = { label: string; value: string };

function fmt(n: any): string {
  if (n === null || n === undefined) return '-';
  if (typeof n === 'number') return n.toLocaleString('en-IN');
  return String(n);
}

function fmtNum(n: any, digits = 2): string {
  if (n === null || n === undefined) return '-';
  const v = Number(n);
  if (Number.isNaN(v)) return '-';
  return v.toFixed(digits);
}

function fmtDate(d: any): string {
  if (!d) return '-';
  try { return new Date(d).toLocaleString('en-IN', { dateStyle: 'short', timeStyle: 'short' }); } catch { return String(d); }
}

export default async function FounderEngineerWellbeingPulsePage() {
  await requireFounder();
  const sb = await getSupabaseServerClient();

  let kpis: any = null;
  let cycles: any[] = [];
  let redFlags: any[] = [];
  let trend: any[] = [];
  let recent: any[] = [];
  let dims: any[] = [];
  let weekly: any[] = [];

  try {
    const r = await sb.rpc('founder_wellbeing_kpis');
    kpis = (r.data && r.data[0]) ?? null;
  } catch {}
  try {
    const r = await sb.rpc('founder_wellbeing_cycles_list');
    cycles = r.data ?? [];
  } catch {}
  try {
    const r = await sb.rpc('founder_wellbeing_red_flags');
    redFlags = r.data ?? [];
  } catch {}
  try {
    const r = await sb.rpc('founder_wellbeing_engineer_trend');
    trend = r.data ?? [];
  } catch {}
  try {
    const r = await sb.rpc('founder_wellbeing_recent_responses');
    recent = r.data ?? [];
  } catch {}
  try {
    const r = await sb.rpc('founder_wellbeing_dimension_breakdown');
    dims = r.data ?? [];
  } catch {}
  try {
    const r = await sb.rpc('founder_wellbeing_weekly_trend');
    weekly = r.data ?? [];
  } catch {}

  const cards: Kpi[] = [
    { label: 'Open Cycles', value: fmt(kpis?.open_cycles ?? 0) },
    { label: 'Total Cycles', value: fmt(kpis?.total_cycles ?? 0) },
    { label: 'Total Responses', value: fmt(kpis?.total_responses ?? 0) },
    { label: 'Responses (30d)', value: fmt(kpis?.responses_30d ?? 0) },
    { label: 'Responses (7d)', value: fmt(kpis?.responses_7d ?? 0) },
    { label: 'Red Flags Total', value: fmt(kpis?.red_flags_total ?? 0) },
    { label: 'Red Flags Open', value: fmt(kpis?.red_flags_open ?? 0) },
    { label: 'Red Flags (7d)', value: fmt(kpis?.red_flags_7d ?? 0) },
    { label: 'Engineers (30d)', value: fmt(kpis?.engineers_responded_30d ?? 0) },
    { label: 'Avg Workload', value: fmtNum(kpis?.avg_workload) },
    { label: 'Avg Support', value: fmtNum(kpis?.avg_support) },
    { label: 'Avg Growth', value: fmtNum(kpis?.avg_growth) },
    { label: 'Avg Burnout Risk', value: fmtNum(kpis?.avg_burnout) },
    { label: 'Avg Joy', value: fmtNum(kpis?.avg_joy) },
    { label: 'Avg Composite', value: fmtNum(kpis?.avg_composite) },
    { label: 'Worst Composite', value: fmtNum(kpis?.worst_composite) },
  ];

  const cycleCols: Column<any>[] = [
    { key: 'cycle_label', header: 'Cycle', render: (r: any) => r.cycle_label ?? '-' },
    { key: 'starts_on', header: 'Starts', render: (r: any) => r.starts_on ?? '-' },
    { key: 'ends_on', header: 'Ends', render: (r: any) => r.ends_on ?? '-' },
    { key: 'is_open', header: 'Open', render: (r: any) => (r.is_open ? 'yes' : 'no') },
    { key: 'response_count', header: 'Responses', render: (r: any) => fmt(r.response_count) },
    { key: 'red_flag_count', header: 'Red Flags', render: (r: any) => fmt(r.red_flag_count) },
    { key: 'avg_composite', header: 'Avg Comp', render: (r: any) => fmtNum(r.avg_composite) },
  ];

  const redCols: Column<any>[] = [
    { key: 'cycle_label', header: 'Cycle', render: (r: any) => r.cycle_label ?? '-' },
    { key: 'engineer_email', header: 'Engineer', render: (r: any) => r.engineer_email ?? '-' },
    { key: 'burnout_risk', header: 'Burnout', render: (r: any) => fmt(r.burnout_risk) },
    { key: 'joy_score', header: 'Joy', render: (r: any) => fmt(r.joy_score) },
    { key: 'composite_score', header: 'Composite', render: (r: any) => fmtNum(r.composite_score) },
    { key: 'reviewed_at', header: 'Reviewed', render: (r: any) => (r.reviewed_at ? 'yes' : 'no') },
    { key: 'submitted_at', header: 'Submitted', render: (r: any) => fmtDate(r.submitted_at) },
  ];

  const trendCols: Column<any>[] = [
    { key: 'engineer_email', header: 'Engineer', render: (r: any) => r.engineer_email ?? '-' },
    { key: 'responses_count', header: 'Responses', render: (r: any) => fmt(r.responses_count) },
    { key: 'avg_composite', header: 'Avg Comp', render: (r: any) => fmtNum(r.avg_composite) },
    { key: 'latest_composite', header: 'Latest Comp', render: (r: any) => fmtNum(r.latest_composite) },
    { key: 'latest_burnout', header: 'Latest Burnout', render: (r: any) => fmt(r.latest_burnout) },
    { key: 'latest_joy', header: 'Latest Joy', render: (r: any) => fmt(r.latest_joy) },
    { key: 'red_flag_count', header: 'Red Flags', render: (r: any) => fmt(r.red_flag_count) },
    { key: 'last_submitted_at', header: 'Last At', render: (r: any) => fmtDate(r.last_submitted_at) },
  ];

  const recentCols: Column<any>[] = [
    { key: 'cycle_label', header: 'Cycle', render: (r: any) => r.cycle_label ?? '-' },
    { key: 'engineer_email', header: 'Engineer', render: (r: any) => r.engineer_email ?? '-' },
    { key: 'workload_score', header: 'WL', render: (r: any) => fmt(r.workload_score) },
    { key: 'support_score', header: 'Sup', render: (r: any) => fmt(r.support_score) },
    { key: 'growth_score', header: 'Gr', render: (r: any) => fmt(r.growth_score) },
    { key: 'burnout_risk', header: 'BO', render: (r: any) => fmt(r.burnout_risk) },
    { key: 'joy_score', header: 'Joy', render: (r: any) => fmt(r.joy_score) },
    { key: 'composite_score', header: 'Comp', render: (r: any) => fmtNum(r.composite_score) },
    { key: 'is_red_flag', header: 'Red', render: (r: any) => (r.is_red_flag ? 'yes' : 'no') },
    { key: 'submitted_at', header: 'At', render: (r: any) => fmtDate(r.submitted_at) },
  ];

  const dimCols: Column<any>[] = [
    { key: 'dimension', header: 'Dimension', render: (r: any) => r.dimension ?? '-' },
    { key: 'avg_score', header: 'Avg', render: (r: any) => fmtNum(r.avg_score) },
    { key: 'count_1', header: '1', render: (r: any) => fmt(r.count_1) },
    { key: 'count_2', header: '2', render: (r: any) => fmt(r.count_2) },
    { key: 'count_3', header: '3', render: (r: any) => fmt(r.count_3) },
    { key: 'count_4', header: '4', render: (r: any) => fmt(r.count_4) },
    { key: 'count_5', header: '5', render: (r: any) => fmt(r.count_5) },
    { key: 'total_responses', header: 'Total', render: (r: any) => fmt(r.total_responses) },
  ];

  const weeklyCols: Column<any>[] = [
    { key: 'week_start', header: 'Week', render: (r: any) => r.week_start ?? '-' },
    { key: 'responses', header: 'Responses', render: (r: any) => fmt(r.responses) },
    { key: 'red_flags', header: 'Red Flags', render: (r: any) => fmt(r.red_flags) },
    { key: 'avg_composite', header: 'Avg Comp', render: (r: any) => fmtNum(r.avg_composite) },
    { key: 'avg_burnout', header: 'Avg BO', render: (r: any) => fmtNum(r.avg_burnout) },
    { key: 'avg_joy', header: 'Avg Joy', render: (r: any) => fmtNum(r.avg_joy) },
  ];

  return (
    <main style={{ padding: 24, maxWidth: 1400, margin: '0 auto', fontFamily: 'system-ui' }}>
      <h1 style={{ fontSize: 28, fontWeight: 700, marginBottom: 8 }}>Engineer Wellbeing Pulse</h1>
      <p style={{ color: '#666', marginBottom: 24 }}>
        Weekly 5-question pulse: workload, support, growth, burnout-risk, joy. Per-engineer trend; founder review of red flags.
      </p>

      <section style={{ display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)', gap: 12, marginBottom: 32 }}>
        {cards.map((c) => (
          <div key={c.label} style={{ border: '1px solid #e5e5e5', borderRadius: 8, padding: 12, background: '#fafafa' }}>
            <div style={{ fontSize: 11, color: '#666', textTransform: 'uppercase', letterSpacing: 0.5 }}>{c.label}</div>
            <div style={{ fontSize: 20, fontWeight: 600, marginTop: 4 }}>{c.value}</div>
          </div>
        ))}
      </section>

      <h2 style={{ fontSize: 18, fontWeight: 600, margin: '24px 0 12px' }}>Red Flags (open + recent)</h2>
      <DataTable columns={redCols} rows={redFlags} rowKey={(r: any) => r.id} />

      <h2 style={{ fontSize: 18, fontWeight: 600, margin: '24px 0 12px' }}>Per-Engineer Trend (90d)</h2>
      <DataTable columns={trendCols} rows={trend} rowKey={(r: any) => r.engineer_user_id} />

      <h2 style={{ fontSize: 18, fontWeight: 600, margin: '24px 0 12px' }}>Survey Cycles</h2>
      <DataTable columns={cycleCols} rows={cycles} rowKey={(r: any) => r.id} />

      <h2 style={{ fontSize: 18, fontWeight: 600, margin: '24px 0 12px' }}>Dimension Breakdown (30d)</h2>
      <DataTable columns={dimCols} rows={dims} rowKey={(r: any) => r.dimension} />

      <h2 style={{ fontSize: 18, fontWeight: 600, margin: '24px 0 12px' }}>Weekly Trend (12w)</h2>
      <DataTable columns={weeklyCols} rows={weekly} rowKey={(r: any) => String(r.week_start)} />

      <h2 style={{ fontSize: 18, fontWeight: 600, margin: '24px 0 12px' }}>Recent Responses</h2>
      <DataTable columns={recentCols} rows={recent} rowKey={(r: any) => r.id} />
    </main>
  );
}
