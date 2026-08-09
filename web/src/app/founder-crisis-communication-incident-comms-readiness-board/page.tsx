import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type StatusRow = { readiness_status: string; scenarios: number; pct: number };
type FuncRow = {
  owning_function: string;
  total_scenarios: number;
  ready: number;
  review_due: number;
  drill_overdue: number;
  gaps_or_unprepared: number;
  avg_contact_tree_pct: number;
  avg_drill_response_minutes: number;
  ready_pct: number;
};
type MatrixRow = {
  scenario_class: string;
  readiness_status: string;
  scenarios: number;
  avg_contact_tree_pct: number;
  avg_drill_response_minutes: number;
};
type TrendRow = {
  period_month: string;
  scenarios: number;
  drills_run: number;
  avg_drill_response_minutes: number;
  spokesperson_gaps: number;
  playbook_stale: number;
};
type CapaRow = {
  capa_status: string;
  actions: number;
  avg_cost_rupees: number;
  overdue_flag: number;
};
type CauseRow = {
  root_cause: string;
  occurrences: number;
  total_cost_rupees: number;
  pct: number;
};
type GapRow = {
  gap_category: string;
  actions: number;
  open_actions: number;
  total_cost_rupees: number;
};
type RiskRow = {
  scenario_name: string;
  owning_function: string;
  scenario_class: string;
  period_month: string;
  readiness_status: string;
  trend_dir: string;
  spokesperson_assigned: boolean;
  contact_tree_verified_pct: number | null;
  media_holding_statement_ready: boolean;
  notes: string | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    statusRes,
    funcRes,
    matrixRes,
    trendRes,
    capaRes,
    causeRes,
    gapRes,
    riskRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3705_readiness_status_rollup'),
    supabase.rpc('founder_r3705_owning_function_scorecard'),
    supabase.rpc('founder_r3705_class_status_matrix'),
    supabase.rpc('founder_r3705_monthly_drill_trend'),
    supabase.rpc('founder_r3705_capa_status_board'),
    supabase.rpc('founder_r3705_root_cause_pareto'),
    supabase.rpc('founder_r3705_gap_digest'),
    supabase.rpc('founder_r3705_high_risk_queue'),
  ]);

  const statusRows: StatusRow[] = (statusRes.data as StatusRow[]) ?? [];
  const funcRows: FuncRow[] = (funcRes.data as FuncRow[]) ?? [];
  const matrixRows: MatrixRow[] = (matrixRes.data as MatrixRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const gapRows: GapRow[] = (gapRes.data as GapRow[]) ?? [];
  const riskRows: RiskRow[] = (riskRes.data as RiskRow[]) ?? [];

  const statusCols: Column<StatusRow>[] = [
    { key: 'readiness_status', header: 'Readiness Status' },
    { key: 'scenarios', header: 'Scenarios' },
    { key: 'pct', header: 'Share %' },
  ];

  const funcCols: Column<FuncRow>[] = [
    { key: 'owning_function', header: 'Owning Function' },
    { key: 'total_scenarios', header: 'Scenarios' },
    { key: 'ready', header: 'Ready' },
    { key: 'review_due', header: 'Review Due' },
    { key: 'drill_overdue', header: 'Drill Overdue' },
    { key: 'gaps_or_unprepared', header: 'Gaps / Unprepared' },
    { key: 'avg_contact_tree_pct', header: 'Avg Contact Tree %' },
    { key: 'avg_drill_response_minutes', header: 'Avg Drill Resp (min)' },
    { key: 'ready_pct', header: 'Ready %' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'scenario_class', header: 'Scenario Class' },
    { key: 'readiness_status', header: 'Readiness Status' },
    { key: 'scenarios', header: 'Scenarios' },
    { key: 'avg_contact_tree_pct', header: 'Avg Contact Tree %' },
    { key: 'avg_drill_response_minutes', header: 'Avg Drill Resp (min)' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'period_month', header: 'Month' },
    { key: 'scenarios', header: 'Scenarios' },
    { key: 'drills_run', header: 'Drills Run' },
    { key: 'avg_drill_response_minutes', header: 'Avg Drill Resp (min)' },
    { key: 'spokesperson_gaps', header: 'Spokesperson Gaps' },
    { key: 'playbook_stale', header: 'Playbook Stale' },
  ];

  const capaCols: Column<CapaRow>[] = [
    { key: 'capa_status', header: 'CAPA Status' },
    { key: 'actions', header: 'Actions' },
    { key: 'avg_cost_rupees', header: 'Avg Cost (INR)' },
    { key: 'overdue_flag', header: 'Overdue / Escalated' },
  ];

  const causeCols: Column<CauseRow>[] = [
    { key: 'root_cause', header: 'Root Cause' },
    { key: 'occurrences', header: 'Occurrences' },
    { key: 'total_cost_rupees', header: 'Total Cost (INR)' },
    { key: 'pct', header: 'Share %' },
  ];

  const gapCols: Column<GapRow>[] = [
    { key: 'gap_category', header: 'Gap Category' },
    { key: 'actions', header: 'Actions' },
    { key: 'open_actions', header: 'Open' },
    { key: 'total_cost_rupees', header: 'Total Cost (INR)' },
  ];

  const riskCols: Column<RiskRow>[] = [
    { key: 'scenario_name', header: 'Scenario' },
    { key: 'owning_function', header: 'Function' },
    { key: 'scenario_class', header: 'Class' },
    { key: 'period_month', header: 'Month' },
    { key: 'readiness_status', header: 'Status' },
    { key: 'trend_dir', header: 'Trend' },
    { key: 'spokesperson_assigned', header: 'Spokesperson' },
    { key: 'contact_tree_verified_pct', header: 'Contact Tree %' },
    { key: 'media_holding_statement_ready', header: 'Holding Stmt' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Crisis-Communication / Incident-Comms Readiness Board
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Crisis-communication readiness log — scenario playbooks (patient-safety events, data
        breaches, regulatory actions, key-person loss, service outages, PR &amp; social) &times;
        owning function &times; spokesperson assignment &times; contact-tree verification &times;
        drill cadence &amp; response minutes &times; stakeholder coverage &times; media holding
        statements &amp; CAPA closure. Founder-gated view: readiness-status rollups, function
        scorecards, root-cause pareto, and the unprepared / gaps-found high-risk queue.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Readiness status distribution</h2>
        <DataTable
          rows={statusRows}
          columns={statusCols}
          emptyMessage="No readiness scenarios logged yet."
          rowKey={(r, i) => String(r.readiness_status ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Owning-function scorecard</h2>
        <DataTable
          rows={funcRows}
          columns={funcCols}
          emptyMessage="No function rollups."
          rowKey={(r, i) => String(r.owning_function ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Scenario class &times; readiness status matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No scenarios by class."
          rowKey={(r, i) => `${r.scenario_class}-${r.readiness_status}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Monthly drill trend</h2>
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>7. Readiness-gap digest</h2>
        <DataTable
          rows={gapRows}
          columns={gapCols}
          emptyMessage="No gap rollups."
          rowKey={(r, i) => String(r.gap_category ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk scenario queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk scenarios."
          rowKey={(r, i) => `${r.scenario_name}-${r.period_month}-${i}`}
        />
      </section>
    </main>
  );
}
