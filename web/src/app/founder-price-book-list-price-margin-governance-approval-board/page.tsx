import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type ApprovalRow = { approval_status: string; skus: number; pct: number };
type LineRow = {
  product_line: string;
  skus: number;
  within_policy: number;
  needs_approval: number;
  below_floor: number;
  avg_list_margin_pct: number;
  avg_realized_margin_pct: number;
  margin_gap_pct: number;
};
type MatrixRow = {
  discount_band: string;
  approval_status: string;
  skus: number;
  avg_realized_margin_pct: number;
};
type TrendRow = {
  revised_month: string;
  skus: number;
  avg_list_margin_pct: number;
  avg_realized_margin_pct: number;
  below_floor: number;
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
  sku: string;
  product_line: string;
  list_price_rupees: number;
  floor_price_rupees: number;
  avg_realized_price_rupees: number | null;
  realized_margin_pct: number | null;
  discount_band: string;
  approval_status: string;
  price_trend: string;
  notes: string | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    approvalRes,
    lineRes,
    matrixRes,
    trendRes,
    capaRes,
    causeRes,
    digestRes,
    riskRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3457_approval_status_rollup'),
    supabase.rpc('founder_r3457_product_line_scorecard'),
    supabase.rpc('founder_r3457_discount_approval_matrix'),
    supabase.rpc('founder_r3457_monthly_margin_trend'),
    supabase.rpc('founder_r3457_capa_status_board'),
    supabase.rpc('founder_r3457_root_cause_pareto'),
    supabase.rpc('founder_r3457_margin_impact_digest'),
    supabase.rpc('founder_r3457_high_risk_queue'),
  ]);

  const approvalRows: ApprovalRow[] = (approvalRes.data as ApprovalRow[]) ?? [];
  const lineRows: LineRow[] = (lineRes.data as LineRow[]) ?? [];
  const matrixRows: MatrixRow[] = (matrixRes.data as MatrixRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const digestRows: DigestRow[] = (digestRes.data as DigestRow[]) ?? [];
  const riskRows: RiskRow[] = (riskRes.data as RiskRow[]) ?? [];

  const approvalCols: Column<ApprovalRow>[] = [
    { key: 'approval_status', header: 'Approval Status' },
    { key: 'skus', header: 'SKUs' },
    { key: 'pct', header: 'Share %' },
  ];

  const lineCols: Column<LineRow>[] = [
    { key: 'product_line', header: 'Product Line' },
    { key: 'skus', header: 'SKUs' },
    { key: 'within_policy', header: 'Within Policy' },
    { key: 'needs_approval', header: 'Needs Approval' },
    { key: 'below_floor', header: 'Below Floor' },
    { key: 'avg_list_margin_pct', header: 'Avg List Margin %' },
    { key: 'avg_realized_margin_pct', header: 'Avg Realized Margin %' },
    { key: 'margin_gap_pct', header: 'Margin Gap %' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'discount_band', header: 'Discount Band' },
    { key: 'approval_status', header: 'Approval Status' },
    { key: 'skus', header: 'SKUs' },
    { key: 'avg_realized_margin_pct', header: 'Avg Realized Margin %' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'revised_month', header: 'Revised Month' },
    { key: 'skus', header: 'SKUs' },
    { key: 'avg_list_margin_pct', header: 'Avg List Margin %' },
    { key: 'avg_realized_margin_pct', header: 'Avg Realized Margin %' },
    { key: 'below_floor', header: 'Below Floor' },
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
    { key: 'sku', header: 'SKU' },
    { key: 'product_line', header: 'Product Line' },
    { key: 'list_price_rupees', header: 'List (INR)' },
    { key: 'floor_price_rupees', header: 'Floor (INR)' },
    { key: 'avg_realized_price_rupees', header: 'Realized (INR)' },
    { key: 'realized_margin_pct', header: 'Realized Margin %' },
    { key: 'discount_band', header: 'Discount Band' },
    { key: 'approval_status', header: 'Approval Status' },
    { key: 'price_trend', header: 'Trend' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Price-Book / List-Price Margin-Governance &amp; Approval Board
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Founder-gated price-book governance — SKU &times; product line &times; list / floor / realized
        price &times; standard cost &times; list &amp; realized margin &times; discount band &times;
        approval status &times; price trend, with margin-floor enforcement and discount-approval bands.
        Rollups cover approval-status distribution, product-line scorecards, discount-band &times;
        approval matrix, monthly margin trend, CAPA status, root-cause pareto, margin-impact digest, and
        a high-risk queue of below-floor, awaiting-approval &amp; eroding-margin SKUs.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Approval-status distribution</h2>
        <DataTable
          rows={approvalRows}
          columns={approvalCols}
          emptyMessage="No price-book rows logged yet."
          rowKey={(r, i) => String(r.approval_status ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Product-line margin scorecard</h2>
        <DataTable
          rows={lineRows}
          columns={lineCols}
          emptyMessage="No product-line rollups."
          rowKey={(r, i) => String(r.product_line ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Discount-band &times; approval-status matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No discount-band data."
          rowKey={(r, i) => `${r.discount_band}-${r.approval_status}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Monthly margin trend</h2>
        <DataTable
          rows={trendRows}
          columns={trendCols}
          emptyMessage="No trend data."
          rowKey={(r, i) => String(r.revised_month ?? i)}
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>7. Margin-impact digest</h2>
        <DataTable
          rows={digestRows}
          columns={digestCols}
          emptyMessage="No margin-impact rollups."
          rowKey={(r, i) => String(r.finding_category ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk SKUs."
          rowKey={(r, i) => `${r.sku}-${i}`}
        />
      </section>
    </main>
  );
}
