import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type RiskRatingRow = {
  risk_rating: string;
  suppliers: number;
  total_spend_rupees: number;
  pct: number;
};
type CategoryRow = {
  spend_category: string;
  suppliers: number;
  total_spend_rupees: number;
  avg_share_pct: number;
  single_source: number;
  severe: number;
  no_contingency: number;
  avg_lead_time_days: number;
};
type MatrixRow = {
  sourcing_status: string;
  criticality: string;
  suppliers: number;
  total_spend_rupees: number;
  severe: number;
  avg_alt_suppliers: number;
};
type TrendRow = {
  period_month: string;
  suppliers: number;
  total_spend_rupees: number;
  severe: number;
  single_source: number;
  no_contingency: number;
};
type CapaRow = {
  capa_status: string;
  findings: number;
  avg_exposure_rupees: number;
  overdue_flag: number;
};
type CauseRow = {
  root_cause: string;
  occurrences: number;
  total_exposure_rupees: number;
  pct: number;
};
type DigestRow = {
  criticality: string;
  suppliers: number;
  total_spend_rupees: number;
  avg_share_pct: number;
  single_source: number;
  severe: number;
};
type QueueRow = {
  supplier_name: string;
  supplier_code: string;
  spend_category: string;
  sourcing_status: string;
  criticality: string;
  risk_rating: string;
  annual_spend_rupees: number;
  spend_share_pct: number;
  lead_time_days: number;
  alt_suppliers_qualified: number;
  contingency_ready: boolean | null;
  notes: string | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    ratingRes,
    categoryRes,
    matrixRes,
    trendRes,
    capaRes,
    causeRes,
    digestRes,
    queueRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3441_risk_rating_rollup'),
    supabase.rpc('founder_r3441_spend_category_scorecard'),
    supabase.rpc('founder_r3441_sourcing_criticality_matrix'),
    supabase.rpc('founder_r3441_monthly_spend_risk_trend'),
    supabase.rpc('founder_r3441_capa_status_board'),
    supabase.rpc('founder_r3441_root_cause_pareto'),
    supabase.rpc('founder_r3441_spend_impact_digest'),
    supabase.rpc('founder_r3441_high_risk_queue'),
  ]);

  const ratingRows: RiskRatingRow[] = (ratingRes.data as RiskRatingRow[]) ?? [];
  const categoryRows: CategoryRow[] = (categoryRes.data as CategoryRow[]) ?? [];
  const matrixRows: MatrixRow[] = (matrixRes.data as MatrixRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const digestRows: DigestRow[] = (digestRes.data as DigestRow[]) ?? [];
  const queueRows: QueueRow[] = (queueRes.data as QueueRow[]) ?? [];

  const ratingCols: Column<RiskRatingRow>[] = [
    { key: 'risk_rating', header: 'Risk Rating' },
    { key: 'suppliers', header: 'Suppliers' },
    { key: 'total_spend_rupees', header: 'Total Spend (INR)' },
    { key: 'pct', header: 'Share %' },
  ];

  const categoryCols: Column<CategoryRow>[] = [
    { key: 'spend_category', header: 'Spend Category' },
    { key: 'suppliers', header: 'Suppliers' },
    { key: 'total_spend_rupees', header: 'Total Spend (INR)' },
    { key: 'avg_share_pct', header: 'Avg Share %' },
    { key: 'single_source', header: 'Single/Sole Source' },
    { key: 'severe', header: 'Severe' },
    { key: 'no_contingency', header: 'No Contingency' },
    { key: 'avg_lead_time_days', header: 'Avg Lead (days)' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'sourcing_status', header: 'Sourcing Status' },
    { key: 'criticality', header: 'Criticality' },
    { key: 'suppliers', header: 'Suppliers' },
    { key: 'total_spend_rupees', header: 'Total Spend (INR)' },
    { key: 'severe', header: 'Severe' },
    { key: 'avg_alt_suppliers', header: 'Avg Qualified Alternates' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'period_month', header: 'Month' },
    { key: 'suppliers', header: 'Suppliers' },
    { key: 'total_spend_rupees', header: 'Total Spend (INR)' },
    { key: 'severe', header: 'Severe' },
    { key: 'single_source', header: 'Single/Sole Source' },
    { key: 'no_contingency', header: 'No Contingency' },
  ];

  const capaCols: Column<CapaRow>[] = [
    { key: 'capa_status', header: 'CAPA Status' },
    { key: 'findings', header: 'Findings' },
    { key: 'avg_exposure_rupees', header: 'Avg Exposure (INR)' },
    { key: 'overdue_flag', header: 'Overdue / Escalated' },
  ];

  const causeCols: Column<CauseRow>[] = [
    { key: 'root_cause', header: 'Root Cause' },
    { key: 'occurrences', header: 'Occurrences' },
    { key: 'total_exposure_rupees', header: 'Total Exposure (INR)' },
    { key: 'pct', header: 'Share %' },
  ];

  const digestCols: Column<DigestRow>[] = [
    { key: 'criticality', header: 'Criticality' },
    { key: 'suppliers', header: 'Suppliers' },
    { key: 'total_spend_rupees', header: 'Total Spend (INR)' },
    { key: 'avg_share_pct', header: 'Avg Share %' },
    { key: 'single_source', header: 'Single/Sole Source' },
    { key: 'severe', header: 'Severe' },
  ];

  const queueCols: Column<QueueRow>[] = [
    { key: 'supplier_name', header: 'Supplier' },
    { key: 'supplier_code', header: 'Code' },
    { key: 'spend_category', header: 'Category' },
    { key: 'sourcing_status', header: 'Sourcing' },
    { key: 'criticality', header: 'Criticality' },
    { key: 'risk_rating', header: 'Risk' },
    { key: 'annual_spend_rupees', header: 'Annual Spend (INR)' },
    { key: 'spend_share_pct', header: 'Share %' },
    { key: 'lead_time_days', header: 'Lead (days)' },
    { key: 'alt_suppliers_qualified', header: 'Alt Qualified' },
    { key: 'contingency_ready', header: 'Contingency' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Supplier-Concentration / Single-Source Dependency-Risk Board
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Founder-gated supplier-concentration &amp; single-source dependency-risk board per spend
        category — supplier &times; category &times; annual spend &times; spend share &times; sourcing
        status (single &amp; sole source vs dual &amp; multi source) &times; qualified alternates
        &times; lead time &times; criticality &times; risk rating &times; contingency readiness &amp;
        CAPA closure. Rollups: risk-rating distribution, spend-category scorecards, sourcing &times;
        criticality matrix, monthly spend/risk trend, CAPA status board, root-cause pareto,
        spend-impact digest, and the high-risk single-source dependency queue.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Risk-rating distribution</h2>
        <DataTable
          rows={ratingRows}
          columns={ratingCols}
          emptyMessage="No supplier risk records yet."
          rowKey={(r, i) => String(r.risk_rating ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Spend-category scorecard</h2>
        <DataTable
          rows={categoryRows}
          columns={categoryCols}
          emptyMessage="No spend-category rollups."
          rowKey={(r, i) => String(r.spend_category ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Sourcing status &times; criticality matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No suppliers by sourcing status."
          rowKey={(r, i) => `${r.sourcing_status}-${r.criticality}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Monthly spend &amp; risk trend</h2>
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>7. Spend-impact digest</h2>
        <DataTable
          rows={digestRows}
          columns={digestCols}
          emptyMessage="No spend-impact rollups."
          rowKey={(r, i) => String(r.criticality ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk dependency queue</h2>
        <DataTable
          rows={queueRows}
          columns={queueCols}
          emptyMessage="No high-risk suppliers."
          rowKey={(r, i) => `${r.supplier_code}-${i}`}
        />
      </section>
    </main>
  );
}
