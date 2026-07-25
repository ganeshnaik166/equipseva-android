import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type VerdictRow = { people_verdict: string; cohorts: number; pct: number };
type DeptRow = {
  department: string;
  cohort_rows: number;
  total_headcount: number;
  avg_enps: number;
  avg_attrition_pct: number;
  avg_regretted_pct: number;
  avg_engagement: number;
  flight_risk: number;
  action_rows: number;
};
type MatrixRow = {
  department: string;
  cohort: string;
  rows_count: number;
  total_headcount: number;
  avg_enps: number;
  avg_attrition_pct: number;
  avg_tenure_years: number;
};
type TrendRow = {
  period_quarter: string;
  cohort_rows: number;
  total_headcount: number;
  avg_enps: number;
  avg_attrition_pct: number;
  avg_engagement: number;
  flight_risk: number;
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
  people_impact: string;
  findings: number;
  open_findings: number;
  total_cost_rupees: number;
};
type RiskRow = {
  department: string;
  cohort: string;
  period_quarter: string;
  headcount: number;
  enps_score: number;
  attrition_pct: number;
  people_verdict: string;
  top_attrition_driver: string;
  flight_risk_count: number;
  notes: string | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    verdictRes,
    deptRes,
    matrixRes,
    trendRes,
    capaRes,
    causeRes,
    impactRes,
    riskRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3405_people_verdict_rollup'),
    supabase.rpc('founder_r3405_department_scorecard'),
    supabase.rpc('founder_r3405_department_cohort_matrix'),
    supabase.rpc('founder_r3405_quarterly_trend'),
    supabase.rpc('founder_r3405_capa_status_board'),
    supabase.rpc('founder_r3405_root_cause_pareto'),
    supabase.rpc('founder_r3405_people_impact_digest'),
    supabase.rpc('founder_r3405_high_risk_queue'),
  ]);

  const verdictRows: VerdictRow[] = (verdictRes.data as VerdictRow[]) ?? [];
  const deptRows: DeptRow[] = (deptRes.data as DeptRow[]) ?? [];
  const matrixRows: MatrixRow[] = (matrixRes.data as MatrixRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const impactRows: ImpactRow[] = (impactRes.data as ImpactRow[]) ?? [];
  const riskRows: RiskRow[] = (riskRes.data as RiskRow[]) ?? [];

  const verdictCols: Column<VerdictRow>[] = [
    { key: 'people_verdict', header: 'People Verdict' },
    { key: 'cohorts', header: 'Cohort Rows' },
    { key: 'pct', header: 'Share %' },
  ];

  const deptCols: Column<DeptRow>[] = [
    { key: 'department', header: 'Department' },
    { key: 'cohort_rows', header: 'Cohort Rows' },
    { key: 'total_headcount', header: 'Headcount' },
    { key: 'avg_enps', header: 'Avg eNPS' },
    { key: 'avg_attrition_pct', header: 'Avg Attrition %' },
    { key: 'avg_regretted_pct', header: 'Avg Regretted %' },
    { key: 'avg_engagement', header: 'Avg Engagement' },
    { key: 'flight_risk', header: 'Flight Risk' },
    { key: 'action_rows', header: 'Action Rows' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'department', header: 'Department' },
    { key: 'cohort', header: 'Cohort' },
    { key: 'rows_count', header: 'Rows' },
    { key: 'total_headcount', header: 'Headcount' },
    { key: 'avg_enps', header: 'Avg eNPS' },
    { key: 'avg_attrition_pct', header: 'Avg Attrition %' },
    { key: 'avg_tenure_years', header: 'Avg Tenure (yrs)' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'period_quarter', header: 'Quarter' },
    { key: 'cohort_rows', header: 'Cohort Rows' },
    { key: 'total_headcount', header: 'Headcount' },
    { key: 'avg_enps', header: 'Avg eNPS' },
    { key: 'avg_attrition_pct', header: 'Avg Attrition %' },
    { key: 'avg_engagement', header: 'Avg Engagement' },
    { key: 'flight_risk', header: 'Flight Risk' },
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
    { key: 'people_impact', header: 'People Impact' },
    { key: 'findings', header: 'Findings' },
    { key: 'open_findings', header: 'Open' },
    { key: 'total_cost_rupees', header: 'Total Cost (INR)' },
  ];

  const riskCols: Column<RiskRow>[] = [
    { key: 'department', header: 'Department' },
    { key: 'cohort', header: 'Cohort' },
    { key: 'period_quarter', header: 'Quarter' },
    { key: 'headcount', header: 'Headcount' },
    { key: 'enps_score', header: 'eNPS' },
    { key: 'attrition_pct', header: 'Attrition %' },
    { key: 'people_verdict', header: 'Verdict' },
    { key: 'top_attrition_driver', header: 'Top Driver' },
    { key: 'flight_risk_count', header: 'Flight Risk' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Founder People-Analytics eNPS &amp; Attrition-Driver Board
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        EquipSeva HR governance — department (field engineering, office ops, sales, finance,
        leadership, support) &times; tenure cohort &times; period quarter &times; headcount &times;
        eNPS &times; attrition &amp; regretted attrition &times; average tenure &times; top
        attrition driver &times; engagement index &times; absenteeism &times; internal mobility
        &times; flight-risk count &amp; retention/engagement CAPA closure. Founder-gated view:
        people verdicts, department scorecards, department &times; cohort matrix, quarterly trend,
        root-cause pareto, and people-impact digest for eNPS &amp; attrition governance.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. People verdict distribution</h2>
        <DataTable
          rows={verdictRows}
          columns={verdictCols}
          emptyMessage="No people-analytics rows logged yet."
          rowKey={(r, i) => String(r.people_verdict ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Department scorecard</h2>
        <DataTable
          rows={deptRows}
          columns={deptCols}
          emptyMessage="No department rollups."
          rowKey={(r, i) => String(r.department ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Department &times; cohort matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No rows by department and cohort."
          rowKey={(r, i) => `${r.department}-${r.cohort}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Quarterly people trend</h2>
        <DataTable
          rows={trendRows}
          columns={trendCols}
          emptyMessage="No trend data."
          rowKey={(r, i) => String(r.period_quarter ?? i)}
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>7. People impact digest</h2>
        <DataTable
          rows={impactRows}
          columns={impactCols}
          emptyMessage="No people-impact rollups."
          rowKey={(r, i) => String(r.people_impact ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk cohort queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk cohorts."
          rowKey={(r, i) => `${r.department}-${r.cohort}-${r.period_quarter}-${i}`}
        />
      </section>
    </main>
  );
}
