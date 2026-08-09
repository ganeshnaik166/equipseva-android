import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type StatusRow = { discovery_status: string; surfaces: number; pct: number };
type SurfaceRow = {
  platform_surface: string;
  gap_rows: number;
  healthy: number;
  gap_emerging: number;
  high_zero_rate: number;
  catalog_gap: number;
  broken_relevance: number;
  searches: number;
  avg_zero_pct: number;
  avg_ctr_pct: number;
};
type MatrixRow = {
  surface_class: string;
  discovery_status: string;
  gap_rows: number;
  searches: number;
  avg_zero_pct: number;
};
type TrendRow = {
  period_month: string;
  gap_rows: number;
  searches: number;
  zero_results: number;
  avg_zero_pct: number;
  avg_ctr_pct: number;
};
type CapaRow = {
  capa_status: string;
  actions: number;
  avg_zero_searches_impacted: number;
  overdue_flag: number;
};
type CauseRow = {
  root_cause: string;
  occurrences: number;
  total_zero_searches_impacted: number;
  pct: number;
};
type TermRow = {
  top_missing_term: string;
  mentions: number;
  zero_searches: number;
  avg_zero_pct: number;
  synonyms_added: number;
  catalog_gaps: number;
};
type RiskRow = {
  gap_code: string;
  search_category: string;
  platform_surface: string;
  period_month: string;
  zero_result_pct: number | null;
  abandonment_pct: number | null;
  top_missing_term: string | null;
  discovery_status: string;
  trend_dir: string;
  notes: string | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    statusRes,
    surfaceRes,
    matrixRes,
    trendRes,
    capaRes,
    causeRes,
    termRes,
    riskRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3699_discovery_status_rollup'),
    supabase.rpc('founder_r3699_surface_scorecard'),
    supabase.rpc('founder_r3699_surface_class_status_matrix'),
    supabase.rpc('founder_r3699_monthly_zero_rate_trend'),
    supabase.rpc('founder_r3699_capa_status_board'),
    supabase.rpc('founder_r3699_root_cause_pareto'),
    supabase.rpc('founder_r3699_missing_term_digest'),
    supabase.rpc('founder_r3699_high_risk_queue'),
  ]);

  const statusRows: StatusRow[] = (statusRes.data as StatusRow[]) ?? [];
  const surfaceRows: SurfaceRow[] = (surfaceRes.data as SurfaceRow[]) ?? [];
  const matrixRows: MatrixRow[] = (matrixRes.data as MatrixRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const termRows: TermRow[] = (termRes.data as TermRow[]) ?? [];
  const riskRows: RiskRow[] = (riskRes.data as RiskRow[]) ?? [];

  const statusCols: Column<StatusRow>[] = [
    { key: 'discovery_status', header: 'Discovery Status' },
    { key: 'surfaces', header: 'Rows' },
    { key: 'pct', header: 'Share %' },
  ];

  const surfaceCols: Column<SurfaceRow>[] = [
    { key: 'platform_surface', header: 'Surface' },
    { key: 'gap_rows', header: 'Rows' },
    { key: 'healthy', header: 'Healthy' },
    { key: 'gap_emerging', header: 'Gap Emerging' },
    { key: 'high_zero_rate', header: 'High Zero-Rate' },
    { key: 'catalog_gap', header: 'Catalog Gap' },
    { key: 'broken_relevance', header: 'Broken Relevance' },
    { key: 'searches', header: 'Searches' },
    { key: 'avg_zero_pct', header: 'Avg Zero %' },
    { key: 'avg_ctr_pct', header: 'Avg CTR %' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'surface_class', header: 'Surface Class' },
    { key: 'discovery_status', header: 'Discovery Status' },
    { key: 'gap_rows', header: 'Rows' },
    { key: 'searches', header: 'Searches' },
    { key: 'avg_zero_pct', header: 'Avg Zero %' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'period_month', header: 'Month' },
    { key: 'gap_rows', header: 'Rows' },
    { key: 'searches', header: 'Searches' },
    { key: 'zero_results', header: 'Zero Results' },
    { key: 'avg_zero_pct', header: 'Avg Zero %' },
    { key: 'avg_ctr_pct', header: 'Avg CTR %' },
  ];

  const capaCols: Column<CapaRow>[] = [
    { key: 'capa_status', header: 'CAPA Status' },
    { key: 'actions', header: 'Actions' },
    { key: 'avg_zero_searches_impacted', header: 'Avg Zero-Searches Impacted' },
    { key: 'overdue_flag', header: 'Overdue / Escalated' },
  ];

  const causeCols: Column<CauseRow>[] = [
    { key: 'root_cause', header: 'Root Cause' },
    { key: 'occurrences', header: 'Occurrences' },
    { key: 'total_zero_searches_impacted', header: 'Total Zero-Searches Impacted' },
    { key: 'pct', header: 'Share %' },
  ];

  const termCols: Column<TermRow>[] = [
    { key: 'top_missing_term', header: 'Missing Term' },
    { key: 'mentions', header: 'Mentions' },
    { key: 'zero_searches', header: 'Zero Searches' },
    { key: 'avg_zero_pct', header: 'Avg Zero %' },
    { key: 'synonyms_added', header: 'Synonyms Added' },
    { key: 'catalog_gaps', header: 'Catalog Gaps' },
  ];

  const riskCols: Column<RiskRow>[] = [
    { key: 'gap_code', header: 'Code' },
    { key: 'search_category', header: 'Category' },
    { key: 'platform_surface', header: 'Surface' },
    { key: 'period_month', header: 'Month' },
    { key: 'zero_result_pct', header: 'Zero %' },
    { key: 'abandonment_pct', header: 'Abandon %' },
    { key: 'top_missing_term', header: 'Missing Term' },
    { key: 'discovery_status', header: 'Status' },
    { key: 'trend_dir', header: 'Trend' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Search Zero-Results / Discovery-Gap Board
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        In-app search zero-results and discovery-gap analytics — search category (ventilator-repair,
        infusion-pump-service, parts, engineer hire, KB) &times; platform surface &times; period month
        &times; zero-result rate &times; top missing term &times; synonyms added &times; results CTR
        &times; abandonment &times; catalog gaps identified &amp; CAPA closure. Founder-gated view:
        discovery-status rollups, surface scorecards, surface-class &times; status matrix, monthly
        zero-rate trend, root-cause pareto, missing-term digest, and the high-risk relevance queue.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Discovery status distribution</h2>
        <DataTable
          rows={statusRows}
          columns={statusCols}
          emptyMessage="No search-gap rows logged yet."
          rowKey={(r, i) => String(r.discovery_status ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Platform-surface scorecard</h2>
        <DataTable
          rows={surfaceRows}
          columns={surfaceCols}
          emptyMessage="No surface rollups."
          rowKey={(r, i) => String(r.platform_surface ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Surface class &times; discovery status matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No matrix data."
          rowKey={(r, i) => `${r.surface_class}-${r.discovery_status}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Monthly zero-rate trend</h2>
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>7. Missing-term digest</h2>
        <DataTable
          rows={termRows}
          columns={termCols}
          emptyMessage="No missing-term rollups."
          rowKey={(r, i) => String(r.top_missing_term ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk discovery queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk search gaps."
          rowKey={(r, i) => `${r.gap_code}-${r.period_month}-${i}`}
        />
      </section>
    </main>
  );
}
