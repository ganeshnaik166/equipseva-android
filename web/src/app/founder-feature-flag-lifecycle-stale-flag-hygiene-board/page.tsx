import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type StatusRow = { lifecycle_status: string; flags: number; pct: number };
type TeamRow = {
  owning_team: string;
  total_flags: number;
  active_managed: number;
  fully_rolled_out: number;
  stale_flags: number;
  zombie_flags: number;
  cleanup_overdue_flags: number;
  kill_switches: number;
  avg_age_days: number;
  hygiene_pct: number;
};
type MatrixRow = {
  flag_class: string;
  lifecycle_status: string;
  flags: number;
  avg_age_days: number;
  avg_rollout_pct: number;
};
type TrendRow = {
  period_month: string;
  flags: number;
  avg_age_days: number;
  stale_plus: number;
  cleanup_tickets_open: number;
  avg_evaluations_30d: number;
};
type CapaRow = {
  capa_status: string;
  actions: number;
  avg_hours_est: number;
  overdue_flag: number;
};
type CauseRow = {
  root_cause: string;
  occurrences: number;
  total_hours_est: number;
  pct: number;
};
type DigestRow = {
  trend_dir: string;
  flags: number;
  stale_flags: number;
  zombie_flags: number;
  cleanup_overdue_flags: number;
  avg_age_days: number;
  total_code_references: number;
};
type RiskRow = {
  flag_name: string;
  owning_team: string;
  flag_class: string;
  lifecycle_status: string;
  age_days: number;
  rollout_pct: number | null;
  evaluations_30d: number;
  code_references: number;
  cleanup_ticket_open: boolean;
  trend_dir: string;
  notes: string | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    statusRes,
    teamRes,
    matrixRes,
    trendRes,
    capaRes,
    causeRes,
    digestRes,
    riskRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3702_lifecycle_status_rollup'),
    supabase.rpc('founder_r3702_owning_team_scorecard'),
    supabase.rpc('founder_r3702_flag_class_lifecycle_matrix'),
    supabase.rpc('founder_r3702_monthly_flag_age_trend'),
    supabase.rpc('founder_r3702_capa_status_board'),
    supabase.rpc('founder_r3702_root_cause_pareto'),
    supabase.rpc('founder_r3702_stale_flag_digest'),
    supabase.rpc('founder_r3702_high_risk_queue'),
  ]);

  const statusRows: StatusRow[] = (statusRes.data as StatusRow[]) ?? [];
  const teamRows: TeamRow[] = (teamRes.data as TeamRow[]) ?? [];
  const matrixRows: MatrixRow[] = (matrixRes.data as MatrixRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const digestRows: DigestRow[] = (digestRes.data as DigestRow[]) ?? [];
  const riskRows: RiskRow[] = (riskRes.data as RiskRow[]) ?? [];

  const statusCols: Column<StatusRow>[] = [
    { key: 'lifecycle_status', header: 'Lifecycle Status' },
    { key: 'flags', header: 'Flags' },
    { key: 'pct', header: 'Share %' },
  ];

  const teamCols: Column<TeamRow>[] = [
    { key: 'owning_team', header: 'Team' },
    { key: 'total_flags', header: 'Flags' },
    { key: 'active_managed', header: 'Active Managed' },
    { key: 'fully_rolled_out', header: 'Fully Rolled Out' },
    { key: 'stale_flags', header: 'Stale' },
    { key: 'zombie_flags', header: 'Zombie' },
    { key: 'cleanup_overdue_flags', header: 'Cleanup Overdue' },
    { key: 'kill_switches', header: 'Kill-Switches' },
    { key: 'avg_age_days', header: 'Avg Age (days)' },
    { key: 'hygiene_pct', header: 'Hygiene %' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'flag_class', header: 'Flag Class' },
    { key: 'lifecycle_status', header: 'Lifecycle Status' },
    { key: 'flags', header: 'Flags' },
    { key: 'avg_age_days', header: 'Avg Age (days)' },
    { key: 'avg_rollout_pct', header: 'Avg Rollout %' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'period_month', header: 'Month' },
    { key: 'flags', header: 'Flags' },
    { key: 'avg_age_days', header: 'Avg Age (days)' },
    { key: 'stale_plus', header: 'Stale / Zombie / Overdue' },
    { key: 'cleanup_tickets_open', header: 'Cleanup Tickets Open' },
    { key: 'avg_evaluations_30d', header: 'Avg Evals 30d' },
  ];

  const capaCols: Column<CapaRow>[] = [
    { key: 'capa_status', header: 'CAPA Status' },
    { key: 'actions', header: 'Actions' },
    { key: 'avg_hours_est', header: 'Avg Eng Hours' },
    { key: 'overdue_flag', header: 'Overdue / Escalated' },
  ];

  const causeCols: Column<CauseRow>[] = [
    { key: 'root_cause', header: 'Root Cause' },
    { key: 'occurrences', header: 'Occurrences' },
    { key: 'total_hours_est', header: 'Total Eng Hours' },
    { key: 'pct', header: 'Share %' },
  ];

  const digestCols: Column<DigestRow>[] = [
    { key: 'trend_dir', header: 'Trend' },
    { key: 'flags', header: 'Flags' },
    { key: 'stale_flags', header: 'Stale' },
    { key: 'zombie_flags', header: 'Zombie' },
    { key: 'cleanup_overdue_flags', header: 'Cleanup Overdue' },
    { key: 'avg_age_days', header: 'Avg Age (days)' },
    { key: 'total_code_references', header: 'Total Code Refs' },
  ];

  const riskCols: Column<RiskRow>[] = [
    { key: 'flag_name', header: 'Flag' },
    { key: 'owning_team', header: 'Team' },
    { key: 'flag_class', header: 'Class' },
    { key: 'lifecycle_status', header: 'Lifecycle' },
    { key: 'age_days', header: 'Age (days)' },
    { key: 'rollout_pct', header: 'Rollout %' },
    { key: 'evaluations_30d', header: 'Evals 30d' },
    { key: 'code_references', header: 'Code Refs' },
    { key: 'cleanup_ticket_open', header: 'Cleanup Ticket' },
    { key: 'trend_dir', header: 'Trend' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Feature-Flag Lifecycle / Stale-Flag Hygiene Board
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Platform feature-flag governance — flag inventory (release, ops kill-switch, experiment,
        permission &amp; config flags) &times; owning team &times; flag age &times; rollout %
        &times; active environments &times; 30-day evaluations &times; code references &times;
        cleanup-ticket state &amp; CAPA closure. Founder-gated view: lifecycle-status rollups,
        team hygiene scorecards, flag-class matrix, monthly age trend, root-cause pareto, and the
        zombie / cleanup-overdue high-risk queue. Flag governance only &mdash; not experiment
        outcomes.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Lifecycle status distribution</h2>
        <DataTable
          rows={statusRows}
          columns={statusCols}
          emptyMessage="No flags inventoried yet."
          rowKey={(r, i) => String(r.lifecycle_status ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Owning-team hygiene scorecard</h2>
        <DataTable
          rows={teamRows}
          columns={teamCols}
          emptyMessage="No team rollups."
          rowKey={(r, i) => String(r.owning_team ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Flag class &times; lifecycle matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No flags by class."
          rowKey={(r, i) => `${r.flag_class}-${r.lifecycle_status}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Monthly flag-age trend</h2>
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
          emptyMessage="No CAPA actions."
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>7. Stale-flag digest by trend</h2>
        <DataTable
          rows={digestRows}
          columns={digestCols}
          emptyMessage="No digest rollups."
          rowKey={(r, i) => String(r.trend_dir ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk flag queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk flags."
          rowKey={(r, i) => `${r.flag_name}-${i}`}
        />
      </section>
    </main>
  );
}
