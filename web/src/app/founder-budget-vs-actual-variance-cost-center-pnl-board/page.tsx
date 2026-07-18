import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type VerdictRow = { variance_verdict: string; entries: number; pct: number };
type CenterRow = {
  cost_center: string;
  total_lines: number;
  favorable: number;
  unfavorable: number;
  overrun_action: number;
  total_budget_rupees: number;
  total_actual_rupees: number;
  total_variance_rupees: number;
  avg_variance_pct: number;
};
type MatrixRow = {
  cost_center: string;
  line_item: string;
  entries: number;
  total_budget_rupees: number;
  total_actual_rupees: number;
  total_variance_rupees: number;
  avg_variance_pct: number;
};
type TrendRow = {
  period_month: string;
  entries: number;
  total_budget_rupees: number;
  total_actual_rupees: number;
  total_variance_rupees: number;
  unfavorable: number;
};
type CapaRow = {
  capa_status: string;
  findings: number;
  avg_impact_rupees: number;
  overdue_flag: number;
};
type CauseRow = {
  root_cause: string;
  occurrences: number;
  total_impact_rupees: number;
  pct: number;
};
type MaterialityRow = {
  materiality: string;
  findings: number;
  open_findings: number;
  total_impact_rupees: number;
};
type RiskRow = {
  cost_center: string;
  period_month: string;
  line_item: string;
  owner: string;
  budget_rupees: number;
  actual_rupees: number;
  variance_rupees: number;
  variance_pct: number;
  variance_direction: string;
  variance_verdict: string;
  notes: string | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    verdictRes,
    centerRes,
    matrixRes,
    trendRes,
    capaRes,
    causeRes,
    materialityRes,
    riskRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3313_variance_verdict_rollup'),
    supabase.rpc('founder_r3313_cost_center_scorecard'),
    supabase.rpc('founder_r3313_center_lineitem_matrix'),
    supabase.rpc('founder_r3313_monthly_variance_trend'),
    supabase.rpc('founder_r3313_capa_status_board'),
    supabase.rpc('founder_r3313_root_cause_pareto'),
    supabase.rpc('founder_r3313_materiality_digest'),
    supabase.rpc('founder_r3313_high_risk_queue'),
  ]);

  const verdictRows: VerdictRow[] = (verdictRes.data as VerdictRow[]) ?? [];
  const centerRows: CenterRow[] = (centerRes.data as CenterRow[]) ?? [];
  const matrixRows: MatrixRow[] = (matrixRes.data as MatrixRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const materialityRows: MaterialityRow[] = (materialityRes.data as MaterialityRow[]) ?? [];
  const riskRows: RiskRow[] = (riskRes.data as RiskRow[]) ?? [];

  const verdictCols: Column<VerdictRow>[] = [
    { key: 'variance_verdict', header: 'Variance Verdict' },
    { key: 'entries', header: 'Entries' },
    { key: 'pct', header: 'Share %' },
  ];

  const centerCols: Column<CenterRow>[] = [
    { key: 'cost_center', header: 'Cost Center' },
    { key: 'total_lines', header: 'Lines' },
    { key: 'favorable', header: 'Favorable' },
    { key: 'unfavorable', header: 'Unfavorable' },
    { key: 'overrun_action', header: 'Action Needed' },
    { key: 'total_budget_rupees', header: 'Budget (INR)' },
    { key: 'total_actual_rupees', header: 'Actual (INR)' },
    { key: 'total_variance_rupees', header: 'Variance (INR)' },
    { key: 'avg_variance_pct', header: 'Avg Variance %' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'cost_center', header: 'Cost Center' },
    { key: 'line_item', header: 'Line Item' },
    { key: 'entries', header: 'Entries' },
    { key: 'total_budget_rupees', header: 'Budget (INR)' },
    { key: 'total_actual_rupees', header: 'Actual (INR)' },
    { key: 'total_variance_rupees', header: 'Variance (INR)' },
    { key: 'avg_variance_pct', header: 'Avg Variance %' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'period_month', header: 'Period' },
    { key: 'entries', header: 'Entries' },
    { key: 'total_budget_rupees', header: 'Budget (INR)' },
    { key: 'total_actual_rupees', header: 'Actual (INR)' },
    { key: 'total_variance_rupees', header: 'Variance (INR)' },
    { key: 'unfavorable', header: 'Unfavorable' },
  ];

  const capaCols: Column<CapaRow>[] = [
    { key: 'capa_status', header: 'CAPA Status' },
    { key: 'findings', header: 'Findings' },
    { key: 'avg_impact_rupees', header: 'Avg Impact (INR)' },
    { key: 'overdue_flag', header: 'Overdue / Escalated' },
  ];

  const causeCols: Column<CauseRow>[] = [
    { key: 'root_cause', header: 'Root Cause' },
    { key: 'occurrences', header: 'Occurrences' },
    { key: 'total_impact_rupees', header: 'Total Impact (INR)' },
    { key: 'pct', header: 'Share %' },
  ];

  const materialityCols: Column<MaterialityRow>[] = [
    { key: 'materiality', header: 'Materiality' },
    { key: 'findings', header: 'Findings' },
    { key: 'open_findings', header: 'Open' },
    { key: 'total_impact_rupees', header: 'Total Impact (INR)' },
  ];

  const riskCols: Column<RiskRow>[] = [
    { key: 'cost_center', header: 'Cost Center' },
    { key: 'period_month', header: 'Period' },
    { key: 'line_item', header: 'Line Item' },
    { key: 'owner', header: 'Owner' },
    { key: 'budget_rupees', header: 'Budget (INR)' },
    { key: 'actual_rupees', header: 'Actual (INR)' },
    { key: 'variance_rupees', header: 'Variance (INR)' },
    { key: 'variance_pct', header: 'Variance %' },
    { key: 'variance_direction', header: 'Direction' },
    { key: 'variance_verdict', header: 'Verdict' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Founder Budget-vs-Actual Variance &amp; Cost-Center P&amp;L Governance Board
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Finance governance view — cost-center &times; line-item &times; budget vs actual rupees
        &times; variance rupees &amp; % &times; favorable/unfavorable direction &times; YTD budget vs
        actual &times; full-year forecast &times; variance verdict &amp; CAPA reforecast closure.
        Founder-gated: verdict rollups, cost-center P&amp;L scorecards, root-cause pareto, and a
        materiality digest for overruns needing board escalation or reforecast.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Variance verdict distribution</h2>
        <DataTable
          rows={verdictRows}
          columns={verdictCols}
          emptyMessage="No variance rows logged yet."
          rowKey={(r, i) => String(r.variance_verdict ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Cost-center P&amp;L scorecard</h2>
        <DataTable
          rows={centerRows}
          columns={centerCols}
          emptyMessage="No cost-center rollups."
          rowKey={(r, i) => String(r.cost_center ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Cost-center &times; line-item matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No rows by center and line item."
          rowKey={(r, i) => `${r.cost_center}-${r.line_item}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Monthly variance trend</h2>
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>7. Materiality digest</h2>
        <DataTable
          rows={materialityRows}
          columns={materialityCols}
          emptyMessage="No materiality rollups."
          rowKey={(r, i) => String(r.materiality ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk variance queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk variances."
          rowKey={(r, i) => `${r.cost_center}-${r.period_month}-${r.line_item}-${i}`}
        />
      </section>
    </main>
  );
}
