import { requireFounder } from '@/lib/auth/requireFounder';
import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type Kpi = { label: string; value: string };

function fmtNum(n: any): string {
  if (n === null || n === undefined) return '—';
  const v = Number(n);
  if (Number.isNaN(v)) return '—';
  return v.toLocaleString('en-IN');
}

function fmtPct(n: any): string {
  if (n === null || n === undefined) return '—';
  return `${Number(n).toFixed(1)}%`;
}

export default async function FounderCofounderOkrAlignmentPage() {
  await requireFounder();
  const sb = await getSupabaseServerClient();

  let kpis: any = {};
  let okrList: any[] = [];
  let perCofounder: any[] = [];
  let depGraph: any[] = [];
  let syncRecent: any[] = [];
  let quarterBreakdown: any[] = [];
  let signals: any[] = [];

  try {
    const r = await sb.rpc('founder_cofounder_okr_kpis');
    kpis = r.data ?? {};
  } catch { kpis = {}; }
  try {
    const r = await sb.rpc('founder_cofounder_okr_list');
    okrList = r.data ?? [];
  } catch { okrList = []; }
  try {
    const r = await sb.rpc('founder_cofounder_per_cofounder_rollup');
    perCofounder = r.data ?? [];
  } catch { perCofounder = []; }
  try {
    const r = await sb.rpc('founder_cofounder_dependency_graph');
    depGraph = r.data ?? [];
  } catch { depGraph = []; }
  try {
    const r = await sb.rpc('founder_cofounder_sync_recent');
    syncRecent = r.data ?? [];
  } catch { syncRecent = []; }
  try {
    const r = await sb.rpc('founder_cofounder_quarter_breakdown');
    quarterBreakdown = r.data ?? [];
  } catch { quarterBreakdown = []; }
  try {
    const r = await sb.rpc('founder_cofounder_misalignment_signals');
    signals = r.data ?? [];
  } catch { signals = []; }

  const kpiCards: Kpi[] = [
    { label: 'Total OKRs', value: fmtNum(kpis.total_okrs) },
    { label: 'Cofounders', value: fmtNum(kpis.cofounder_count) },
    { label: 'On Track', value: fmtNum(kpis.on_track) },
    { label: 'At Risk', value: fmtNum(kpis.at_risk) },
    { label: 'Off Track', value: fmtNum(kpis.off_track) },
    { label: 'Done', value: fmtNum(kpis.done_count) },
    { label: 'With Deps', value: fmtNum(kpis.with_deps) },
    { label: 'Avg Progress', value: fmtPct(kpis.avg_progress_pct) },
    { label: 'Quarters', value: fmtNum(kpis.quarters_tracked) },
    { label: 'Syncs Logged', value: fmtNum(kpis.sync_count) },
    { label: 'Avg Health', value: kpis.avg_health ? `${Number(kpis.avg_health).toFixed(1)}/10` : '—' },
    { label: 'Last Sync', value: kpis.last_sync ?? '—' },
    { label: 'Syncs 30d', value: fmtNum(kpis.syncs_30d) },
    { label: 'Low Health', value: fmtNum(kpis.low_health_syncs) },
    { label: 'Alignment Score', value: fmtPct(kpis.alignment_score) },
    { label: 'Dep Density', value: fmtPct(kpis.dep_density_pct) },
  ];

  const okrCols: Column<any>[] = [
    { key: 'cofounder_name', header: 'Cofounder', render: (r: any) => r.cofounder_name ?? '—' },
    { key: 'cofounder_role', header: 'Role', render: (r: any) => r.cofounder_role ?? '—' },
    { key: 'quarter', header: 'Quarter', render: (r: any) => r.quarter ?? '—' },
    { key: 'objective', header: 'Objective', render: (r: any) => r.objective ?? '—' },
    { key: 'key_result', header: 'Key Result', render: (r: any) => r.key_result ?? '—' },
    { key: 'progress_pct', header: 'Progress', render: (r: any) => fmtPct(r.progress_pct) },
    { key: 'status', header: 'Status', render: (r: any) => r.status ?? '—' },
    { key: 'weight_pct', header: 'Weight', render: (r: any) => fmtPct(r.weight_pct) },
  ];

  const rollupCols: Column<any>[] = [
    { key: 'cofounder_name', header: 'Cofounder', render: (r: any) => r.cofounder_name ?? '—' },
    { key: 'cofounder_role', header: 'Role', render: (r: any) => r.cofounder_role ?? '—' },
    { key: 'okr_count', header: 'OKRs', render: (r: any) => fmtNum(r.okr_count) },
    { key: 'on_track', header: 'On Track', render: (r: any) => fmtNum(r.on_track) },
    { key: 'at_risk', header: 'At Risk', render: (r: any) => fmtNum(r.at_risk) },
    { key: 'off_track', header: 'Off Track', render: (r: any) => fmtNum(r.off_track) },
    { key: 'done_count', header: 'Done', render: (r: any) => fmtNum(r.done_count) },
    { key: 'avg_progress', header: 'Avg Progress', render: (r: any) => fmtPct(r.avg_progress) },
    { key: 'total_weight', header: 'Total Weight', render: (r: any) => fmtPct(r.total_weight) },
  ];

  const depCols: Column<any>[] = [
    { key: 'dependent_name', header: 'Dependent', render: (r: any) => r.dependent_name ?? '—' },
    { key: 'dependent_okr', header: 'Their OKR', render: (r: any) => r.dependent_okr ?? '—' },
    { key: 'parent_name', header: 'Depends On', render: (r: any) => r.parent_name ?? '—' },
    { key: 'parent_okr', header: 'Parent OKR', render: (r: any) => r.parent_okr ?? '—' },
    { key: 'parent_status', header: 'Parent Status', render: (r: any) => r.parent_status ?? '—' },
    { key: 'risk_flag', header: 'Risk', render: (r: any) => r.risk_flag ?? '—' },
  ];

  const syncCols: Column<any>[] = [
    { key: 'sync_date', header: 'Date', render: (r: any) => r.sync_date ?? '—' },
    { key: 'week_label', header: 'Week', render: (r: any) => r.week_label ?? '—' },
    { key: 'attendee_count', header: 'Attendees', render: (r: any) => fmtNum(r.attendee_count) },
    { key: 'health_score', header: 'Health', render: (r: any) => r.health_score ? `${r.health_score}/10` : '—' },
    { key: 'topics_preview', header: 'Topics', render: (r: any) => r.topics_preview ?? '—' },
    { key: 'blockers_preview', header: 'Blockers', render: (r: any) => r.blockers_preview ?? '—' },
    { key: 'days_since', header: 'Days Ago', render: (r: any) => fmtNum(r.days_since) },
  ];

  const quarterCols: Column<any>[] = [
    { key: 'quarter', header: 'Quarter', render: (r: any) => r.quarter ?? '—' },
    { key: 'okr_count', header: 'OKRs', render: (r: any) => fmtNum(r.okr_count) },
    { key: 'avg_progress', header: 'Avg Progress', render: (r: any) => fmtPct(r.avg_progress) },
    { key: 'on_track', header: 'On Track', render: (r: any) => fmtNum(r.on_track) },
    { key: 'off_track', header: 'Off Track', render: (r: any) => fmtNum(r.off_track) },
    { key: 'done_count', header: 'Done', render: (r: any) => fmtNum(r.done_count) },
  ];

  const signalCols: Column<any>[] = [
    { key: 'signal_kind', header: 'Signal', render: (r: any) => r.signal_kind ?? '—' },
    { key: 'severity', header: 'Severity', render: (r: any) => r.severity ?? '—' },
    { key: 'detail', header: 'Detail', render: (r: any) => r.detail ?? '—' },
  ];

  return (
    <div style={{ padding: '24px', maxWidth: '1400px', margin: '0 auto' }}>
      <h1 style={{ fontSize: '24px', fontWeight: 700, marginBottom: '8px' }}>Cofounder OKR Alignment</h1>
      <p style={{ color: '#666', marginBottom: '24px' }}>
        Per-cofounder OKR sets, dependency graph, and weekly sync log. r1606.
      </p>

      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(180px, 1fr))', gap: '12px', marginBottom: '32px' }}>
        {kpiCards.map((k) => (
          <div key={k.label} style={{ border: '1px solid #e5e7eb', borderRadius: '8px', padding: '12px', background: '#fff' }}>
            <div style={{ fontSize: '12px', color: '#6b7280', textTransform: 'uppercase', letterSpacing: '0.04em' }}>{k.label}</div>
            <div style={{ fontSize: '20px', fontWeight: 600, marginTop: '4px' }}>{k.value}</div>
          </div>
        ))}
      </div>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '18px', fontWeight: 600, marginBottom: '12px' }}>OKR List</h2>
        <DataTable rows={okrList} columns={okrCols} rowKey={(r: any) => r.id} />
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '18px', fontWeight: 600, marginBottom: '12px' }}>Per-Cofounder Rollup</h2>
        <DataTable rows={perCofounder} columns={rollupCols} rowKey={(r: any) => r.id} />
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '18px', fontWeight: 600, marginBottom: '12px' }}>Dependency Graph</h2>
        <DataTable rows={depGraph} columns={depCols} rowKey={(r: any) => r.id} />
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '18px', fontWeight: 600, marginBottom: '12px' }}>Weekly Sync Log</h2>
        <DataTable rows={syncRecent} columns={syncCols} rowKey={(r: any) => r.id} />
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '18px', fontWeight: 600, marginBottom: '12px' }}>Quarter Breakdown</h2>
        <DataTable rows={quarterBreakdown} columns={quarterCols} rowKey={(r: any) => r.id} />
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '18px', fontWeight: 600, marginBottom: '12px' }}>Misalignment Signals</h2>
        <DataTable rows={signals} columns={signalCols} rowKey={(r: any) => r.id} />
      </section>
    </div>
  );
}
