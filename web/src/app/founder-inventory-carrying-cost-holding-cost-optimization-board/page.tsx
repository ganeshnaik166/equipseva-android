import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type StatusRow = { cost_status: string; lines: number; pct: number };
type CategoryRow = {
  category: string;
  total_lines: number;
  optimal: number;
  acceptable: number;
  elevated: number;
  excessive: number;
  total_carrying_cost_rupees: number;
  avg_carrying_cost_pct: number;
  avg_target_pct: number;
};
type MatrixRow = {
  category: string;
  cost_status: string;
  lines: number;
  total_carrying_cost_rupees: number;
  avg_carrying_cost_pct: number;
};
type TrendRow = {
  period_month: string;
  lines: number;
  total_carrying_cost_rupees: number;
  total_capital_cost_rupees: number;
  total_obsolescence_cost_rupees: number;
  avg_carrying_cost_pct: number;
};
type CapaRow = {
  capa_status: string;
  findings: number;
  avg_savings_impact_rupees: number;
  overdue_flag: number;
};
type CauseRow = {
  root_cause: string;
  occurrences: number;
  total_savings_impact_rupees: number;
  pct: number;
};
type DigestRow = {
  finding_category: string;
  findings: number;
  open_findings: number;
  total_savings_impact_rupees: number;
};
type RiskRow = {
  category: string;
  warehouse: string;
  sku_code: string;
  period_month: string;
  cost_status: string;
  carrying_cost_pct: number;
  target_pct: number;
  total_carrying_cost_rupees: number;
  trend_dir: string | null;
  notes: string | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    statusRes,
    categoryRes,
    matrixRes,
    trendRes,
    capaRes,
    causeRes,
    digestRes,
    riskRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3553_cost_status_rollup'),
    supabase.rpc('founder_r3553_category_scorecard'),
    supabase.rpc('founder_r3553_category_status_matrix'),
    supabase.rpc('founder_r3553_monthly_carrying_cost_trend'),
    supabase.rpc('founder_r3553_capa_status_board'),
    supabase.rpc('founder_r3553_root_cause_pareto'),
    supabase.rpc('founder_r3553_carrying_cost_impact_digest'),
    supabase.rpc('founder_r3553_high_risk_queue'),
  ]);

  const statusRows: StatusRow[] = (statusRes.data as StatusRow[]) ?? [];
  const categoryRows: CategoryRow[] = (categoryRes.data as CategoryRow[]) ?? [];
  const matrixRows: MatrixRow[] = (matrixRes.data as MatrixRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const digestRows: DigestRow[] = (digestRes.data as DigestRow[]) ?? [];
  const riskRows: RiskRow[] = (riskRes.data as RiskRow[]) ?? [];

  const statusCols: Column<StatusRow>[] = [
    { key: 'cost_status', header: 'Cost Status' },
    { key: 'lines', header: 'Lines' },
    { key: 'pct', header: 'Share %' },
  ];

  const categoryCols: Column<CategoryRow>[] = [
    { key: 'category', header: 'Category' },
    { key: 'total_lines', header: 'Lines' },
    { key: 'optimal', header: 'Optimal' },
    { key: 'acceptable', header: 'Acceptable' },
    { key: 'elevated', header: 'Elevated' },
    { key: 'excessive', header: 'Excessive' },
    { key: 'total_carrying_cost_rupees', header: 'Total Carrying Cost (INR)' },
    { key: 'avg_carrying_cost_pct', header: 'Avg Carrying %' },
    { key: 'avg_target_pct', header: 'Avg Target %' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'category', header: 'Category' },
    { key: 'cost_status', header: 'Cost Status' },
    { key: 'lines', header: 'Lines' },
    { key: 'total_carrying_cost_rupees', header: 'Total Carrying Cost (INR)' },
    { key: 'avg_carrying_cost_pct', header: 'Avg Carrying %' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'period_month', header: 'Month' },
    { key: 'lines', header: 'Lines' },
    { key: 'total_carrying_cost_rupees', header: 'Total Carrying Cost (INR)' },
    { key: 'total_capital_cost_rupees', header: 'Capital Cost (INR)' },
    { key: 'total_obsolescence_cost_rupees', header: 'Obsolescence Cost (INR)' },
    { key: 'avg_carrying_cost_pct', header: 'Avg Carrying %' },
  ];

  const capaCols: Column<CapaRow>[] = [
    { key: 'capa_status', header: 'CAPA Status' },
    { key: 'findings', header: 'Findings' },
    { key: 'avg_savings_impact_rupees', header: 'Avg Savings Impact (INR)' },
    { key: 'overdue_flag', header: 'Overdue / Escalated' },
  ];

  const causeCols: Column<CauseRow>[] = [
    { key: 'root_cause', header: 'Root Cause' },
    { key: 'occurrences', header: 'Occurrences' },
    { key: 'total_savings_impact_rupees', header: 'Total Savings Impact (INR)' },
    { key: 'pct', header: 'Share %' },
  ];

  const digestCols: Column<DigestRow>[] = [
    { key: 'finding_category', header: 'Finding Category' },
    { key: 'findings', header: 'Findings' },
    { key: 'open_findings', header: 'Open' },
    { key: 'total_savings_impact_rupees', header: 'Total Savings Impact (INR)' },
  ];

  const riskCols: Column<RiskRow>[] = [
    { key: 'category', header: 'Category' },
    { key: 'warehouse', header: 'Warehouse' },
    { key: 'sku_code', header: 'SKU' },
    { key: 'period_month', header: 'Month' },
    { key: 'cost_status', header: 'Status' },
    { key: 'carrying_cost_pct', header: 'Carrying %' },
    { key: 'target_pct', header: 'Target %' },
    { key: 'total_carrying_cost_rupees', header: 'Total Carrying Cost (INR)' },
    { key: 'trend_dir', header: 'Trend' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Inventory Carrying-Cost / Holding-Cost Optimization Board
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Inventory carrying / holding cost optimization &mdash; capital lock-up + storage +
        obsolescence + insurance across category &times; warehouse. Each line tracks average
        inventory value, the four cost components, total carrying cost, carrying-cost % vs
        target %, cost status (optimal &rarr; excessive) &amp; month-on-month trend, plus CAPA
        closure. Founder-gated view: cost-status distribution, category scorecards, root-cause
        pareto, and a savings-impact digest for lines where carrying cost &gt; target.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Cost-status distribution</h2>
        <DataTable
          rows={statusRows}
          columns={statusCols}
          emptyMessage="No carrying-cost lines logged yet."
          rowKey={(r, i) => String(r.cost_status ?? i)}
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Category &times; cost-status matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No lines by category."
          rowKey={(r, i) => `${r.category}-${r.cost_status}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Monthly carrying-cost trend</h2>
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>6. Root-cause pareto</h2>
        <DataTable
          rows={causeRows}
          columns={causeCols}
          emptyMessage="No root-cause data."
          rowKey={(r, i) => String(r.root_cause ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>7. Carrying-cost impact digest</h2>
        <DataTable
          rows={digestRows}
          columns={digestCols}
          emptyMessage="No impact digest rows."
          rowKey={(r, i) => String(r.finding_category ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk carrying-cost queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk lines."
          rowKey={(r, i) => `${r.sku_code}-${r.period_month}-${i}`}
        />
      </section>
    </main>
  );
}
