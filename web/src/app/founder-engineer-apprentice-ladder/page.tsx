import { requireFounder } from '@/lib/auth/requireFounder';
import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type Kpi = { label: string; value: string };

function fmt(n: any): string {
  if (n === null || n === undefined) return '—';
  if (typeof n === 'number') return Number.isFinite(n) ? n.toLocaleString('en-IN') : '—';
  return String(n);
}

function fmtNum(n: any, digits = 1): string {
  const v = typeof n === 'number' ? n : Number(n);
  if (!Number.isFinite(v)) return '—';
  return v.toFixed(digits);
}

export default async function FounderEngineerApprenticeLadderPage() {
  await requireFounder();
  const sb = await getSupabaseServerClient();

  let kpis: any = null;
  let pairings: any[] = [];
  let masters: any[] = [];
  let grads: any[] = [];
  let funnel: any[] = [];
  let overdue: any[] = [];

  try {
    const r = await sb.rpc('founder_apprentice_kpis');
    kpis = (r.data && r.data[0]) ?? null;
  } catch {}
  try {
    const r = await sb.rpc('founder_apprentice_pairings_list');
    pairings = r.data ?? [];
  } catch {}
  try {
    const r = await sb.rpc('founder_apprentice_masters_scoreboard');
    masters = r.data ?? [];
  } catch {}
  try {
    const r = await sb.rpc('founder_apprentice_grad_candidates');
    grads = r.data ?? [];
  } catch {}
  try {
    const r = await sb.rpc('founder_apprentice_weekly_funnel');
    funnel = r.data ?? [];
  } catch {}
  try {
    const r = await sb.rpc('founder_apprentice_overdue');
    overdue = r.data ?? [];
  } catch {}

  const k: Kpi[] = [
    { label: 'Total pairings',        value: fmt(kpis?.total_pairings) },
    { label: 'Active',                value: fmt(kpis?.active_pairings) },
    { label: 'Paused',                value: fmt(kpis?.paused_pairings) },
    { label: 'Graduated',             value: fmt(kpis?.graduated_pairings) },
    { label: 'Dropped',               value: fmt(kpis?.dropped_pairings) },
    { label: 'Unique masters',        value: fmt(kpis?.unique_masters) },
    { label: 'Unique apprentices',    value: fmt(kpis?.unique_apprentices) },
    { label: 'Overdue pairings',      value: fmt(kpis?.overdue_pairings) },
    { label: 'Avg days in program',   value: fmtNum(kpis?.avg_days_in_program, 1) },
    { label: 'Avg days to graduate',  value: fmtNum(kpis?.avg_days_to_graduate, 1) },
    { label: 'Jobs shadowed',         value: fmt(kpis?.total_jobs_shadowed) },
    { label: 'Jobs assisted',         value: fmt(kpis?.total_jobs_assisted) },
    { label: 'Jobs solo',             value: fmt(kpis?.total_jobs_solo) },
    { label: 'Milestones complete',   value: fmt(kpis?.milestones_completed) },
    { label: 'Milestones pending',    value: fmt(kpis?.milestones_pending) },
    { label: 'Pct milestones done',   value: (kpis?.pct_milestones_complete ?? '—') + '%' },
  ];

  const pairingsCols: Column<any>[] = [
    { key: 'apprentice_name', header: 'Apprentice', render: (r: any) => r.apprentice_name ?? '—' },
    { key: 'master_name',     header: 'Master',     render: (r: any) => r.master_name ?? '—' },
    { key: 'status',          header: 'Status',     render: (r: any) => r.status ?? '—' },
    { key: 'days_elapsed',    header: 'Days in',    render: (r: any) => fmtNum(r.days_elapsed, 1) },
    { key: 'days_remaining',  header: 'Days left',  render: (r: any) => fmtNum(r.days_remaining, 1) },
    { key: 'jobs_shadowed',   header: 'Shadow',     render: (r: any) => fmt(r.jobs_shadowed) },
    { key: 'jobs_assisted',   header: 'Assist',     render: (r: any) => fmt(r.jobs_assisted) },
    { key: 'jobs_solo',       header: 'Solo',       render: (r: any) => fmt(r.jobs_solo) },
  ];

  const mastersCols: Column<any>[] = [
    { key: 'master_name',                header: 'Master',     render: (r: any) => r.master_name ?? '—' },
    { key: 'active_apprentices',         header: 'Active',     render: (r: any) => fmt(r.active_apprentices) },
    { key: 'graduated_apprentices',      header: 'Graduated',  render: (r: any) => fmt(r.graduated_apprentices) },
    { key: 'total_jobs_with_apprentice', header: 'Co-jobs',    render: (r: any) => fmt(r.total_jobs_with_apprentice) },
    { key: 'avg_milestone_pct',          header: 'Avg ms %',   render: (r: any) => fmtNum(r.avg_milestone_pct, 1) },
  ];

  const gradsCols: Column<any>[] = [
    { key: 'apprentice_name',  header: 'Apprentice', render: (r: any) => r.apprentice_name ?? '—' },
    { key: 'master_name',      header: 'Master',     render: (r: any) => r.master_name ?? '—' },
    { key: 'days_in_program',  header: 'Days',       render: (r: any) => fmtNum(r.days_in_program, 1) },
    { key: 'milestones_done',  header: 'Done',       render: (r: any) => fmt(r.milestones_done) },
    { key: 'milestones_total', header: 'Total',      render: (r: any) => fmt(r.milestones_total) },
    { key: 'jobs_solo',        header: 'Solo',       render: (r: any) => fmt(r.jobs_solo) },
    { key: 'ready',            header: 'Ready',      render: (r: any) => (r.ready ? 'YES' : 'no') },
  ];

  const funnelCols: Column<any>[] = [
    { key: 'week_start', header: 'Week',      render: (r: any) => String(r.week_start ?? '—') },
    { key: 'started',   header: 'Started',    render: (r: any) => fmt(r.started) },
    { key: 'graduated', header: 'Graduated',  render: (r: any) => fmt(r.graduated) },
    { key: 'dropped',   header: 'Dropped',    render: (r: any) => fmt(r.dropped) },
  ];

  const overdueCols: Column<any>[] = [
    { key: 'apprentice_name',    header: 'Apprentice', render: (r: any) => r.apprentice_name ?? '—' },
    { key: 'master_name',        header: 'Master',     render: (r: any) => r.master_name ?? '—' },
    { key: 'days_overdue',       header: 'Days over',  render: (r: any) => fmtNum(r.days_overdue, 1) },
    { key: 'pending_milestones', header: 'Pending ms', render: (r: any) => fmt(r.pending_milestones) },
  ];

  return (
    <main style={{ padding: 24, fontFamily: 'system-ui, sans-serif' }}>
      <h1 style={{ fontSize: 24, fontWeight: 700 }}>Engineer Apprentice Ladder</h1>
      <p style={{ color: '#555', marginTop: 4 }}>
        Apprentices learn under masters across a 6-month curriculum. Per-pair milestone progress and graduation gating.
      </p>

      <section style={{ display: 'grid', gridTemplateColumns: 'repeat(4, minmax(0,1fr))', gap: 12, marginTop: 16 }}>
        {k.map((kpi) => (
          <div key={kpi.label} style={{ border: '1px solid #e5e7eb', borderRadius: 8, padding: 12 }}>
            <div style={{ fontSize: 12, color: '#666' }}>{kpi.label}</div>
            <div style={{ fontSize: 20, fontWeight: 600 }}>{kpi.value}</div>
          </div>
        ))}
      </section>

      <section style={{ marginTop: 24 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600 }}>Active pairings</h2>
        <DataTable rows={pairings} columns={pairingsCols} rowKey={(r: any) => r.id} />
      </section>

      <section style={{ marginTop: 24 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600 }}>Master scoreboard</h2>
        <DataTable rows={masters} columns={mastersCols} rowKey={(r: any) => r.master_engineer_id} />
      </section>

      <section style={{ marginTop: 24 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600 }}>Graduation candidates</h2>
        <DataTable rows={grads} columns={gradsCols} rowKey={(r: any) => r.pairing_id} />
      </section>

      <section style={{ marginTop: 24 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600 }}>Weekly cohort funnel (12w)</h2>
        <DataTable rows={funnel} columns={funnelCols} rowKey={(r: any) => String(r.week_start)} />
      </section>

      <section style={{ marginTop: 24 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600 }}>Overdue pairings</h2>
        <DataTable rows={overdue} columns={overdueCols} rowKey={(r: any) => r.pairing_id} />
      </section>
    </main>
  );
}
