import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type StatusRow = { reputation_status: string; cycles: number; pct: number };
type StoreRow = {
  store_name: string;
  cycles: number;
  avg_rating: number;
  total_ratings: number;
  reviews_received: number;
  reviews_responded: number;
  avg_response_pct: number;
  avg_response_hours: number;
  one_star_total: number;
  at_risk_cycles: number;
};
type MatrixRow = {
  review_theme: string;
  reputation_status: string;
  cycles: number;
  avg_rating: number;
  one_star_total: number;
};
type TrendRow = {
  period_month: string;
  cycles: number;
  avg_rating: number;
  reviews_received: number;
  reviews_responded: number;
  avg_response_pct: number;
  one_star_total: number;
};
type CapaRow = {
  capa_status: string;
  actions: number;
  avg_rating_points_at_risk: number;
  overdue_flag: number;
};
type CauseRow = {
  root_cause: string;
  occurrences: number;
  total_rating_points_at_risk: number;
  pct: number;
};
type OneStarRow = {
  listing_name: string;
  store_name: string;
  cycles: number;
  one_star_total: number;
  bug_complaints_total: number;
  feature_requests_total: number;
  avg_rating: number;
  worst_month_rating: number;
};
type RiskRow = {
  listing_name: string;
  store_name: string;
  period_month: string;
  avg_rating: number;
  one_star_reviews: number;
  response_pct: number;
  reputation_status: string;
  trend_dir: string;
  notes: string | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    statusRes,
    storeRes,
    matrixRes,
    trendRes,
    capaRes,
    causeRes,
    oneStarRes,
    riskRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3695_reputation_status_rollup'),
    supabase.rpc('founder_r3695_store_scorecard'),
    supabase.rpc('founder_r3695_theme_status_matrix'),
    supabase.rpc('founder_r3695_monthly_rating_trend'),
    supabase.rpc('founder_r3695_capa_status_board'),
    supabase.rpc('founder_r3695_root_cause_pareto'),
    supabase.rpc('founder_r3695_one_star_digest'),
    supabase.rpc('founder_r3695_high_risk_queue'),
  ]);

  const statusRows: StatusRow[] = (statusRes.data as StatusRow[]) ?? [];
  const storeRows: StoreRow[] = (storeRes.data as StoreRow[]) ?? [];
  const matrixRows: MatrixRow[] = (matrixRes.data as MatrixRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const oneStarRows: OneStarRow[] = (oneStarRes.data as OneStarRow[]) ?? [];
  const riskRows: RiskRow[] = (riskRes.data as RiskRow[]) ?? [];

  const statusCols: Column<StatusRow>[] = [
    { key: 'reputation_status', header: 'Reputation Status' },
    { key: 'cycles', header: 'Cycles' },
    { key: 'pct', header: 'Share %' },
  ];

  const storeCols: Column<StoreRow>[] = [
    { key: 'store_name', header: 'Store' },
    { key: 'cycles', header: 'Cycles' },
    { key: 'avg_rating', header: 'Avg Rating' },
    { key: 'total_ratings', header: 'Ratings' },
    { key: 'reviews_received', header: 'Reviews In' },
    { key: 'reviews_responded', header: 'Responded' },
    { key: 'avg_response_pct', header: 'Response %' },
    { key: 'avg_response_hours', header: 'Avg Response Hrs' },
    { key: 'one_star_total', header: 'One-Star' },
    { key: 'at_risk_cycles', header: 'At-Risk Cycles' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'review_theme', header: 'Review Theme' },
    { key: 'reputation_status', header: 'Reputation Status' },
    { key: 'cycles', header: 'Cycles' },
    { key: 'avg_rating', header: 'Avg Rating' },
    { key: 'one_star_total', header: 'One-Star' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'period_month', header: 'Month' },
    { key: 'cycles', header: 'Cycles' },
    { key: 'avg_rating', header: 'Avg Rating' },
    { key: 'reviews_received', header: 'Reviews In' },
    { key: 'reviews_responded', header: 'Responded' },
    { key: 'avg_response_pct', header: 'Response %' },
    { key: 'one_star_total', header: 'One-Star' },
  ];

  const capaCols: Column<CapaRow>[] = [
    { key: 'capa_status', header: 'CAPA Status' },
    { key: 'actions', header: 'Actions' },
    { key: 'avg_rating_points_at_risk', header: 'Avg Rating Pts At Risk' },
    { key: 'overdue_flag', header: 'Overdue / Escalated' },
  ];

  const causeCols: Column<CauseRow>[] = [
    { key: 'root_cause', header: 'Root Cause' },
    { key: 'occurrences', header: 'Occurrences' },
    { key: 'total_rating_points_at_risk', header: 'Total Rating Pts At Risk' },
    { key: 'pct', header: 'Share %' },
  ];

  const oneStarCols: Column<OneStarRow>[] = [
    { key: 'listing_name', header: 'Listing' },
    { key: 'store_name', header: 'Store' },
    { key: 'cycles', header: 'Cycles' },
    { key: 'one_star_total', header: 'One-Star' },
    { key: 'bug_complaints_total', header: 'Bug Complaints' },
    { key: 'feature_requests_total', header: 'Feature Requests' },
    { key: 'avg_rating', header: 'Avg Rating' },
    { key: 'worst_month_rating', header: 'Worst Month' },
  ];

  const riskCols: Column<RiskRow>[] = [
    { key: 'listing_name', header: 'Listing' },
    { key: 'store_name', header: 'Store' },
    { key: 'period_month', header: 'Month' },
    { key: 'avg_rating', header: 'Avg Rating' },
    { key: 'one_star_reviews', header: 'One-Star' },
    { key: 'response_pct', header: 'Response %' },
    { key: 'reputation_status', header: 'Status' },
    { key: 'trend_dir', header: 'Trend' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        App-Store Rating / Review-Response Board
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Play-Store &amp; App-Store reputation ops — listing &times; store &times; monthly avg
        rating &times; ratings volume &times; review-response discipline (response % &amp; avg
        response hours) &times; one-star reviews &times; review theme &times; reputation status
        &times; trend &amp; CAPA closure. Founder-gated view: reputation rollups, store scorecards,
        theme &times; status matrix, monthly rating trend, root-cause pareto, one-star digest, and
        the high-risk (critical / at-risk) queue.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Reputation status distribution</h2>
        <DataTable
          rows={statusRows}
          columns={statusCols}
          emptyMessage="No review cycles logged yet."
          rowKey={(r, i) => String(r.reputation_status ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Store scorecard</h2>
        <DataTable
          rows={storeRows}
          columns={storeCols}
          emptyMessage="No store rollups."
          rowKey={(r, i) => String(r.store_name ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Review theme &times; reputation status matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No cycles by review theme."
          rowKey={(r, i) => `${r.review_theme}-${r.reputation_status}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Monthly rating trend</h2>
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>7. One-star digest</h2>
        <DataTable
          rows={oneStarRows}
          columns={oneStarCols}
          emptyMessage="No one-star rollups."
          rowKey={(r, i) => `${r.listing_name}-${r.store_name}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk cycles."
          rowKey={(r, i) => `${r.listing_name}-${r.period_month}-${i}`}
        />
      </section>
    </main>
  );
}
