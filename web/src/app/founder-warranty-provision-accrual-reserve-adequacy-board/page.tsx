import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type AdequacyRow = { reserve_adequacy: string; lines: number; pct: number };
type ScorecardRow = {
  product_line: string;
  total_lines: number;
  adequate: number;
  marginal: number;
  under_reserved: number;
  over_reserved: number;
  units_under_warranty: number;
  provision_balance_rupees: number;
  claims_incurred_rupees: number;
  avg_utilization_pct: number;
};
type MatrixRow = {
  warranty_type: string;
  reserve_adequacy: string;
  lines: number;
  provision_balance_rupees: number;
  claims_incurred_rupees: number;
  avg_utilization_pct: number;
};
type TrendRow = {
  period_month: string;
  lines: number;
  provision_balance_rupees: number;
  claims_paid_ytd_rupees: number;
  claims_incurred_rupees: number;
  avg_utilization_pct: number;
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
type ImpactRow = {
  provision_impact_class: string;
  findings: number;
  open_findings: number;
  total_impact_rupees: number;
};
type RiskRow = {
  product_line: string;
  provision_ref: string;
  warranty_type: string;
  period_month: string;
  reserve_adequacy: string;
  provision_balance_rupees: number | null;
  claims_incurred_rupees: number | null;
  utilization_pct: number | null;
  cost_trend: string | null;
  notes: string | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    adequacyRes,
    scorecardRes,
    matrixRes,
    trendRes,
    capaRes,
    causeRes,
    impactRes,
    riskRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3437_reserve_adequacy_rollup'),
    supabase.rpc('founder_r3437_product_line_scorecard'),
    supabase.rpc('founder_r3437_warranty_type_adequacy_matrix'),
    supabase.rpc('founder_r3437_monthly_provision_trend'),
    supabase.rpc('founder_r3437_capa_status_board'),
    supabase.rpc('founder_r3437_root_cause_pareto'),
    supabase.rpc('founder_r3437_financial_impact_digest'),
    supabase.rpc('founder_r3437_high_risk_queue'),
  ]);

  const adequacyRows: AdequacyRow[] = (adequacyRes.data as AdequacyRow[]) ?? [];
  const scorecardRows: ScorecardRow[] = (scorecardRes.data as ScorecardRow[]) ?? [];
  const matrixRows: MatrixRow[] = (matrixRes.data as MatrixRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const impactRows: ImpactRow[] = (impactRes.data as ImpactRow[]) ?? [];
  const riskRows: RiskRow[] = (riskRes.data as RiskRow[]) ?? [];

  const adequacyCols: Column<AdequacyRow>[] = [
    { key: 'reserve_adequacy', header: 'Reserve Adequacy' },
    { key: 'lines', header: 'Lines' },
    { key: 'pct', header: 'Share %' },
  ];

  const scorecardCols: Column<ScorecardRow>[] = [
    { key: 'product_line', header: 'Product Line' },
    { key: 'total_lines', header: 'Lines' },
    { key: 'adequate', header: 'Adequate' },
    { key: 'marginal', header: 'Marginal' },
    { key: 'under_reserved', header: 'Under-Reserved' },
    { key: 'over_reserved', header: 'Over-Reserved' },
    { key: 'units_under_warranty', header: 'Units' },
    { key: 'provision_balance_rupees', header: 'Provision Bal (INR)' },
    { key: 'claims_incurred_rupees', header: 'Claims Incurred (INR)' },
    { key: 'avg_utilization_pct', header: 'Avg Util %' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'warranty_type', header: 'Warranty Type' },
    { key: 'reserve_adequacy', header: 'Reserve Adequacy' },
    { key: 'lines', header: 'Lines' },
    { key: 'provision_balance_rupees', header: 'Provision Bal (INR)' },
    { key: 'claims_incurred_rupees', header: 'Claims Incurred (INR)' },
    { key: 'avg_utilization_pct', header: 'Avg Util %' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'period_month', header: 'Month' },
    { key: 'lines', header: 'Lines' },
    { key: 'provision_balance_rupees', header: 'Provision Bal (INR)' },
    { key: 'claims_paid_ytd_rupees', header: 'Claims Paid YTD (INR)' },
    { key: 'claims_incurred_rupees', header: 'Claims Incurred (INR)' },
    { key: 'avg_utilization_pct', header: 'Avg Util %' },
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

  const impactCols: Column<ImpactRow>[] = [
    { key: 'provision_impact_class', header: 'Impact Class' },
    { key: 'findings', header: 'Findings' },
    { key: 'open_findings', header: 'Open' },
    { key: 'total_impact_rupees', header: 'Total Impact (INR)' },
  ];

  const riskCols: Column<RiskRow>[] = [
    { key: 'product_line', header: 'Product Line' },
    { key: 'provision_ref', header: 'Ref' },
    { key: 'warranty_type', header: 'Type' },
    { key: 'period_month', header: 'Month' },
    { key: 'reserve_adequacy', header: 'Adequacy' },
    { key: 'provision_balance_rupees', header: 'Provision Bal (INR)' },
    { key: 'claims_incurred_rupees', header: 'Claims Incurred (INR)' },
    { key: 'utilization_pct', header: 'Util %' },
    { key: 'cost_trend', header: 'Cost Trend' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Warranty-Provision Accrual / Reserve-Adequacy Board
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Founder-gated warranty-provision board — accrual vs actual claims and reserve adequacy per
        product line &times; warranty type (standard, extended, AMC-bundled &amp; goodwill) &times;
        units under warranty &times; provision rate &times; provision balance &times; claims paid YTD
        &amp; incurred &times; utilization &times; monthly MTM trend &amp; CAPA closure. Surfaces
        reserve-adequacy distribution, product-line scorecards, root-cause pareto, financial-impact
        digest, and an under-reserved / rising-cost high-risk queue.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Reserve-adequacy distribution</h2>
        <DataTable
          rows={adequacyRows}
          columns={adequacyCols}
          emptyMessage="No provision lines logged yet."
          rowKey={(r, i) => String(r.reserve_adequacy ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Product-line provision scorecard</h2>
        <DataTable
          rows={scorecardRows}
          columns={scorecardCols}
          emptyMessage="No product-line rollups."
          rowKey={(r, i) => String(r.product_line ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Warranty type &times; reserve-adequacy matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No lines by warranty type."
          rowKey={(r, i) => `${r.warranty_type}-${r.reserve_adequacy}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Monthly provision / MTM trend</h2>
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>7. Financial-impact digest</h2>
        <DataTable
          rows={impactRows}
          columns={impactCols}
          emptyMessage="No financial-impact rollups."
          rowKey={(r, i) => String(r.provision_impact_class ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk provision queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk provision lines."
          rowKey={(r, i) => `${r.provision_ref}-${r.period_month}-${i}`}
        />
      </section>
    </main>
  );
}
