import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type VerdictRow = { procurement_verdict: string; deals: number; pct: number };
type CategoryRow = {
  category: string;
  deals: number;
  target_beaten: number;
  on_target: number;
  below_target: number;
  single_source_deals: number;
  total_savings_rupees: number;
  avg_savings_pct: number;
};
type MatrixRow = {
  category: string;
  sourcing_event: string;
  deals: number;
  total_savings_rupees: number;
  avg_savings_pct: number;
  realized: number;
};
type TrendRow = {
  contract_start: string;
  deals: number;
  total_baseline_rupees: number;
  total_negotiated_rupees: number;
  total_savings_rupees: number;
  realized: number;
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
type DigestRow = {
  savings_type: string;
  deals: number;
  total_savings_rupees: number;
  realized_savings_rupees: number;
  avg_savings_pct: number;
};
type RiskRow = {
  procurement_ref: string;
  category: string;
  vendor: string;
  sourcing_event: string;
  contract_start: string;
  procurement_verdict: string;
  savings_pct: number | null;
  savings_type: string;
  single_source_risk: boolean;
  notes: string | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    verdictRes,
    categoryRes,
    matrixRes,
    trendRes,
    capaRes,
    causeRes,
    digestRes,
    riskRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3309_verdict_rollup'),
    supabase.rpc('founder_r3309_category_scorecard'),
    supabase.rpc('founder_r3309_category_sourcing_matrix'),
    supabase.rpc('founder_r3309_savings_trend'),
    supabase.rpc('founder_r3309_capa_status_board'),
    supabase.rpc('founder_r3309_root_cause_pareto'),
    supabase.rpc('founder_r3309_savings_type_digest'),
    supabase.rpc('founder_r3309_high_risk_queue'),
  ]);

  const verdictRows: VerdictRow[] = (verdictRes.data as VerdictRow[]) ?? [];
  const categoryRows: CategoryRow[] = (categoryRes.data as CategoryRow[]) ?? [];
  const matrixRows: MatrixRow[] = (matrixRes.data as MatrixRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const digestRows: DigestRow[] = (digestRes.data as DigestRow[]) ?? [];
  const riskRows: RiskRow[] = (riskRes.data as RiskRow[]) ?? [];

  const verdictCols: Column<VerdictRow>[] = [
    { key: 'procurement_verdict', header: 'Verdict' },
    { key: 'deals', header: 'Deals' },
    { key: 'pct', header: 'Share %' },
  ];

  const categoryCols: Column<CategoryRow>[] = [
    { key: 'category', header: 'Category' },
    { key: 'deals', header: 'Deals' },
    { key: 'target_beaten', header: 'Target Beaten' },
    { key: 'on_target', header: 'On Target' },
    { key: 'below_target', header: 'Below / Renegotiate' },
    { key: 'single_source_deals', header: 'Single-Source' },
    { key: 'total_savings_rupees', header: 'Total Savings (INR)' },
    { key: 'avg_savings_pct', header: 'Avg Savings %' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'category', header: 'Category' },
    { key: 'sourcing_event', header: 'Sourcing Event' },
    { key: 'deals', header: 'Deals' },
    { key: 'total_savings_rupees', header: 'Total Savings (INR)' },
    { key: 'avg_savings_pct', header: 'Avg Savings %' },
    { key: 'realized', header: 'Realized' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'contract_start', header: 'Contract Start' },
    { key: 'deals', header: 'Deals' },
    { key: 'total_baseline_rupees', header: 'Baseline (INR)' },
    { key: 'total_negotiated_rupees', header: 'Negotiated (INR)' },
    { key: 'total_savings_rupees', header: 'Savings (INR)' },
    { key: 'realized', header: 'Realized' },
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

  const digestCols: Column<DigestRow>[] = [
    { key: 'savings_type', header: 'Savings Type' },
    { key: 'deals', header: 'Deals' },
    { key: 'total_savings_rupees', header: 'Total Savings (INR)' },
    { key: 'realized_savings_rupees', header: 'Realized Savings (INR)' },
    { key: 'avg_savings_pct', header: 'Avg Savings %' },
  ];

  const riskCols: Column<RiskRow>[] = [
    { key: 'procurement_ref', header: 'Ref' },
    { key: 'category', header: 'Category' },
    { key: 'vendor', header: 'Vendor' },
    { key: 'sourcing_event', header: 'Sourcing Event' },
    { key: 'contract_start', header: 'Start' },
    { key: 'procurement_verdict', header: 'Verdict' },
    { key: 'savings_pct', header: 'Savings %' },
    { key: 'savings_type', header: 'Savings Type' },
    { key: 'single_source_risk', header: 'Single-Source Risk' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Founder Procurement Cost-Savings, Should-Cost &amp; Vendor-Negotiation Board
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Purchasing governance — category &times; vendor &times; sourcing-event &times; baseline vs
        should-cost vs negotiated cost &times; savings &#8377; &amp; % &times; savings-type &times;
        payment-terms &times; single-source risk &times; procurement verdict &amp; CAPA closure.
        Founder-gated view: verdict rollups, category scorecards, root-cause pareto and savings-type
        digest across spares, test-tools, logistics, IT/SaaS &amp; professional-services spend.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Procurement verdict distribution</h2>
        <DataTable
          rows={verdictRows}
          columns={verdictCols}
          emptyMessage="No procurements logged yet."
          rowKey={(r, i) => String(r.procurement_verdict ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Category savings scorecard</h2>
        <DataTable
          rows={categoryRows}
          columns={categoryCols}
          emptyMessage="No category rollups."
          rowKey={(r, i) => String(r.category ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Category &times; sourcing-event matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No deals by category."
          rowKey={(r, i) => `${r.category}-${r.sourcing_event}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Contract-start savings trend</h2>
        <DataTable
          rows={trendRows}
          columns={trendCols}
          emptyMessage="No trend data."
          rowKey={(r, i) => String(r.contract_start ?? i)}
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>7. Savings-type cost digest</h2>
        <DataTable
          rows={digestRows}
          columns={digestCols}
          emptyMessage="No savings-type rollups."
          rowKey={(r, i) => String(r.savings_type ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk procurement queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk procurements."
          rowKey={(r, i) => `${r.procurement_ref}-${r.contract_start}-${i}`}
        />
      </section>
    </main>
  );
}
