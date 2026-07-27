import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type DecisionRow = {
  gate_decision: string;
  projects: number;
  total_investment_rupees: number;
  pct: number;
};
type CategoryRow = {
  category: string;
  total_projects: number;
  go_count: number;
  conditional_count: number;
  no_go_count: number;
  avg_strategic_score: number;
  avg_risk_score: number;
  total_investment_rupees: number;
  go_pct: number;
};
type MatrixRow = {
  gate_stage: string;
  gate_decision: string;
  projects: number;
  total_investment_rupees: number;
  avg_roi_pct: number;
};
type TrendRow = {
  gate_month: string;
  projects: number;
  go_count: number;
  no_go_count: number;
  hold_count: number;
  total_investment_rupees: number;
};
type CapaRow = {
  capa_status: string;
  findings: number;
  avg_cost_rupees: number;
  overdue_flag: number;
};
type CauseRow = {
  root_cause: string;
  occurrences: number;
  total_cost_rupees: number;
  pct: number;
};
type ImpactRow = {
  investment_impact: string;
  findings: number;
  open_findings: number;
  total_cost_rupees: number;
};
type RiskRow = {
  project_code: string;
  project_name: string;
  sponsor: string;
  category: string;
  gate_stage: string;
  gate_decision: string;
  investment_rupees: number | null;
  strategic_score: number | null;
  risk_score: number | null;
  priority_rank: number | null;
  target_gate_date: string | null;
  notes: string | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    decisionRes,
    categoryRes,
    matrixRes,
    trendRes,
    capaRes,
    causeRes,
    impactRes,
    riskRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3481_gate_decision_rollup'),
    supabase.rpc('founder_r3481_category_scorecard'),
    supabase.rpc('founder_r3481_stage_decision_matrix'),
    supabase.rpc('founder_r3481_monthly_gate_trend'),
    supabase.rpc('founder_r3481_capa_status_board'),
    supabase.rpc('founder_r3481_root_cause_pareto'),
    supabase.rpc('founder_r3481_investment_impact_digest'),
    supabase.rpc('founder_r3481_high_risk_queue'),
  ]);

  const decisionRows: DecisionRow[] = (decisionRes.data as DecisionRow[]) ?? [];
  const categoryRows: CategoryRow[] = (categoryRes.data as CategoryRow[]) ?? [];
  const matrixRows: MatrixRow[] = (matrixRes.data as MatrixRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const impactRows: ImpactRow[] = (impactRes.data as ImpactRow[]) ?? [];
  const riskRows: RiskRow[] = (riskRes.data as RiskRow[]) ?? [];

  const decisionCols: Column<DecisionRow>[] = [
    { key: 'gate_decision', header: 'Gate Decision' },
    { key: 'projects', header: 'Projects' },
    { key: 'total_investment_rupees', header: 'Investment (INR)' },
    { key: 'pct', header: 'Share %' },
  ];

  const categoryCols: Column<CategoryRow>[] = [
    { key: 'category', header: 'Category' },
    { key: 'total_projects', header: 'Projects' },
    { key: 'go_count', header: 'Go' },
    { key: 'conditional_count', header: 'Conditional' },
    { key: 'no_go_count', header: 'No-Go' },
    { key: 'avg_strategic_score', header: 'Avg Strategic' },
    { key: 'avg_risk_score', header: 'Avg Risk' },
    { key: 'total_investment_rupees', header: 'Investment (INR)' },
    { key: 'go_pct', header: 'Go %' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'gate_stage', header: 'Gate Stage' },
    { key: 'gate_decision', header: 'Gate Decision' },
    { key: 'projects', header: 'Projects' },
    { key: 'total_investment_rupees', header: 'Investment (INR)' },
    { key: 'avg_roi_pct', header: 'Avg ROI %' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'gate_month', header: 'Gate Month' },
    { key: 'projects', header: 'Projects' },
    { key: 'go_count', header: 'Go' },
    { key: 'no_go_count', header: 'No-Go' },
    { key: 'hold_count', header: 'Hold' },
    { key: 'total_investment_rupees', header: 'Investment (INR)' },
  ];

  const capaCols: Column<CapaRow>[] = [
    { key: 'capa_status', header: 'CAPA Status' },
    { key: 'findings', header: 'Findings' },
    { key: 'avg_cost_rupees', header: 'Avg Cost (INR)' },
    { key: 'overdue_flag', header: 'Overdue / Escalated' },
  ];

  const causeCols: Column<CauseRow>[] = [
    { key: 'root_cause', header: 'Root Cause' },
    { key: 'occurrences', header: 'Occurrences' },
    { key: 'total_cost_rupees', header: 'Total Cost (INR)' },
    { key: 'pct', header: 'Share %' },
  ];

  const impactCols: Column<ImpactRow>[] = [
    { key: 'investment_impact', header: 'Investment Impact' },
    { key: 'findings', header: 'Findings' },
    { key: 'open_findings', header: 'Open' },
    { key: 'total_cost_rupees', header: 'Total Cost (INR)' },
  ];

  const riskCols: Column<RiskRow>[] = [
    { key: 'project_code', header: 'Code' },
    { key: 'project_name', header: 'Project' },
    { key: 'sponsor', header: 'Sponsor' },
    { key: 'category', header: 'Category' },
    { key: 'gate_stage', header: 'Stage' },
    { key: 'gate_decision', header: 'Decision' },
    { key: 'investment_rupees', header: 'Investment (INR)' },
    { key: 'strategic_score', header: 'Strategic' },
    { key: 'risk_score', header: 'Risk' },
    { key: 'priority_rank', header: 'Priority' },
    { key: 'target_gate_date', header: 'Target Gate' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Stage-Gate Capital-Project Portfolio Prioritization Board
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Founder capital-project portfolio governance &mdash; project &times; sponsor &times; category
        &times; gate stage (idea &rarr; feasibility &rarr; business case &rarr; approved &rarr; in
        execution &rarr; launched, with on-hold &amp; killed) &times; investment &times; expected ROI
        &times; strategic &amp; risk scores &times; priority rank &times; go/no-go decision &times;
        target gate date &amp; CAPA closure. Founder-gated view: gate-decision rollups, category
        scorecards, stage &times; decision matrix, root-cause pareto, and investment-impact digest
        across the capex pipeline.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Gate-decision distribution</h2>
        <DataTable
          rows={decisionRows}
          columns={decisionCols}
          emptyMessage="No projects logged yet."
          rowKey={(r, i) => String(r.gate_decision ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Category scorecard</h2>
        <DataTable
          rows={categoryRows}
          columns={categoryCols}
          emptyMessage="No category rollups."
          rowKey={(r, i) => String(r.category ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Gate stage &times; decision matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No projects by gate stage."
          rowKey={(r, i) => `${r.gate_stage}-${r.gate_decision}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Monthly gate-progress trend</h2>
        <DataTable
          rows={trendRows}
          columns={trendCols}
          emptyMessage="No trend data."
          rowKey={(r, i) => String(r.gate_month ?? i)}
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>7. Investment-impact digest</h2>
        <DataTable
          rows={impactRows}
          columns={impactCols}
          emptyMessage="No investment-impact rollups."
          rowKey={(r, i) => String(r.investment_impact ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk portfolio queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk projects."
          rowKey={(r, i) => `${r.project_code}-${i}`}
        />
      </section>
    </main>
  );
}
