import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type StatusRow = { run_status: string; runs: number; total_payable_rupees: number; pct: number };
type CategoryRow = {
  supplier_category: string;
  runs: number;
  total_payable_rupees: number;
  discount_captured_rupees: number;
  completed: number;
  on_hold: number;
  deferred: number;
  avg_coverage_ratio: number;
};
type MatrixRow = {
  payment_priority: string;
  run_status: string;
  runs: number;
  total_payable_rupees: number;
  avg_coverage_ratio: number;
};
type TrendRow = {
  period_month: string;
  runs: number;
  total_payable_rupees: number;
  discount_captured_rupees: number;
  completed: number;
  on_hold: number;
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
type LiquidityRow = {
  liquidity_impact: string;
  findings: number;
  open_findings: number;
  total_impact_rupees: number;
};
type RiskRow = {
  payment_batch: string;
  supplier_name: string;
  supplier_category: string;
  scheduled_date: string;
  payment_priority: string;
  run_status: string;
  payable_rupees: number;
  coverage_ratio: number | null;
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
    liquidityRes,
    riskRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3561_run_status_rollup'),
    supabase.rpc('founder_r3561_supplier_category_scorecard'),
    supabase.rpc('founder_r3561_priority_status_matrix'),
    supabase.rpc('founder_r3561_monthly_outflow_trend'),
    supabase.rpc('founder_r3561_capa_status_board'),
    supabase.rpc('founder_r3561_root_cause_pareto'),
    supabase.rpc('founder_r3561_liquidity_impact_digest'),
    supabase.rpc('founder_r3561_high_risk_queue'),
  ]);

  const statusRows: StatusRow[] = (statusRes.data as StatusRow[]) ?? [];
  const categoryRows: CategoryRow[] = (categoryRes.data as CategoryRow[]) ?? [];
  const matrixRows: MatrixRow[] = (matrixRes.data as MatrixRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const liquidityRows: LiquidityRow[] = (liquidityRes.data as LiquidityRow[]) ?? [];
  const riskRows: RiskRow[] = (riskRes.data as RiskRow[]) ?? [];

  const statusCols: Column<StatusRow>[] = [
    { key: 'run_status', header: 'Run Status' },
    { key: 'runs', header: 'Runs' },
    { key: 'total_payable_rupees', header: 'Payable (INR)' },
    { key: 'pct', header: 'Share %' },
  ];

  const categoryCols: Column<CategoryRow>[] = [
    { key: 'supplier_category', header: 'Supplier Category' },
    { key: 'runs', header: 'Runs' },
    { key: 'total_payable_rupees', header: 'Payable (INR)' },
    { key: 'discount_captured_rupees', header: 'Discount (INR)' },
    { key: 'completed', header: 'Completed' },
    { key: 'on_hold', header: 'On Hold' },
    { key: 'deferred', header: 'Deferred' },
    { key: 'avg_coverage_ratio', header: 'Avg Coverage' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'payment_priority', header: 'Priority' },
    { key: 'run_status', header: 'Run Status' },
    { key: 'runs', header: 'Runs' },
    { key: 'total_payable_rupees', header: 'Payable (INR)' },
    { key: 'avg_coverage_ratio', header: 'Avg Coverage' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'period_month', header: 'Month' },
    { key: 'runs', header: 'Runs' },
    { key: 'total_payable_rupees', header: 'Payable (INR)' },
    { key: 'discount_captured_rupees', header: 'Discount (INR)' },
    { key: 'completed', header: 'Completed' },
    { key: 'on_hold', header: 'On Hold' },
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

  const liquidityCols: Column<LiquidityRow>[] = [
    { key: 'liquidity_impact', header: 'Liquidity Impact' },
    { key: 'findings', header: 'Findings' },
    { key: 'open_findings', header: 'Open' },
    { key: 'total_impact_rupees', header: 'Total Impact (INR)' },
  ];

  const riskCols: Column<RiskRow>[] = [
    { key: 'payment_batch', header: 'Batch' },
    { key: 'supplier_name', header: 'Supplier' },
    { key: 'supplier_category', header: 'Category' },
    { key: 'scheduled_date', header: 'Scheduled' },
    { key: 'payment_priority', header: 'Priority' },
    { key: 'run_status', header: 'Status' },
    { key: 'payable_rupees', header: 'Payable (INR)' },
    { key: 'coverage_ratio', header: 'Coverage' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Supplier Payment-Run / Cash-Outflow Calendar Board
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Founder-gated supplier payment-run and cash-outflow calendar — scheduled disbursements &amp;
        liquidity timing across payment batch &times; supplier category (OEM spares, consumables,
        logistics, IT/SaaS, statutory dues, contract labour, utilities, capex) &times; scheduled date
        &times; payable &times; early-pay discount capture &times; available cash &times; coverage ratio
        &times; payment priority &times; run status &amp; CAPA closure. Surfaces run-status mix, category
        scorecards, priority &times; status matrix, monthly outflow trend, root-cause pareto,
        liquidity-impact digest, and the high-risk queue where coverage &lt; 1.0 or critical/statutory
        runs are held or deferred.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Run-status distribution</h2>
        <DataTable
          rows={statusRows}
          columns={statusCols}
          emptyMessage="No payment runs logged yet."
          rowKey={(r, i) => String(r.run_status ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Supplier-category scorecard</h2>
        <DataTable
          rows={categoryRows}
          columns={categoryCols}
          emptyMessage="No category rollups."
          rowKey={(r, i) => String(r.supplier_category ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Priority &times; run-status matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No runs by priority."
          rowKey={(r, i) => `${r.payment_priority}-${r.run_status}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Monthly outflow trend</h2>
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>7. Liquidity-impact digest</h2>
        <DataTable
          rows={liquidityRows}
          columns={liquidityCols}
          emptyMessage="No liquidity-impact rollups."
          rowKey={(r, i) => String(r.liquidity_impact ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk payment-run queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk runs."
          rowKey={(r, i) => `${r.payment_batch}-${r.scheduled_date}-${i}`}
        />
      </section>
    </main>
  );
}
