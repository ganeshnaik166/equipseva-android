import { requireFounder } from '@/lib/auth/requireFounder';
import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type Kpi = { label: string; value: string };

function fmtInt(n: any): string {
  const v = Number(n ?? 0);
  return Number.isFinite(v) ? v.toLocaleString('en-IN') : '0';
}
function fmtRupees(n: any): string {
  const v = Number(n ?? 0);
  return '₹' + (Number.isFinite(v) ? v.toLocaleString('en-IN') : '0');
}
function fmtNum(n: any, d = 2): string {
  const v = Number(n ?? 0);
  return Number.isFinite(v) ? v.toFixed(d) : '0';
}

export default async function FounderEngineerDispatchDensityPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();

  let kpis: any = {};
  let grid: any[] = [];
  let hot: any[] = [];
  let cold: any[] = [];
  let states: any[] = [];
  let snaps: any[] = [];
  let prompts: any[] = [];

  try {
    const r = await supabase.rpc('founder_dispatch_density_kpis');
    kpis = (r.data && r.data[0]) || {};
  } catch { kpis = {}; }
  try {
    const r = await supabase.rpc('founder_dispatch_density_grid');
    grid = r.data || [];
  } catch { grid = []; }
  try {
    const r = await supabase.rpc('founder_dispatch_hot_windows');
    hot = r.data || [];
  } catch { hot = []; }
  try {
    const r = await supabase.rpc('founder_dispatch_cold_windows');
    cold = r.data || [];
  } catch { cold = []; }
  try {
    const r = await supabase.rpc('founder_dispatch_state_summary');
    states = r.data || [];
  } catch { states = []; }
  try {
    const r = await supabase.rpc('founder_dispatch_recent_snapshots');
    snaps = r.data || [];
  } catch { snaps = []; }
  try {
    const r = await supabase.rpc('founder_dispatch_ot_bonus_prompts');
    prompts = r.data || [];
  } catch { prompts = []; }

  const kpiCards: Kpi[] = [
    { label: 'Jobs Assigned (7d)', value: fmtInt(kpis.total_jobs_7d) },
    { label: 'Jobs Assigned (24h)', value: fmtInt(kpis.total_jobs_24h) },
    { label: 'Hot Windows', value: fmtInt(kpis.hot_window_count) },
    { label: 'Cold Windows', value: fmtInt(kpis.cold_window_count) },
    { label: 'States Covered', value: fmtInt(kpis.states_covered) },
    { label: 'Total Engineers', value: fmtInt(kpis.total_engineers) },
    { label: 'Avg Density', value: fmtNum(kpis.avg_density) + '%' },
    { label: 'Max Density', value: fmtNum(kpis.max_density) + '%' },
    { label: 'OT Prompts Pending', value: fmtInt(kpis.bonus_prompts_pending) },
    { label: 'OT Prompts Sent', value: fmtInt(kpis.bonus_prompts_sent) },
    { label: 'Bonus Committed', value: fmtRupees(kpis.bonus_rupees_committed) },
    { label: 'Snapshots Total', value: fmtInt(kpis.snapshots_total) },
    { label: 'Grid Cells', value: fmtInt(grid.length) },
    { label: 'State Rows', value: fmtInt(states.length) },
    { label: 'Hot Rows', value: fmtInt(hot.length) },
    { label: 'Cold Rows', value: fmtInt(cold.length) },
  ];

  const gridCols: Column<any>[] = [
    { key: 'state_code', header: 'State', render: (r: any) => r.state_code ?? '—' },
    { key: 'hour_of_day', header: 'Hour', render: (r: any) => String(r.hour_of_day ?? '—') + ':00' },
    { key: 'jobs_assigned', header: 'Jobs', render: (r: any) => fmtInt(r.jobs_assigned) },
    { key: 'density_score', header: 'Density %', render: (r: any) => fmtNum(r.density_score) },
    { key: 'band', header: 'Band', render: (r: any) => r.band ?? '—' },
  ];

  const hotCols: Column<any>[] = [
    { key: 'state_code', header: 'State', render: (r: any) => r.state_code ?? '—' },
    { key: 'hour_of_day', header: 'Hour', render: (r: any) => String(r.hour_of_day ?? '—') + ':00' },
    { key: 'jobs_assigned', header: 'Jobs', render: (r: any) => fmtInt(r.jobs_assigned) },
    { key: 'density_score', header: 'Density %', render: (r: any) => fmtNum(r.density_score) },
    { key: 'active_engineers', header: 'Active Eng', render: (r: any) => fmtInt(r.active_engineers) },
    { key: 'jobs_per_engineer', header: 'Jobs/Eng', render: (r: any) => fmtNum(r.jobs_per_engineer) },
  ];

  const coldCols: Column<any>[] = [
    { key: 'state_code', header: 'State', render: (r: any) => r.state_code ?? '—' },
    { key: 'hour_of_day', header: 'Hour', render: (r: any) => String(r.hour_of_day ?? '—') + ':00' },
    { key: 'jobs_assigned', header: 'Jobs', render: (r: any) => fmtInt(r.jobs_assigned) },
    { key: 'density_score', header: 'Density %', render: (r: any) => fmtNum(r.density_score) },
    { key: 'idle_engineers', header: 'Idle Eng', render: (r: any) => fmtInt(r.idle_engineers) },
  ];

  const stateCols: Column<any>[] = [
    { key: 'state_code', header: 'State', render: (r: any) => r.state_code ?? '—' },
    { key: 'total_jobs', header: 'Total Jobs', render: (r: any) => fmtInt(r.total_jobs) },
    { key: 'total_engineers', header: 'Engineers', render: (r: any) => fmtInt(r.total_engineers) },
    { key: 'avg_jobs_per_hour', header: 'Avg/Hour', render: (r: any) => fmtNum(r.avg_jobs_per_hour) },
    { key: 'peak_hour', header: 'Peak Hour', render: (r: any) => String(r.peak_hour ?? '—') + ':00' },
    { key: 'peak_jobs', header: 'Peak Jobs', render: (r: any) => fmtInt(r.peak_jobs) },
  ];

  const promptCols: Column<any>[] = [
    { key: 'created_at', header: 'Created', render: (r: any) => r.created_at ? new Date(r.created_at).toLocaleString('en-IN') : '—' },
    { key: 'state_code', header: 'State', render: (r: any) => r.state_code ?? '—' },
    { key: 'hour_of_day', header: 'Hour', render: (r: any) => String(r.hour_of_day ?? '—') + ':00' },
    { key: 'density_score', header: 'Density %', render: (r: any) => fmtNum(r.density_score) },
    { key: 'bonus_rupees', header: 'Bonus', render: (r: any) => fmtRupees(r.bonus_rupees) },
    { key: 'status', header: 'Status', render: (r: any) => r.status ?? '—' },
    { key: 'age_days', header: 'Age (d)', render: (r: any) => fmtNum(r.age_days) },
  ];

  return (
    <main style={{ padding: 24, fontFamily: 'system-ui, sans-serif' }}>
      <h1 style={{ fontSize: 26, fontWeight: 700, marginBottom: 4 }}>
        Engineer Dispatch Density Heatmap
      </h1>
      <p style={{ color: '#555', marginBottom: 20 }}>
        Per-state per-hour dispatch density. Identify under-capacity hot windows and over-capacity cold windows. Spawn overtime bonus prompts for hot windows. (r1497)
      </p>

      <section style={{ display: 'grid', gridTemplateColumns: 'repeat(4, minmax(0,1fr))', gap: 12, marginBottom: 28 }}>
        {kpiCards.map((k) => (
          <div key={k.label} style={{ border: '1px solid #e5e7eb', borderRadius: 8, padding: 12, background: '#fff' }}>
            <div style={{ fontSize: 11, textTransform: 'uppercase', color: '#6b7280', letterSpacing: 0.4 }}>{k.label}</div>
            <div style={{ fontSize: 20, fontWeight: 600, marginTop: 4 }}>{k.value}</div>
          </div>
        ))}
      </section>

      <h2 style={{ fontSize: 18, fontWeight: 600, marginTop: 20, marginBottom: 8 }}>Density Grid (state x hour)</h2>
      <DataTable rows={grid} columns={gridCols} rowKey={(r: any) => r.id} />

      <h2 style={{ fontSize: 18, fontWeight: 600, marginTop: 24, marginBottom: 8 }}>Hot Windows (under-capacity)</h2>
      <DataTable rows={hot} columns={hotCols} rowKey={(r: any) => r.id} />

      <h2 style={{ fontSize: 18, fontWeight: 600, marginTop: 24, marginBottom: 8 }}>Cold Windows (over-capacity)</h2>
      <DataTable rows={cold} columns={coldCols} rowKey={(r: any) => r.id} />

      <h2 style={{ fontSize: 18, fontWeight: 600, marginTop: 24, marginBottom: 8 }}>State Capacity Summary</h2>
      <DataTable rows={states} columns={stateCols} rowKey={(r: any) => r.id} />

      <h2 style={{ fontSize: 18, fontWeight: 600, marginTop: 24, marginBottom: 8 }}>Overtime Bonus Prompts</h2>
      <DataTable rows={prompts} columns={promptCols} rowKey={(r: any) => r.id} />
    </main>
  );
}
