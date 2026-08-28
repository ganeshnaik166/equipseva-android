import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type StatusRow = { control_status: string; entries: number; pct: number };
type CategoryRow = {
  product_category: string;
  periods: number;
  total_quotes_on_stale_list: number;
  total_unauthorized_discount_incidents: number;
  avg_mrp_variance_pct: number | null;
  gst_slab_correct_count: number;
  approval_on_file_count: number;
  avg_distribution_channels_notified: number | null;
};
type MatrixRow = {
  list_class: string;
  control_status: string;
  entries: number;
  total_quotes_on_stale_list: number;
  avg_mrp_variance_pct: number | null;
};
type TrendRow = {
  period_month: string;
  entries: number;
  total_quotes_on_stale_list: number;
  total_unauthorized_discount_incidents: number;
  avg_mrp_variance_pct: number | null;
  worsening_entries: number;
};
type CapaRow = { capa_status: string; actions: number; overdue_flag: number };
type CauseRow = { root_cause: string | null; occurrences: number; pct: number };
type DigestRow = {
  product_category: string;
  entries_with_incidents: number;
  total_unauthorized_discount_incidents: number;
  avg_mrp_variance_pct: number | null;
  approval_on_file_count: number;
};
type RiskRow = {
  price_list_ref: string;
  product_category: string;
  period_month: string;
  list_class: string;
  control_status: string;
  quotes_on_stale_list: number | null;
  unauthorized_discount_incidents: number | null;
  mrp_variance_pct: number | null;
  approval_on_file: boolean;
  trend_dir: string;
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
    supabase.rpc('founder_r3726_control_status_rollup'),
    supabase.rpc('founder_r3726_product_category_scorecard'),
    supabase.rpc('founder_r3726_list_class_status_matrix'),
    supabase.rpc('founder_r3726_monthly_stale_list_trend'),
    supabase.rpc('founder_r3726_capa_status_board'),
    supabase.rpc('founder_r3726_root_cause_pareto'),
    supabase.rpc('founder_r3726_unauthorized_discount_digest'),
    supabase.rpc('founder_r3726_high_risk_queue'),
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
    { key: 'control_status', header: 'Control Status' },
    { key: 'entries', header: 'Entries' },
    { key: 'pct', header: 'Share %' },
  ];

  const categoryCols: Column<CategoryRow>[] = [
    { key: 'product_category', header: 'Product Category' },
    { key: 'periods', header: 'Periods' },
    { key: 'total_quotes_on_stale_list', header: 'Quotes on Stale List' },
    { key: 'total_unauthorized_discount_incidents', header: 'Unauthorized Discounts' },
    { key: 'avg_mrp_variance_pct', header: 'Avg MRP Variance %' },
    { key: 'gst_slab_correct_count', header: 'GST Slab Correct' },
    { key: 'approval_on_file_count', header: 'Approval on File' },
    { key: 'avg_distribution_channels_notified', header: 'Avg Channels Notified' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'list_class', header: 'List Class' },
    { key: 'control_status', header: 'Control Status' },
    { key: 'entries', header: 'Entries' },
    { key: 'total_quotes_on_stale_list', header: 'Quotes on Stale List' },
    { key: 'avg_mrp_variance_pct', header: 'Avg MRP Variance %' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'period_month', header: 'Month' },
    { key: 'entries', header: 'Entries' },
    { key: 'total_quotes_on_stale_list', header: 'Quotes on Stale List' },
    { key: 'total_unauthorized_discount_incidents', header: 'Unauthorized Discounts' },
    { key: 'avg_mrp_variance_pct', header: 'Avg MRP Variance %' },
    { key: 'worsening_entries', header: 'Worsening' },
  ];

  const capaCols: Column<CapaRow>[] = [
    { key: 'capa_status', header: 'CAPA Status' },
    { key: 'actions', header: 'Actions' },
    { key: 'overdue_flag', header: 'Overdue' },
  ];

  const causeCols: Column<CauseRow>[] = [
    { key: 'root_cause', header: 'Root Cause' },
    { key: 'occurrences', header: 'Occurrences' },
    { key: 'pct', header: 'Share %' },
  ];

  const digestCols: Column<DigestRow>[] = [
    { key: 'product_category', header: 'Product Category' },
    { key: 'entries_with_incidents', header: 'Entries w/ Incidents' },
    { key: 'total_unauthorized_discount_incidents', header: 'Unauthorized Discounts' },
    { key: 'avg_mrp_variance_pct', header: 'Avg MRP Variance %' },
    { key: 'approval_on_file_count', header: 'Approval on File' },
  ];

  const riskCols: Column<RiskRow>[] = [
    { key: 'price_list_ref', header: 'Price List Ref' },
    { key: 'product_category', header: 'Product Category' },
    { key: 'period_month', header: 'Month' },
    { key: 'list_class', header: 'List Class' },
    { key: 'control_status', header: 'Control Status' },
    { key: 'quotes_on_stale_list', header: 'Quotes on Stale List' },
    { key: 'unauthorized_discount_incidents', header: 'Unauthorized Discounts' },
    { key: 'mrp_variance_pct', header: 'MRP Variance %' },
    { key: 'approval_on_file', header: 'Approval on File' },
    { key: 'trend_dir', header: 'Trend' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        MRP / Price-List Version-Control &amp; Compliance Board
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Commercial price-list &amp; MRP version-control register &mdash; active vs superseded price
        lists, quotes issued against stale lists, unauthorized discount-beyond-list incidents, GST
        slab correctness &amp; approval-on-file status, per product category &times; list class
        &times; period month, with CAPA closure for version-control breaches. Distinct from any QMS
        controlled-document/SOP board (quality-management documents, not commercial pricing) and
        from any per-deal discount-approval-queue board (a single-deal approval queue, not
        list-version governance). Founder-gated view: control-status distribution, product-category
        scorecards, list-class &times; status matrix, monthly stale-list trend, CAPA closure,
        root-cause pareto, an unauthorized-discount digest, and a high-risk queue of stale &amp;
        unauthorized price-list versions still in use.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Control-status distribution</h2>
        <DataTable
          rows={statusRows}
          columns={statusCols}
          emptyMessage="No price-list rows logged yet."
          rowKey={(r, i) => String(r.control_status ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Product-category scorecard</h2>
        <DataTable
          rows={categoryRows}
          columns={categoryCols}
          emptyMessage="No category rollups."
          rowKey={(r, i) => String(r.product_category ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. List-class &times; status matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No price lists by class."
          rowKey={(r, i) => `${r.list_class}-${r.control_status}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Monthly stale-list trend</h2>
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>6. Root cause pareto</h2>
        <DataTable
          rows={causeRows}
          columns={causeCols}
          emptyMessage="No root-cause data."
          rowKey={(r, i) => String(r.root_cause ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>7. Unauthorized-discount digest</h2>
        <DataTable
          rows={digestRows}
          columns={digestCols}
          emptyMessage="No unauthorized-discount incidents."
          rowKey={(r, i) => String(r.product_category ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk price-list queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk price lists."
          rowKey={(r, i) => `${r.price_list_ref}-${r.period_month}-${i}`}
        />
      </section>
    </main>
  );
}
