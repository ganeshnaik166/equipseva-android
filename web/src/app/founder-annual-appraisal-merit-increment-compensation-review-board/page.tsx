import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type VerdictRow = { review_verdict: string; employees: number; pct: number };
type DeptRow = {
  department: string;
  total_reviews: number;
  promotions: number;
  retention_actions: number;
  high_flight_risk: number;
  below_market: number;
  guardrail_breaches: number;
  avg_increment_pct: number;
};
type MatrixRow = {
  band: string;
  performance_rating: string;
  employees: number;
  promotions: number;
  avg_increment_pct: number;
  avg_variable_payout_pct: number;
};
type TrendRow = {
  review_date: string;
  reviews: number;
  promotions: number;
  retention_actions: number;
  high_flight_risk: number;
  guardrail_breaches: number;
};
type CapaRow = {
  capa_status: string;
  actions: number;
  avg_cost_rupees: number;
  escalated_flag: number;
};
type CauseRow = {
  root_cause: string;
  occurrences: number;
  total_cost_rupees: number;
  pct: number;
};
type CostRow = {
  compensation_impact: string;
  actions: number;
  open_actions: number;
  total_cost_rupees: number;
};
type RiskRow = {
  employee_name: string;
  department: string;
  band: string;
  review_date: string;
  performance_rating: string;
  review_verdict: string;
  flight_risk: string;
  market_benchmark_position: string;
  proposed_increment_pct: number;
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
    costRes,
    riskRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3297_verdict_rollup'),
    supabase.rpc('founder_r3297_department_scorecard'),
    supabase.rpc('founder_r3297_band_rating_matrix'),
    supabase.rpc('founder_r3297_review_date_trend'),
    supabase.rpc('founder_r3297_capa_status_board'),
    supabase.rpc('founder_r3297_root_cause_pareto'),
    supabase.rpc('founder_r3297_compensation_cost_digest'),
    supabase.rpc('founder_r3297_high_risk_queue'),
  ]);

  const verdictRows: VerdictRow[] = (verdictRes.data as VerdictRow[]) ?? [];
  const deptRows: DeptRow[] = (deptRes.data as DeptRow[]) ?? [];
  const matrixRows: MatrixRow[] = (matrixRes.data as MatrixRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const costRows: CostRow[] = (costRes.data as CostRow[]) ?? [];
  const riskRows: RiskRow[] = (riskRes.data as RiskRow[]) ?? [];

  const verdictCols: Column<VerdictRow>[] = [
    { key: 'review_verdict', header: 'Verdict' },
    { key: 'employees', header: 'Employees' },
    { key: 'pct', header: 'Share %' },
  ];

  const deptCols: Column<DeptRow>[] = [
    { key: 'department', header: 'Department' },
    { key: 'total_reviews', header: 'Reviews' },
    { key: 'promotions', header: 'Promotions' },
    { key: 'retention_actions', header: 'Retention Actions' },
    { key: 'high_flight_risk', header: 'High Flight-Risk' },
    { key: 'below_market', header: 'Below Market' },
    { key: 'guardrail_breaches', header: 'Guardrail Breaches' },
    { key: 'avg_increment_pct', header: 'Avg Increment %' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'band', header: 'Band' },
    { key: 'performance_rating', header: 'Rating' },
    { key: 'employees', header: 'Employees' },
    { key: 'promotions', header: 'Promotions' },
    { key: 'avg_increment_pct', header: 'Avg Increment %' },
    { key: 'avg_variable_payout_pct', header: 'Avg Variable %' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'review_date', header: 'Date' },
    { key: 'reviews', header: 'Reviews' },
    { key: 'promotions', header: 'Promotions' },
    { key: 'retention_actions', header: 'Retention Actions' },
    { key: 'high_flight_risk', header: 'High Flight-Risk' },
    { key: 'guardrail_breaches', header: 'Guardrail Breaches' },
  ];

  const capaCols: Column<CapaRow>[] = [
    { key: 'capa_status', header: 'CAPA Status' },
    { key: 'actions', header: 'Actions' },
    { key: 'avg_cost_rupees', header: 'Avg Cost (INR)' },
    { key: 'escalated_flag', header: 'Overdue / Escalated' },
  ];

  const causeCols: Column<CauseRow>[] = [
    { key: 'root_cause', header: 'Root Cause' },
    { key: 'occurrences', header: 'Occurrences' },
    { key: 'total_cost_rupees', header: 'Total Cost (INR)' },
    { key: 'pct', header: 'Share %' },
  ];

  const costCols: Column<CostRow>[] = [
    { key: 'compensation_impact', header: 'Compensation Impact' },
    { key: 'actions', header: 'Actions' },
    { key: 'open_actions', header: 'Open' },
    { key: 'total_cost_rupees', header: 'Total Cost (INR)' },
  ];

  const riskCols: Column<RiskRow>[] = [
    { key: 'employee_name', header: 'Employee' },
    { key: 'department', header: 'Department' },
    { key: 'band', header: 'Band' },
    { key: 'review_date', header: 'Date' },
    { key: 'performance_rating', header: 'Rating' },
    { key: 'review_verdict', header: 'Verdict' },
    { key: 'flight_risk', header: 'Flight Risk' },
    { key: 'market_benchmark_position', header: 'Market Position' },
    { key: 'proposed_increment_pct', header: 'Increment %' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Founder Annual Appraisal, Merit-Increment &amp; Compensation-Review Board
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Founder-gated HR governance — review verdict &times; department scorecard &times; band
        &times; performance rating &times; merit increment % &times; market-benchmark position
        &times; flight-risk &times; variable-payout &amp; retention/calibration/promotion CAPA.
        Rollups: verdict distribution, department scorecards, band &times; rating matrix,
        root-cause pareto, compensation-cost digest, and a high-risk retention queue.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Review verdict distribution</h2>
        <DataTable
          rows={verdictRows}
          columns={verdictCols}
          emptyMessage="No appraisal reviews logged yet."
          rowKey={(r, i) => String(r.review_verdict ?? i)}
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Band &times; rating matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No reviews by band."
          rowKey={(r, i) => `${r.band}-${r.performance_rating}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Daily review trend</h2>
        <DataTable
          rows={trendRows}
          columns={trendCols}
          emptyMessage="No trend data."
          rowKey={(r, i) => String(r.review_date ?? i)}
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>7. Compensation-cost digest</h2>
        <DataTable
          rows={costRows}
          columns={costCols}
          emptyMessage="No compensation-cost rollups."
          rowKey={(r, i) => String(r.compensation_impact ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk retention queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk reviews."
          rowKey={(r, i) => `${r.employee_name}-${r.review_date}-${i}`}
        />
      </section>
    </main>
  );
}
