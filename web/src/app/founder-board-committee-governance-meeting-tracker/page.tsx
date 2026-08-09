import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type StatusRow = { governance_status: string; committee_months: number; pct: number };
type ScoreRow = {
  committee_name: string;
  committee_class: string;
  periods: number;
  meetings_required_total: number;
  meetings_held_total: number;
  avg_quorum_pct: number;
  avg_attendance: number;
  avg_closure_pct: number;
  overdue_actions_total: number;
  minutes_on_time_pct: number;
};
type MatrixRow = {
  committee_class: string;
  governance_status: string;
  committee_months: number;
  avg_closure_pct: number;
  overdue_actions_total: number;
};
type TrendRow = {
  period_month: string;
  committee_months: number;
  meetings_required_total: number;
  meetings_held_total: number;
  avg_closure_pct: number;
  overdue_actions_total: number;
};
type CapaRow = {
  capa_status: string;
  findings: number;
  avg_risk_score: number;
  overdue_flag: number;
};
type CauseRow = {
  root_cause: string;
  occurrences: number;
  avg_risk_score: number;
  pct: number;
};
type OverdueRow = {
  committee_name: string;
  committee_class: string;
  actions_assigned_total: number;
  actions_closed_total: number;
  overdue_actions_total: number;
  avg_closure_pct: number;
};
type RiskRow = {
  committee_ref: string;
  committee_name: string;
  chair_name: string;
  committee_class: string;
  period_month: string;
  governance_status: string;
  trend_dir: string;
  quorum_met_pct: number | null;
  overdue_actions: number | null;
  notes: string | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    statusRes,
    scoreRes,
    matrixRes,
    trendRes,
    capaRes,
    causeRes,
    overdueRes,
    riskRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3707_governance_status_rollup'),
    supabase.rpc('founder_r3707_committee_scorecard'),
    supabase.rpc('founder_r3707_class_status_matrix'),
    supabase.rpc('founder_r3707_monthly_closure_trend'),
    supabase.rpc('founder_r3707_capa_status_board'),
    supabase.rpc('founder_r3707_root_cause_pareto'),
    supabase.rpc('founder_r3707_overdue_action_digest'),
    supabase.rpc('founder_r3707_high_risk_queue'),
  ]);

  const statusRows: StatusRow[] = (statusRes.data as StatusRow[]) ?? [];
  const scoreRows: ScoreRow[] = (scoreRes.data as ScoreRow[]) ?? [];
  const matrixRows: MatrixRow[] = (matrixRes.data as MatrixRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const overdueRows: OverdueRow[] = (overdueRes.data as OverdueRow[]) ?? [];
  const riskRows: RiskRow[] = (riskRes.data as RiskRow[]) ?? [];

  const statusCols: Column<StatusRow>[] = [
    { key: 'governance_status', header: 'Governance Status' },
    { key: 'committee_months', header: 'Committee-Months' },
    { key: 'pct', header: 'Share %' },
  ];

  const scoreCols: Column<ScoreRow>[] = [
    { key: 'committee_name', header: 'Committee' },
    { key: 'committee_class', header: 'Class' },
    { key: 'periods', header: 'Periods' },
    { key: 'meetings_required_total', header: 'Mtgs Required' },
    { key: 'meetings_held_total', header: 'Mtgs Held' },
    { key: 'avg_quorum_pct', header: 'Avg Quorum %' },
    { key: 'avg_attendance', header: 'Avg Attendance %' },
    { key: 'avg_closure_pct', header: 'Avg Closure %' },
    { key: 'overdue_actions_total', header: 'Overdue Actions' },
    { key: 'minutes_on_time_pct', header: 'Minutes On-Time %' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'committee_class', header: 'Committee Class' },
    { key: 'governance_status', header: 'Governance Status' },
    { key: 'committee_months', header: 'Committee-Months' },
    { key: 'avg_closure_pct', header: 'Avg Closure %' },
    { key: 'overdue_actions_total', header: 'Overdue Actions' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'period_month', header: 'Month' },
    { key: 'committee_months', header: 'Committee-Months' },
    { key: 'meetings_required_total', header: 'Mtgs Required' },
    { key: 'meetings_held_total', header: 'Mtgs Held' },
    { key: 'avg_closure_pct', header: 'Avg Closure %' },
    { key: 'overdue_actions_total', header: 'Overdue Actions' },
  ];

  const capaCols: Column<CapaRow>[] = [
    { key: 'capa_status', header: 'CAPA Status' },
    { key: 'findings', header: 'Findings' },
    { key: 'avg_risk_score', header: 'Avg Risk Score' },
    { key: 'overdue_flag', header: 'Overdue / Escalated' },
  ];

  const causeCols: Column<CauseRow>[] = [
    { key: 'root_cause', header: 'Root Cause' },
    { key: 'occurrences', header: 'Occurrences' },
    { key: 'avg_risk_score', header: 'Avg Risk Score' },
    { key: 'pct', header: 'Share %' },
  ];

  const overdueCols: Column<OverdueRow>[] = [
    { key: 'committee_name', header: 'Committee' },
    { key: 'committee_class', header: 'Class' },
    { key: 'actions_assigned_total', header: 'Actions Assigned' },
    { key: 'actions_closed_total', header: 'Actions Closed' },
    { key: 'overdue_actions_total', header: 'Overdue Actions' },
    { key: 'avg_closure_pct', header: 'Avg Closure %' },
  ];

  const riskCols: Column<RiskRow>[] = [
    { key: 'committee_ref', header: 'Ref' },
    { key: 'committee_name', header: 'Committee' },
    { key: 'chair_name', header: 'Chair' },
    { key: 'committee_class', header: 'Class' },
    { key: 'period_month', header: 'Month' },
    { key: 'governance_status', header: 'Status' },
    { key: 'trend_dir', header: 'Trend' },
    { key: 'quorum_met_pct', header: 'Quorum %' },
    { key: 'overdue_actions', header: 'Overdue' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Board-Committee Governance / Meeting Tracker
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Board committee governance tracker — committee (audit, NRC, CSR, risk, IT steering)
        &times; meetings held vs required &times; quorum &times; attendance &times; agenda
        &times; action closure &times; overdue actions &times; minutes filing &amp; CAPA closure.
        Founder-gated view: governance-status rollups, committee scorecards, monthly closure
        trend, root-cause pareto, and the high-risk (non-compliant / quorum-risk) queue.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Governance status distribution</h2>
        <DataTable
          rows={statusRows}
          columns={statusCols}
          emptyMessage="No committee-months logged yet."
          rowKey={(r, i) => String(r.governance_status ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Committee scorecard</h2>
        <DataTable
          rows={scoreRows}
          columns={scoreCols}
          emptyMessage="No committee rollups."
          rowKey={(r, i) => String(r.committee_name ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Committee class &times; governance status matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No matrix data."
          rowKey={(r, i) => `${r.committee_class}-${r.governance_status}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Monthly closure trend</h2>
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>7. Overdue-action digest</h2>
        <DataTable
          rows={overdueRows}
          columns={overdueCols}
          emptyMessage="No overdue actions."
          rowKey={(r, i) => `${r.committee_name}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk committee queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk committee-months."
          rowKey={(r, i) => `${r.committee_ref}-${r.period_month}-${i}`}
        />
      </section>
    </main>
  );
}
