import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type StatusRow = { catalog_status: string; sections: number; pct: number };
type CategoryRow = {
  category: string;
  sections: number;
  skus: number;
  complete_sections: number;
  poor_quality_sections: number;
  avg_photo_pct: number;
  avg_spec_pct: number;
  avg_pricing_pct: number;
  avg_completeness: number;
};
type MatrixRow = {
  section_class: string;
  catalog_status: string;
  sections: number;
  skus: number;
  avg_completeness: number;
};
type TrendRow = {
  period_month: string;
  sections: number;
  avg_photo_pct: number;
  avg_spec_pct: number;
  avg_pricing_pct: number;
  avg_completeness: number;
  duplicate_listings: number;
  stale_listings: number;
};
type CapaRow = {
  capa_status: string;
  actions: number;
  skus_impacted: number;
  overdue_flag: number;
};
type CauseRow = {
  root_cause: string;
  occurrences: number;
  skus_impacted: number;
  pct: number;
};
type GapRow = {
  gap_category: string;
  actions: number;
  open_actions: number;
  skus_impacted: number;
};
type RiskRow = {
  section_ref: string;
  catalog_section: string;
  category: string;
  period_month: string;
  catalog_status: string;
  trend_dir: string;
  completeness_score: number;
  duplicate_listings: number;
  stale_listings: number;
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
    gapRes,
    riskRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3706_catalog_status_rollup'),
    supabase.rpc('founder_r3706_category_scorecard'),
    supabase.rpc('founder_r3706_section_class_status_matrix'),
    supabase.rpc('founder_r3706_monthly_completeness_trend'),
    supabase.rpc('founder_r3706_capa_status_board'),
    supabase.rpc('founder_r3706_root_cause_pareto'),
    supabase.rpc('founder_r3706_gap_digest'),
    supabase.rpc('founder_r3706_high_risk_queue'),
  ]);

  const statusRows: StatusRow[] = (statusRes.data as StatusRow[]) ?? [];
  const categoryRows: CategoryRow[] = (categoryRes.data as CategoryRow[]) ?? [];
  const matrixRows: MatrixRow[] = (matrixRes.data as MatrixRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const gapRows: GapRow[] = (gapRes.data as GapRow[]) ?? [];
  const riskRows: RiskRow[] = (riskRes.data as RiskRow[]) ?? [];

  const statusCols: Column<StatusRow>[] = [
    { key: 'catalog_status', header: 'Catalog Status' },
    { key: 'sections', header: 'Sections' },
    { key: 'pct', header: 'Share %' },
  ];

  const categoryCols: Column<CategoryRow>[] = [
    { key: 'category', header: 'Category' },
    { key: 'sections', header: 'Sections' },
    { key: 'skus', header: 'SKUs' },
    { key: 'complete_sections', header: 'Complete' },
    { key: 'poor_quality_sections', header: 'Poor Quality' },
    { key: 'avg_photo_pct', header: 'Avg Photo %' },
    { key: 'avg_spec_pct', header: 'Avg Spec %' },
    { key: 'avg_pricing_pct', header: 'Avg Pricing %' },
    { key: 'avg_completeness', header: 'Avg Completeness' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'section_class', header: 'Section Class' },
    { key: 'catalog_status', header: 'Catalog Status' },
    { key: 'sections', header: 'Sections' },
    { key: 'skus', header: 'SKUs' },
    { key: 'avg_completeness', header: 'Avg Completeness' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'period_month', header: 'Month' },
    { key: 'sections', header: 'Sections' },
    { key: 'avg_photo_pct', header: 'Avg Photo %' },
    { key: 'avg_spec_pct', header: 'Avg Spec %' },
    { key: 'avg_pricing_pct', header: 'Avg Pricing %' },
    { key: 'avg_completeness', header: 'Avg Completeness' },
    { key: 'duplicate_listings', header: 'Duplicates' },
    { key: 'stale_listings', header: 'Stale' },
  ];

  const capaCols: Column<CapaRow>[] = [
    { key: 'capa_status', header: 'CAPA Status' },
    { key: 'actions', header: 'Actions' },
    { key: 'skus_impacted', header: 'SKUs Impacted' },
    { key: 'overdue_flag', header: 'Overdue / Escalated' },
  ];

  const causeCols: Column<CauseRow>[] = [
    { key: 'root_cause', header: 'Root Cause' },
    { key: 'occurrences', header: 'Occurrences' },
    { key: 'skus_impacted', header: 'SKUs Impacted' },
    { key: 'pct', header: 'Share %' },
  ];

  const gapCols: Column<GapRow>[] = [
    { key: 'gap_category', header: 'Gap Category' },
    { key: 'actions', header: 'Actions' },
    { key: 'open_actions', header: 'Open' },
    { key: 'skus_impacted', header: 'SKUs Impacted' },
  ];

  const riskCols: Column<RiskRow>[] = [
    { key: 'section_ref', header: 'Section Ref' },
    { key: 'catalog_section', header: 'Catalog Section' },
    { key: 'category', header: 'Category' },
    { key: 'period_month', header: 'Month' },
    { key: 'catalog_status', header: 'Status' },
    { key: 'trend_dir', header: 'Trend' },
    { key: 'completeness_score', header: 'Completeness' },
    { key: 'duplicate_listings', header: 'Duplicates' },
    { key: 'stale_listings', header: 'Stale' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Marketplace SKU-Catalog Completeness / Listing-Quality Board
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Platform catalog listing-quality log — catalog section &times; category &times; photo
        coverage &times; spec-sheet coverage &times; pricing coverage &times; duplicate listings
        &times; stale-listing backlog &times; completeness score &amp; CAPA closure. Founder-gated
        view: catalog-status distribution, category scorecards, section-class &times; status
        matrix, monthly completeness trend, root-cause pareto, gap digest, and the
        poor-quality / spec-gaps high-risk queue across our marketplace SKU catalog.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Catalog status distribution</h2>
        <DataTable
          rows={statusRows}
          columns={statusCols}
          emptyMessage="No catalog sections logged yet."
          rowKey={(r, i) => String(r.catalog_status ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Category completeness scorecard</h2>
        <DataTable
          rows={categoryRows}
          columns={categoryCols}
          emptyMessage="No category rollups."
          rowKey={(r, i) => String(r.category ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Section class &times; catalog status matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No sections by class."
          rowKey={(r, i) => `${r.section_class}-${r.catalog_status}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Monthly completeness trend</h2>
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>7. Gap-category digest</h2>
        <DataTable
          rows={gapRows}
          columns={gapCols}
          emptyMessage="No gap-category rollups."
          rowKey={(r, i) => String(r.gap_category ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk section queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk sections."
          rowKey={(r, i) => `${r.section_ref}-${r.period_month}-${i}`}
        />
      </section>
    </main>
  );
}
