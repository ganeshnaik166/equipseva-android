import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type VarianceTypeRow = {
  variance_type: string;
  entries: number;
  total_variance_rupees: number;
  pct: number;
};
type ElementRow = {
  cost_element: string;
  entries: number;
  adverse: number;
  favorable: number;
  neutral: number;
  total_standard_rupees: number;
  total_actual_rupees: number;
  total_variance_rupees: number;
  adverse_pct: number;
};
type MatrixRow = {
  cost_element: string;
  variance_driver: string;
  entries: number;
  adverse: number;
  total_variance_rupees: number;
};
type TrendRow = {
  period_month: string;
  entries: number;
  adverse: number;
  favorable: number;
  total_variance_rupees: number;
  price_rate_variance_rupees: number;
  usage_efficiency_variance_rupees: number;
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
type DigestRow = {
  finding_category: string;
  findings: number;
  open_findings: number;
  total_impact_rupees: number;
};
type RiskRow = {
  product_line: string;
  cost_entry_code: string;
  cost_element: string;
  variance_driver: string;
  period_month: string;
  variance_type: string;
  total_variance_rupees: number;
  variance_pct: number | null;
  recurring: boolean;
  notes: string | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    typeRes,
    elementRes,
    matrixRes,
    trendRes,
    capaRes,
    causeRes,
    digestRes,
    riskRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3545_variance_type_rollup'),
    supabase.rpc('founder_r3545_cost_element_scorecard'),
    supabase.rpc('founder_r3545_element_driver_matrix'),
    supabase.rpc('founder_r3545_monthly_variance_trend'),
    supabase.rpc('founder_r3545_capa_status_board'),
    supabase.rpc('founder_r3545_root_cause_pareto'),
    supabase.rpc('founder_r3545_variance_impact_digest'),
    supabase.rpc('founder_r3545_high_risk_queue'),
  ]);

  const typeRows: VarianceTypeRow[] = (typeRes.data as VarianceTypeRow[]) ?? [];
  const elementRows: ElementRow[] = (elementRes.data as ElementRow[]) ?? [];
  const matrixRows: MatrixRow[] = (matrixRes.data as MatrixRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const digestRows: DigestRow[] = (digestRes.data as DigestRow[]) ?? [];
  const riskRows: RiskRow[] = (riskRes.data as RiskRow[]) ?? [];

  const typeCols: Column<VarianceTypeRow>[] = [
    { key: 'variance_type', header: 'Variance Type' },
    { key: 'entries', header: 'Entries' },
    { key: 'total_variance_rupees', header: 'Total Variance (INR)' },
    { key: 'pct', header: 'Share %' },
  ];

  const elementCols: Column<ElementRow>[] = [
    { key: 'cost_element', header: 'Cost Element' },
    { key: 'entries', header: 'Entries' },
    { key: 'adverse', header: 'Adverse' },
    { key: 'favorable', header: 'Favorable' },
    { key: 'neutral', header: 'Neutral' },
    { key: 'total_standard_rupees', header: 'Std Cost (INR)' },
    { key: 'total_actual_rupees', header: 'Actual Cost (INR)' },
    { key: 'total_variance_rupees', header: 'Total Variance (INR)' },
    { key: 'adverse_pct', header: 'Adverse %' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'cost_element', header: 'Cost Element' },
    { key: 'variance_driver', header: 'Variance Driver' },
    { key: 'entries', header: 'Entries' },
    { key: 'adverse', header: 'Adverse' },
    { key: 'total_variance_rupees', header: 'Total Variance (INR)' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'period_month', header: 'Period' },
    { key: 'entries', header: 'Entries' },
    { key: 'adverse', header: 'Adverse' },
    { key: 'favorable', header: 'Favorable' },
    { key: 'total_variance_rupees', header: 'Total Variance (INR)' },
    { key: 'price_rate_variance_rupees', header: 'Price/Rate Var (INR)' },
    { key: 'usage_efficiency_variance_rupees', header: 'Usage/Eff Var (INR)' },
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

  const digestCols: Column<DigestRow>[] = [
    { key: 'finding_category', header: 'Finding Category' },
    { key: 'findings', header: 'Findings' },
    { key: 'open_findings', header: 'Open' },
    { key: 'total_impact_rupees', header: 'Total Impact (INR)' },
  ];

  const riskCols: Column<RiskRow>[] = [
    { key: 'product_line', header: 'Product Line' },
    { key: 'cost_entry_code', header: 'Entry' },
    { key: 'cost_element', header: 'Element' },
    { key: 'variance_driver', header: 'Driver' },
    { key: 'period_month', header: 'Period' },
    { key: 'variance_type', header: 'Type' },
    { key: 'total_variance_rupees', header: 'Total Variance (INR)' },
    { key: 'variance_pct', header: 'Variance %' },
    { key: 'recurring', header: 'Recurring' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Standard-Costing Material/Labor/Overhead Variance Board
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Standard-costing variance analysis across cost elements (material, labor, variable &amp; fixed
        overhead) &times; product line &times; standard vs actual cost &times; price/rate variance
        &times; usage/efficiency variance &times; variance driver (price, usage, efficiency, rate,
        volume, mix) &amp; CAPA closure. Founder-gated view: favorable vs adverse verdicts, cost-element
        scorecards, element &times; driver matrix, monthly trend, root-cause pareto, and a high-risk
        queue for adverse, large, or recurring variances.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Variance-type distribution</h2>
        <DataTable
          rows={typeRows}
          columns={typeCols}
          emptyMessage="No variance entries logged yet."
          rowKey={(r, i) => String(r.variance_type ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Cost-element scorecard</h2>
        <DataTable
          rows={elementRows}
          columns={elementCols}
          emptyMessage="No cost-element rollups."
          rowKey={(r, i) => String(r.cost_element ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Cost element &times; variance driver matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No entries by cost element."
          rowKey={(r, i) => `${r.cost_element}-${r.variance_driver}-${i}`}
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>7. Variance-impact digest</h2>
        <DataTable
          rows={digestRows}
          columns={digestCols}
          emptyMessage="No variance-impact rollups."
          rowKey={(r, i) => String(r.finding_category ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk variance queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk variances."
          rowKey={(r, i) => `${r.cost_entry_code}-${r.period_month}-${i}`}
        />
      </section>
    </main>
  );
}
