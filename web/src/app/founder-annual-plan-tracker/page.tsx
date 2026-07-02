import { requireFounder } from '@/lib/auth/requireFounder';
import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type Kpi = { label: string; value: string };

function Card({ label, value }: Kpi) {
  return (
    <div style={{ border: '1px solid #e5e7eb', borderRadius: 8, padding: 12, background: '#fff' }}>
      <div style={{ fontSize: 11, color: '#6b7280', textTransform: 'uppercase', letterSpacing: 0.5 }}>{label}</div>
      <div style={{ fontSize: 18, fontWeight: 600, marginTop: 4 }}>{value}</div>
    </div>
  );
}

export default async function FounderAnnualPlanTrackerPage() {
  await requireFounder();
  const sb = await getSupabaseServerClient();

  let overview: any[] = [];
  let current: any = null;
  let pillars: any[] = [];
  let quarters: any[] = [];
  let carryover: any[] = [];
  let healthDist: any[] = [];
  let yearCompare: any[] = [];

  try {
    const r = await sb.rpc('founder_annual_plan_overview');
    overview = (r.data as any[]) ?? [];
  } catch {}

  try {
    const r = await sb.rpc('founder_annual_plan_current');
    const rows = (r.data as any[]) ?? [];
    current = rows[0] ?? null;
  } catch {}

  if (current?.plan_id) {
    try {
      const r = await sb.rpc('founder_annual_plan_pillars_list', { p_plan_id: current.plan_id });
      pillars = (r.data as any[]) ?? [];
    } catch {}
    try {
      const r = await sb.rpc('founder_annual_plan_quarter_summary', { p_plan_id: current.plan_id });
      quarters = (r.data as any[]) ?? [];
    } catch {}
  }

  try {
    const r = await sb.rpc('founder_annual_plan_carryover_candidates', { p_from_year: (current?.plan_year ?? new Date().getFullYear()) - 1 });
    carryover = (r.data as any[]) ?? [];
  } catch {}

  try {
    const r = await sb.rpc('founder_annual_plan_health_distribution');
    healthDist = (r.data as any[]) ?? [];
  } catch {}

  try {
    const r = await sb.rpc('founder_annual_plan_year_compare');
    yearCompare = (r.data as any[]) ?? [];
  } catch {}

  const totalPillars = pillars.length;
  const onTrack = pillars.filter((p: any) => p.health_status === 'on_track').length;
  const atRisk = pillars.filter((p: any) => p.health_status === 'at_risk').length;
  const offTrack = pillars.filter((p: any) => p.health_status === 'off_track').length;
  const done = pillars.filter((p: any) => p.health_status === 'done').length;
  const blocked = pillars.filter((p: any) => p.health_status === 'blocked').length;
  const carriedOver = pillars.filter((p: any) => p.carried_over).length;
  const completionPct = totalPillars > 0 ? Math.round((done * 100) / totalPillars) : 0;
  const quartersDone = quarters.filter((q: any) => q.checkpoint_status === 'done').length;
  const quartersAtRisk = quarters.filter((q: any) => q.checkpoint_status === 'at_risk' || q.checkpoint_status === 'off_track').length;
  const planCount = overview.length;
  const activeYear = current?.plan_year ?? '—';
  const status = current?.status ?? '—';
  const midYearDone = current?.mid_year_refresh_at ? 'Yes' : 'No';
  const carryoverCandidates = carryover.length;
  const totalInitiatives = pillars.reduce((s: number, p: any) => s + (Array.isArray(p.key_initiatives) ? p.key_initiatives.length : 0), 0);

  const kpis: Kpi[] = [
    { label: 'Active Plan Year', value: String(activeYear) },
    { label: 'Plan Status', value: String(status) },
    { label: 'Total Pillars', value: String(totalPillars) },
    { label: 'On Track', value: String(onTrack) },
    { label: 'At Risk', value: String(atRisk) },
    { label: 'Off Track', value: String(offTrack) },
    { label: 'Done', value: String(done) },
    { label: 'Blocked', value: String(blocked) },
    { label: 'Completion %', value: `${completionPct}%` },
    { label: 'Initiatives Logged', value: String(totalInitiatives) },
    { label: 'Quarters Done', value: `${quartersDone}/4` },
    { label: 'Quarters At/Off-Risk', value: String(quartersAtRisk) },
    { label: 'Mid-Year Refresh', value: midYearDone },
    { label: 'Carryover Candidates', value: String(carryoverCandidates) },
    { label: 'Carried Over Pillars', value: String(carriedOver) },
    { label: 'Plans on File', value: String(planCount) },
  ];

  const overviewCols: Column<any>[] = [
    { key: 'plan_year', header: 'Year', render: (r: any) => r.plan_year ?? '—' },
    { key: 'status', header: 'Status', render: (r: any) => r.status ?? '—' },
    { key: 'north_star_metric', header: 'North Star', render: (r: any) => r.north_star_metric ?? '—' },
    { key: 'pillar_count', header: 'Pillars', render: (r: any) => r.pillar_count ?? 0 },
    { key: 'on_track_count', header: 'On Track', render: (r: any) => r.on_track_count ?? 0 },
    { key: 'at_risk_count', header: 'At Risk', render: (r: any) => r.at_risk_count ?? 0 },
    { key: 'off_track_count', header: 'Off Track', render: (r: any) => r.off_track_count ?? 0 },
    { key: 'done_count', header: 'Done', render: (r: any) => r.done_count ?? 0 },
    { key: 'mid_year_refresh_at', header: 'Mid-Year', render: (r: any) => r.mid_year_refresh_at ? new Date(r.mid_year_refresh_at).toLocaleDateString() : '—' },
  ];

  const pillarCols: Column<any>[] = [
    { key: 'pillar_order', header: '#', render: (r: any) => r.pillar_order ?? '—' },
    { key: 'pillar_name', header: 'Pillar', render: (r: any) => r.pillar_name ?? '—' },
    { key: 'goal_statement', header: 'Goal', render: (r: any) => r.goal_statement ?? '—' },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email ?? '—' },
    { key: 'target_metric', header: 'Metric', render: (r: any) => r.target_metric ?? '—' },
    { key: 'progress_pct', header: 'Progress', render: (r: any) => r.progress_pct != null ? `${r.progress_pct}%` : '—' },
    { key: 'health_status', header: 'Health', render: (r: any) => r.health_status ?? '—' },
    { key: 'carried_over', header: 'Carryover', render: (r: any) => r.carried_over ? 'Yes' : 'No' },
    { key: 'key_initiatives', header: 'Initiatives', render: (r: any) => Array.isArray(r.key_initiatives) ? String(r.key_initiatives.length) : '0' },
  ];

  const quarterCols: Column<any>[] = [
    { key: 'quarter', header: 'Quarter', render: (r: any) => r.quarter ?? '—' },
    { key: 'checkpoint_status', header: 'Status', render: (r: any) => r.checkpoint_status ?? '—' },
    { key: 'notes', header: 'Notes', render: (r: any) => r.notes ?? '—' },
  ];

  const carryoverCols: Column<any>[] = [
    { key: 'pillar_name', header: 'Pillar', render: (r: any) => r.pillar_name ?? '—' },
    { key: 'goal_statement', header: 'Goal', render: (r: any) => r.goal_statement ?? '—' },
    { key: 'health_status', header: 'Health', render: (r: any) => r.health_status ?? '—' },
    { key: 'current_value', header: 'Current', render: (r: any) => r.current_value ?? 0 },
    { key: 'target_value', header: 'Target', render: (r: any) => r.target_value ?? '—' },
    { key: 'progress_pct', header: 'Progress', render: (r: any) => r.progress_pct != null ? `${r.progress_pct}%` : '—' },
  ];

  const healthCols: Column<any>[] = [
    { key: 'health_status', header: 'Health', render: (r: any) => r.health_status ?? '—' },
    { key: 'pillar_count', header: 'Pillars', render: (r: any) => r.pillar_count ?? 0 },
    { key: 'share_pct', header: 'Share %', render: (r: any) => r.share_pct != null ? `${r.share_pct}%` : '—' },
  ];

  return (
    <div style={{ padding: 24, maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: 28, fontWeight: 700, marginBottom: 8 }}>Founder Annual Plan Tracker</h1>
      <p style={{ color: '#6b7280', marginBottom: 24 }}>
        Annual planning doc with 4 quarterly checkpoints, per-pillar goals + initiatives, mid-year refresh, carryover from prior year.
      </p>

      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(180px, 1fr))', gap: 12, marginBottom: 32 }}>
        {kpis.map((k) => (
          <Card key={k.label} label={k.label} value={k.value} />
        ))}
      </div>

      {current ? (
        <section style={{ marginBottom: 32, padding: 16, border: '1px solid #e5e7eb', borderRadius: 8, background: '#f9fafb' }}>
          <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>{current.plan_year} Plan — {current.status}</h2>
          <div style={{ color: '#374151', marginBottom: 6 }}><strong>North Star:</strong> {current.north_star_metric ?? '—'}</div>
          <div style={{ color: '#374151', marginBottom: 6 }}><strong>Vision:</strong> {current.vision_statement ?? '—'}</div>
          {current.mid_year_refresh_at ? (
            <div style={{ color: '#374151' }}><strong>Mid-Year Refresh:</strong> {new Date(current.mid_year_refresh_at).toLocaleDateString()} — {current.mid_year_refresh_notes ?? '—'}</div>
          ) : null}
          {current.carryover_from_year ? (
            <div style={{ color: '#374151' }}><strong>Carryover from:</strong> {current.carryover_from_year}</div>
          ) : null}
        </section>
      ) : null}

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Quarterly Checkpoints</h2>
        <DataTable<any> rows={quarters} columns={quarterCols} rowKey={(r: any) => r.quarter} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Pillars (Current Plan)</h2>
        <DataTable<any> rows={pillars} columns={pillarCols} rowKey={(r: any) => r.id} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Carryover Candidates (Prior Year At-Risk / Off-Track)</h2>
        <DataTable<any> rows={carryover} columns={carryoverCols} rowKey={(r: any) => r.pillar_id} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Health Distribution</h2>
        <DataTable<any> rows={healthDist} columns={healthCols} rowKey={(r: any) => r.health_status} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>All Plans (Year Overview)</h2>
        <DataTable<any> rows={overview} columns={overviewCols} rowKey={(r: any) => r.plan_id} />
      </section>
    </div>
  );
}
