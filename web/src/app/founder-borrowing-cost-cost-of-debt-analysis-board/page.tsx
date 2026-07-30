import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type StatusRow = { cost_status: string; facilities: number; pct: number };
type UnitRow = {
  business_unit: string;
  facilities: number;
  total_outstanding_rupees: number;
  total_interest_rupees: number;
  avg_effective_rate_pct: number;
  avg_spread_bps: number;
  avg_hedged_pct: number;
  expensive: number;
};
type MatrixRow = {
  business_unit: string;
  cost_status: string;
  facilities: number;
  total_outstanding_rupees: number;
  avg_effective_rate_pct: number;
};
type TrendRow = {
  period_month: string;
  facilities: number;
  total_outstanding_rupees: number;
  total_interest_rupees: number;
  weighted_avg_cost_pct: number;
  avg_spread_bps: number;
};
type CapaRow = {
  capa_status: string;
  actions: number;
  avg_savings_rupees: number;
  overdue_flag: number;
};
type CauseRow = {
  root_cause: string;
  occurrences: number;
  total_savings_rupees: number;
  pct: number;
};
type DigestRow = {
  trend_dir: string;
  facilities: number;
  total_outstanding_rupees: number;
  total_interest_rupees: number;
  avg_effective_rate_pct: number;
  avg_spread_bps: number;
};
type RiskRow = {
  facility_name: string;
  business_unit: string;
  period_month: string;
  outstanding_rupees: number;
  effective_rate_pct: number;
  benchmark_rate_pct: number;
  spread_bps: number;
  hedged_pct: number;
  cost_status: string;
  trend_dir: string;
  notes: string | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    statusRes,
    unitRes,
    matrixRes,
    trendRes,
    capaRes,
    causeRes,
    digestRes,
    riskRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3611_cost_status_rollup'),
    supabase.rpc('founder_r3611_business_unit_scorecard'),
    supabase.rpc('founder_r3611_business_unit_status_matrix'),
    supabase.rpc('founder_r3611_monthly_cost_trend'),
    supabase.rpc('founder_r3611_capa_status_board'),
    supabase.rpc('founder_r3611_root_cause_pareto'),
    supabase.rpc('founder_r3611_interest_cost_digest'),
    supabase.rpc('founder_r3611_high_risk_queue'),
  ]);

  const statusRows: StatusRow[] = (statusRes.data as StatusRow[]) ?? [];
  const unitRows: UnitRow[] = (unitRes.data as UnitRow[]) ?? [];
  const matrixRows: MatrixRow[] = (matrixRes.data as MatrixRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const digestRows: DigestRow[] = (digestRes.data as DigestRow[]) ?? [];
  const riskRows: RiskRow[] = (riskRes.data as RiskRow[]) ?? [];

  const statusCols: Column<StatusRow>[] = [
    { key: 'cost_status', header: 'Cost Status' },
    { key: 'facilities', header: 'Facilities' },
    { key: 'pct', header: 'Share %' },
  ];

  const unitCols: Column<UnitRow>[] = [
    { key: 'business_unit', header: 'Business Unit' },
    { key: 'facilities', header: 'Facilities' },
    { key: 'total_outstanding_rupees', header: 'Outstanding (INR)' },
    { key: 'total_interest_rupees', header: 'Interest (INR)' },
    { key: 'avg_effective_rate_pct', header: 'Avg Eff Rate %' },
    { key: 'avg_spread_bps', header: 'Avg Spread bps' },
    { key: 'avg_hedged_pct', header: 'Avg Hedged %' },
    { key: 'expensive', header: 'Expensive / Distressed' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'business_unit', header: 'Business Unit' },
    { key: 'cost_status', header: 'Cost Status' },
    { key: 'facilities', header: 'Facilities' },
    { key: 'total_outstanding_rupees', header: 'Outstanding (INR)' },
    { key: 'avg_effective_rate_pct', header: 'Avg Eff Rate %' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'period_month', header: 'Month' },
    { key: 'facilities', header: 'Facilities' },
    { key: 'total_outstanding_rupees', header: 'Outstanding (INR)' },
    { key: 'total_interest_rupees', header: 'Interest (INR)' },
    { key: 'weighted_avg_cost_pct', header: 'Wtd Avg Cost %' },
    { key: 'avg_spread_bps', header: 'Avg Spread bps' },
  ];

  const capaCols: Column<CapaRow>[] = [
    { key: 'capa_status', header: 'CAPA Status' },
    { key: 'actions', header: 'Actions' },
    { key: 'avg_savings_rupees', header: 'Avg Savings (INR)' },
    { key: 'overdue_flag', header: 'Overdue / Escalated' },
  ];

  const causeCols: Column<CauseRow>[] = [
    { key: 'root_cause', header: 'Root Cause' },
    { key: 'occurrences', header: 'Occurrences' },
    { key: 'total_savings_rupees', header: 'Total Savings (INR)' },
    { key: 'pct', header: 'Share %' },
  ];

  const digestCols: Column<DigestRow>[] = [
    { key: 'trend_dir', header: 'Cost Trend' },
    { key: 'facilities', header: 'Facilities' },
    { key: 'total_outstanding_rupees', header: 'Outstanding (INR)' },
    { key: 'total_interest_rupees', header: 'Interest (INR)' },
    { key: 'avg_effective_rate_pct', header: 'Avg Eff Rate %' },
    { key: 'avg_spread_bps', header: 'Avg Spread bps' },
  ];

  const riskCols: Column<RiskRow>[] = [
    { key: 'facility_name', header: 'Facility' },
    { key: 'business_unit', header: 'Unit' },
    { key: 'period_month', header: 'Month' },
    { key: 'outstanding_rupees', header: 'Outstanding (INR)' },
    { key: 'effective_rate_pct', header: 'Eff Rate %' },
    { key: 'benchmark_rate_pct', header: 'Benchmark %' },
    { key: 'spread_bps', header: 'Spread bps' },
    { key: 'hedged_pct', header: 'Hedged %' },
    { key: 'cost_status', header: 'Status' },
    { key: 'trend_dir', header: 'Trend' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Borrowing-Cost / Cost-of-Debt Analysis Board
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Founder-gated cost-of-debt analytics across the borrowing book &mdash; per-facility effective
        rate vs benchmark, spread in bps, weighted-average cost, hedged share &amp; fixed/floating mix
        by business unit (AMC services, spare parts, projects, diagnostics, rentals &amp; working
        capital). Surfaces cost-status distribution, business-unit scorecards, a business-unit
        &times; cost-status matrix, the monthly cost-of-debt trend, CAPA remediation board,
        root-cause pareto, an interest-cost digest &amp; a high-risk queue for facilities that are
        above-market, expensive or distressed.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Cost-status distribution</h2>
        <DataTable
          rows={statusRows}
          columns={statusCols}
          emptyMessage="No facilities logged yet."
          rowKey={(r, i) => String(r.cost_status ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Business-unit scorecard</h2>
        <DataTable
          rows={unitRows}
          columns={unitCols}
          emptyMessage="No business-unit rollups."
          rowKey={(r, i) => String(r.business_unit ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Business unit &times; cost-status matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No facilities by business unit."
          rowKey={(r, i) => `${r.business_unit}-${r.cost_status}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Monthly cost-of-debt trend</h2>
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>6. Root-cause pareto</h2>
        <DataTable
          rows={causeRows}
          columns={causeCols}
          emptyMessage="No root-cause data."
          rowKey={(r, i) => String(r.root_cause ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>7. Interest-cost digest</h2>
        <DataTable
          rows={digestRows}
          columns={digestCols}
          emptyMessage="No interest-cost rollups."
          rowKey={(r, i) => String(r.trend_dir ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk facility queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk facilities."
          rowKey={(r, i) => `${r.facility_name}-${r.period_month}-${i}`}
        />
      </section>
    </main>
  );
}
