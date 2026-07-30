import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type StatusRow = {
  spend_status: string;
  suppliers: number;
  total_spend_rupees: number;
  pct: number;
};
type ScoreRow = {
  category: string;
  suppliers: number;
  total_spend_rupees: number;
  avg_on_contract_pct: number;
  avg_maverick_pct: number;
  savings_realized_rupees: number;
  savings_target_rupees: number;
  savings_attainment_pct: number;
};
type MatrixRow = {
  category: string;
  spend_status: string;
  suppliers: number;
  total_spend_rupees: number;
  avg_price_variance_pct: number;
};
type TrendRow = {
  period_month: string;
  suppliers: number;
  total_spend_rupees: number;
  savings_realized_rupees: number;
  avg_on_contract_pct: number;
  avg_maverick_pct: number;
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
  supplier_name: string;
  supplier_code: string;
  category: string;
  period_month: string;
  spend_rupees: number;
  spend_status: string;
  maverick_spend_pct: number | null;
  on_contract_pct: number | null;
  price_variance_pct: number | null;
  notes: string | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    statusRes,
    scoreRes,
    matrixRes,
    trendRes,
    capaRes,
    causeRes,
    digestRes,
    riskRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3599_spend_status_rollup'),
    supabase.rpc('founder_r3599_category_scorecard'),
    supabase.rpc('founder_r3599_category_status_matrix'),
    supabase.rpc('founder_r3599_monthly_spend_trend'),
    supabase.rpc('founder_r3599_capa_status_board'),
    supabase.rpc('founder_r3599_root_cause_pareto'),
    supabase.rpc('founder_r3599_savings_impact_digest'),
    supabase.rpc('founder_r3599_high_risk_queue'),
  ]);

  const statusRows: StatusRow[] = (statusRes.data as StatusRow[]) ?? [];
  const scoreRows: ScoreRow[] = (scoreRes.data as ScoreRow[]) ?? [];
  const matrixRows: MatrixRow[] = (matrixRes.data as MatrixRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const digestRows: DigestRow[] = (digestRes.data as DigestRow[]) ?? [];
  const riskRows: RiskRow[] = (riskRes.data as RiskRow[]) ?? [];

  const statusCols: Column<StatusRow>[] = [
    { key: 'spend_status', header: 'Spend Status' },
    { key: 'suppliers', header: 'Suppliers' },
    { key: 'total_spend_rupees', header: 'Total Spend (INR)' },
    { key: 'pct', header: 'Share %' },
  ];

  const scoreCols: Column<ScoreRow>[] = [
    { key: 'category', header: 'Category' },
    { key: 'suppliers', header: 'Suppliers' },
    { key: 'total_spend_rupees', header: 'Total Spend (INR)' },
    { key: 'avg_on_contract_pct', header: 'Avg On-Contract %' },
    { key: 'avg_maverick_pct', header: 'Avg Maverick %' },
    { key: 'savings_realized_rupees', header: 'Savings Realized (INR)' },
    { key: 'savings_target_rupees', header: 'Savings Target (INR)' },
    { key: 'savings_attainment_pct', header: 'Savings Attainment %' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'category', header: 'Category' },
    { key: 'spend_status', header: 'Spend Status' },
    { key: 'suppliers', header: 'Suppliers' },
    { key: 'total_spend_rupees', header: 'Total Spend (INR)' },
    { key: 'avg_price_variance_pct', header: 'Avg Price Variance %' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'period_month', header: 'Month' },
    { key: 'suppliers', header: 'Suppliers' },
    { key: 'total_spend_rupees', header: 'Total Spend (INR)' },
    { key: 'savings_realized_rupees', header: 'Savings Realized (INR)' },
    { key: 'avg_on_contract_pct', header: 'Avg On-Contract %' },
    { key: 'avg_maverick_pct', header: 'Avg Maverick %' },
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
    { key: 'supplier_name', header: 'Supplier' },
    { key: 'supplier_code', header: 'Code' },
    { key: 'category', header: 'Category' },
    { key: 'period_month', header: 'Month' },
    { key: 'spend_rupees', header: 'Spend (INR)' },
    { key: 'spend_status', header: 'Status' },
    { key: 'maverick_spend_pct', header: 'Maverick %' },
    { key: 'on_contract_pct', header: 'On-Contract %' },
    { key: 'price_variance_pct', header: 'Price Var %' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Procurement / Supplier Spend-Analysis &amp; Savings Board
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Per-supplier monthly spend-analysis snapshot &mdash; spend concentration by supplier &amp;
        category &times; on-contract vs maverick spend &times; savings realized vs target &times;
        price variance &times; payment terms &times; spend status (strategic, preferred, tail,
        maverick-risk, single-source-risk) &amp; trend direction &amp; CAPA remediation.
        Founder-gated view: spend-status distribution, category scorecards, root-cause pareto,
        savings-impact digest and a high-risk supplier queue across the procurement portfolio.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Spend-status distribution</h2>
        <DataTable
          rows={statusRows}
          columns={statusCols}
          emptyMessage="No spend rows logged yet."
          rowKey={(r, i) => String(r.spend_status ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Category spend scorecard</h2>
        <DataTable
          rows={scoreRows}
          columns={scoreCols}
          emptyMessage="No category rollups."
          rowKey={(r, i) => String(r.category ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Category &times; spend-status matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No spend by category."
          rowKey={(r, i) => `${r.category}-${r.spend_status}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Monthly spend trend</h2>
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>7. Savings-impact digest</h2>
        <DataTable
          rows={digestRows}
          columns={digestCols}
          emptyMessage="No savings-impact rollups."
          rowKey={(r, i) => String(r.finding_category ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk spend queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk suppliers."
          rowKey={(r, i) => `${r.supplier_code}-${r.period_month}-${i}`}
        />
      </section>
    </main>
  );
}
