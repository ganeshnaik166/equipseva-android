import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type StatusRow = {
  readiness_status: string;
  entries: number;
  avg_readiness_pct: number;
  pct: number;
};
type WaveRow = {
  launch_wave: string;
  entries: number;
  on_track: number;
  ahead: number;
  at_risk: number;
  blocked: number;
  launched: number;
  avg_readiness_pct: number;
  avg_hiring_pct: number;
};
type MatrixRow = {
  workstream: string;
  readiness_status: string;
  entries: number;
  avg_readiness_pct: number;
  worsening: number;
};
type TrendRow = {
  period_month: string;
  entries: number;
  avg_readiness_pct: number;
  avg_hiring_pct: number;
  at_risk: number;
  blocked: number;
  launched: number;
};
type CapaRow = {
  capa_status: string;
  findings: number;
  avg_delay_impact_days: number;
  overdue_flag: number;
};
type CauseRow = {
  root_cause: string;
  occurrences: number;
  total_delay_days: number;
  pct: number;
};
type BlockerRow = {
  finding_category: string;
  findings: number;
  open_findings: number;
  total_delay_days: number;
};
type RiskRow = {
  city_name: string;
  entry_ref: string;
  launch_wave: string;
  workstream: string;
  target_launch_date: string;
  days_to_launch: number | null;
  readiness_pct: number | null;
  readiness_status: string;
  trend_dir: string | null;
  notes: string | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    statusRes,
    waveRes,
    matrixRes,
    trendRes,
    capaRes,
    causeRes,
    blockerRes,
    riskRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3704_readiness_status_rollup'),
    supabase.rpc('founder_r3704_launch_wave_scorecard'),
    supabase.rpc('founder_r3704_workstream_status_matrix'),
    supabase.rpc('founder_r3704_monthly_readiness_trend'),
    supabase.rpc('founder_r3704_capa_status_board'),
    supabase.rpc('founder_r3704_root_cause_pareto'),
    supabase.rpc('founder_r3704_blocker_digest'),
    supabase.rpc('founder_r3704_high_risk_queue'),
  ]);

  const statusRows: StatusRow[] = (statusRes.data as StatusRow[]) ?? [];
  const waveRows: WaveRow[] = (waveRes.data as WaveRow[]) ?? [];
  const matrixRows: MatrixRow[] = (matrixRes.data as MatrixRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const blockerRows: BlockerRow[] = (blockerRes.data as BlockerRow[]) ?? [];
  const riskRows: RiskRow[] = (riskRes.data as RiskRow[]) ?? [];

  const statusCols: Column<StatusRow>[] = [
    { key: 'readiness_status', header: 'Readiness Status' },
    { key: 'entries', header: 'Entries' },
    { key: 'avg_readiness_pct', header: 'Avg Readiness %' },
    { key: 'pct', header: 'Share %' },
  ];

  const waveCols: Column<WaveRow>[] = [
    { key: 'launch_wave', header: 'Launch Wave' },
    { key: 'entries', header: 'Entries' },
    { key: 'on_track', header: 'On Track' },
    { key: 'ahead', header: 'Ahead' },
    { key: 'at_risk', header: 'At Risk' },
    { key: 'blocked', header: 'Blocked' },
    { key: 'launched', header: 'Launched' },
    { key: 'avg_readiness_pct', header: 'Avg Readiness %' },
    { key: 'avg_hiring_pct', header: 'Avg Hiring %' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'workstream', header: 'Workstream' },
    { key: 'readiness_status', header: 'Readiness Status' },
    { key: 'entries', header: 'Entries' },
    { key: 'avg_readiness_pct', header: 'Avg Readiness %' },
    { key: 'worsening', header: 'Worsening' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'period_month', header: 'Month' },
    { key: 'entries', header: 'Entries' },
    { key: 'avg_readiness_pct', header: 'Avg Readiness %' },
    { key: 'avg_hiring_pct', header: 'Avg Hiring %' },
    { key: 'at_risk', header: 'At Risk' },
    { key: 'blocked', header: 'Blocked' },
    { key: 'launched', header: 'Launched' },
  ];

  const capaCols: Column<CapaRow>[] = [
    { key: 'capa_status', header: 'CAPA Status' },
    { key: 'findings', header: 'Findings' },
    { key: 'avg_delay_impact_days', header: 'Avg Delay Impact (days)' },
    { key: 'overdue_flag', header: 'Overdue / Escalated' },
  ];

  const causeCols: Column<CauseRow>[] = [
    { key: 'root_cause', header: 'Root Cause' },
    { key: 'occurrences', header: 'Occurrences' },
    { key: 'total_delay_days', header: 'Total Delay (days)' },
    { key: 'pct', header: 'Share %' },
  ];

  const blockerCols: Column<BlockerRow>[] = [
    { key: 'finding_category', header: 'Blocker Category' },
    { key: 'findings', header: 'Findings' },
    { key: 'open_findings', header: 'Open' },
    { key: 'total_delay_days', header: 'Total Delay (days)' },
  ];

  const riskCols: Column<RiskRow>[] = [
    { key: 'city_name', header: 'City' },
    { key: 'entry_ref', header: 'Entry Ref' },
    { key: 'launch_wave', header: 'Wave' },
    { key: 'workstream', header: 'Workstream' },
    { key: 'target_launch_date', header: 'Target Launch' },
    { key: 'days_to_launch', header: 'Days to Launch' },
    { key: 'readiness_pct', header: 'Readiness %' },
    { key: 'readiness_status', header: 'Status' },
    { key: 'trend_dir', header: 'Trend' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        New-City Market-Entry / Launch-Readiness Board
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        New-city market-entry launch readiness — city &times; launch wave &times; engineer hiring
        (hired vs target) &times; demand pipeline (hospitals prospected &amp; anchor accounts)
        &times; statutory registrations % &times; warehouse readiness &times; readiness % &times;
        workstream status &amp; CAPA closure. Founder-gated view: readiness-status rollups,
        launch-wave scorecards, workstream matrices, root-cause pareto, and the blocked /
        at-risk city queue for go-live calls.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Readiness-status distribution</h2>
        <DataTable
          rows={statusRows}
          columns={statusCols}
          emptyMessage="No launch-readiness entries logged yet."
          rowKey={(r, i) => String(r.readiness_status ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Launch-wave scorecard</h2>
        <DataTable
          rows={waveRows}
          columns={waveCols}
          emptyMessage="No launch-wave rollups."
          rowKey={(r, i) => String(r.launch_wave ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Workstream &times; readiness-status matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No entries by workstream."
          rowKey={(r, i) => `${r.workstream}-${r.readiness_status}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Monthly readiness trend</h2>
        <DataTable
          rows={trendRows}
          columns={trendCols}
          emptyMessage="No trend data."
          rowKey={(r, i) => String(r.period_month ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>5. CAPA status board</h2>
        <DataTable
          rows={capaRows}
          columns={capaCols}
          emptyMessage="No CAPA findings."
          rowKey={(r, i) => String(r.capa_status ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>6. Root cause pareto</h2>
        <DataTable
          rows={causeRows}
          columns={causeCols}
          emptyMessage="No root-cause data."
          rowKey={(r, i) => String(r.root_cause ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>7. Blocker digest</h2>
        <DataTable
          rows={blockerRows}
          columns={blockerCols}
          emptyMessage="No blocker rollups."
          rowKey={(r, i) => String(r.finding_category ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk city queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No blocked or at-risk entries."
          rowKey={(r, i) => `${r.entry_ref}-${i}`}
        />
      </section>
    </main>
  );
}
