import { requireFounder } from '@/lib/auth/requireFounder';
import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column  } from "@/components/DataTable";

export const dynamic = 'force-dynamic';

type Kpi = { label: string; value: string };

function fmtNum(n: any, digits = 1): string {
  if (n === null || n === undefined) return '—';
  const v = Number(n);
  if (!Number.isFinite(v)) return '—';
  return v.toFixed(digits);
}

function fmtInt(n: any): string {
  if (n === null || n === undefined) return '—';
  const v = Number(n);
  if (!Number.isFinite(v)) return '—';
  return Math.round(v).toLocaleString('en-IN');
}

function shortId(id: any): string {
  if (!id) return '—';
  const s = String(id);
  return s.length > 8 ? s.slice(0, 8) : s;
}

export default async function FounderEngineerKpiScoreboardV2Page() {
  await requireFounder();
  const sb = await getSupabaseServerClient();

  let summary: any = null;
  let leaderboard: any[] = [];
  let bottomDecile: any[] = [];
  let tierDist: any[] = [];
  let trend: any[] = [];
  let openReviews: any[] = [];
  let breakdown: any[] = [];

  try {
    const r = await sb.rpc('founder_engineer_kpi_v2_summary');
    summary = (r.data && r.data[0]) || null;
  } catch (_e) {
    summary = null;
  }
  try {
    const r = await sb.rpc('founder_engineer_kpi_v2_leaderboard', { p_limit: 25 });
    leaderboard = Array.isArray(r.data) ? r.data : [];
  } catch (_e) {
    leaderboard = [];
  }
  try {
    const r = await sb.rpc('founder_engineer_kpi_v2_bottom_decile');
    bottomDecile = Array.isArray(r.data) ? r.data : [];
  } catch (_e) {
    bottomDecile = [];
  }
  try {
    const r = await sb.rpc('founder_engineer_kpi_v2_tier_distribution');
    tierDist = Array.isArray(r.data) ? r.data : [];
  } catch (_e) {
    tierDist = [];
  }
  try {
    const r = await sb.rpc('founder_engineer_kpi_v2_trend');
    trend = Array.isArray(r.data) ? r.data : [];
  } catch (_e) {
    trend = [];
  }
  try {
    const r = await sb.rpc('founder_engineer_kpi_v2_open_reviews');
    openReviews = Array.isArray(r.data) ? r.data : [];
  } catch (_e) {
    openReviews = [];
  }
  try {
    const r = await sb.rpc('founder_engineer_kpi_v2_component_breakdown');
    breakdown = Array.isArray(r.data) ? r.data : [];
  } catch (_e) {
    breakdown = [];
  }

  const kpis: Kpi[] = [
    { label: 'Snapshot date', value: summary?.snapshot_date ?? '—' },
    { label: 'Cohort size', value: fmtInt(summary?.cohort_size) },
    { label: 'Avg composite', value: fmtNum(summary?.avg_composite, 2) },
    { label: 'Median composite', value: fmtNum(summary?.median_composite, 2) },
    { label: 'Min composite', value: fmtNum(summary?.min_composite, 2) },
    { label: 'Max composite', value: fmtNum(summary?.max_composite, 2) },
    { label: 'Bottom decile threshold', value: fmtNum(summary?.bottom_decile_threshold, 2) },
    { label: 'Top decile threshold', value: fmtNum(summary?.top_decile_threshold, 2) },
    { label: 'Reviews open', value: fmtInt(summary?.reviews_open) },
    { label: 'Reviews total', value: fmtInt(summary?.reviews_total) },
    { label: 'Leaderboard size', value: fmtInt(leaderboard.length) },
    { label: 'Bottom decile count', value: fmtInt(bottomDecile.length) },
    { label: 'Trend points', value: fmtInt(trend.length) },
    { label: 'Tier buckets', value: fmtInt(tierDist.length) },
    { label: 'Components tracked', value: fmtInt(breakdown.length) },
    { label: 'Round', value: 'r1529' },
  ];

  const leaderCols: Column<any>[] = [
    { key: 'rank_overall', header: 'Rank', render: (r: any) => fmtInt(r.rank_overall) },
    { key: 'engineer_id', header: 'Engineer', render: (r: any) => shortId(r.engineer_id) },
    { key: 'composite_score', header: 'Composite', render: (r: any) => fmtNum(r.composite_score, 2) },
    { key: 'percentile', header: 'Percentile', render: (r: any) => fmtNum(r.percentile, 1) },
    { key: 'nps_score', header: 'NPS', render: (r: any) => fmtNum(r.nps_score, 1) },
    { key: 'acceptance_score', header: 'Accept', render: (r: any) => fmtNum(r.acceptance_score, 1) },
    { key: 'completion_score', header: 'Complete', render: (r: any) => fmtNum(r.completion_score, 1) },
    { key: 'tier_score', header: 'Tier', render: (r: any) => fmtNum(r.tier_score, 1) },
    { key: 'retention_score', header: 'Retain', render: (r: any) => fmtNum(r.retention_score, 1) },
  ];

  const bottomCols: Column<any>[] = [
    { key: 'rank_overall', header: 'Rank', render: (r: any) => fmtInt(r.rank_overall) },
    { key: 'engineer_id', header: 'Engineer', render: (r: any) => shortId(r.engineer_id) },
    { key: 'composite_score', header: 'Composite', render: (r: any) => fmtNum(r.composite_score, 2) },
    { key: 'percentile', header: 'Percentile', render: (r: any) => fmtNum(r.percentile, 1) },
    { key: 'raw_jobs_total', header: 'Jobs', render: (r: any) => fmtInt(r.raw_jobs_total) },
    { key: 'raw_avg_rating', header: 'Avg rating', render: (r: any) => fmtNum(r.raw_avg_rating, 2) },
  ];

  const tierCols: Column<any>[] = [
    { key: 'tier', header: 'Tier', render: (r: any) => String(r.tier ?? '—') },
    { key: 'engineer_count', header: 'Engineers', render: (r: any) => fmtInt(r.engineer_count) },
    { key: 'avg_composite', header: 'Avg composite', render: (r: any) => fmtNum(r.avg_composite, 2) },
  ];

  const trendCols: Column<any>[] = [
    { key: 'snapshot_date', header: 'Date', render: (r: any) => String(r.snapshot_date ?? '—') },
    { key: 'cohort_size', header: 'Cohort', render: (r: any) => fmtInt(r.cohort_size) },
    { key: 'avg_composite', header: 'Avg', render: (r: any) => fmtNum(r.avg_composite, 2) },
    { key: 'median_composite', header: 'Median', render: (r: any) => fmtNum(r.median_composite, 2) },
  ];

  const reviewCols: Column<any>[] = [
    { key: 'review_date', header: 'Date', render: (r: any) => String(r.review_date ?? '—') },
    { key: 'engineer_id', header: 'Engineer', render: (r: any) => shortId(r.engineer_id) },
    { key: 'review_status', header: 'Status', render: (r: any) => String(r.review_status ?? '—') },
    { key: 'composite_at_review', header: 'Composite', render: (r: any) => fmtNum(r.composite_at_review, 2) },
    { key: 'percentile_at_review', header: 'Percentile', render: (r: any) => fmtNum(r.percentile_at_review, 1) },
    { key: 'action_taken', header: 'Action', render: (r: any) => String(r.action_taken ?? '—') },
  ];

  const breakdownCols: Column<any>[] = [
    { key: 'component', header: 'Component', render: (r: any) => String(r.component ?? '—') },
    { key: 'avg_score', header: 'Avg', render: (r: any) => fmtNum(r.avg_score, 2) },
    { key: 'min_score', header: 'Min', render: (r: any) => fmtNum(r.min_score, 2) },
    { key: 'max_score', header: 'Max', render: (r: any) => fmtNum(r.max_score, 2) },
  ];

  return (
    <div style={{ padding: 24, fontFamily: 'system-ui, sans-serif' }}>
      <h1 style={{ fontSize: 24, fontWeight: 700, marginBottom: 4 }}>
        Engineer KPI Scoreboard v2
      </h1>
      <p style={{ color: '#666', marginBottom: 24 }}>
        Composite engineer KPI: NPS + acceptance + completion + tier + retention. Rank, percentile, and founder review for the bottom 10%. Round r1529.
      </p>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Headline KPIs</h2>
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fill, minmax(180px, 1fr))', gap: 12 }}>
          {kpis.map((k) => (
            <div key={k.label} style={{ border: '1px solid #e5e7eb', borderRadius: 8, padding: 12, background: '#fff' }}>
              <div style={{ fontSize: 12, color: '#6b7280' }}>{k.label}</div>
              <div style={{ fontSize: 18, fontWeight: 600, marginTop: 4 }}>{k.value ?? '—'}</div>
            </div>
          ))}
        </div>
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Leaderboard (top 25)</h2>
        <DataTable columns={leaderCols} rows={leaderboard} rowKey={(r: any) => r.id} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Bottom decile (review candidates)</h2>
        <DataTable columns={bottomCols} rows={bottomDecile} rowKey={(r: any) => r.id} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Tier distribution</h2>
        <DataTable columns={tierCols} rows={tierDist} rowKey={(r: any) => String(r.tier ?? 'none')} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Snapshot trend (last 30)</h2>
        <DataTable columns={trendCols} rows={trend} rowKey={(r: any) => String(r.snapshot_date ?? '')} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Component breakdown</h2>
        <DataTable columns={breakdownCols} rows={breakdown} rowKey={(r: any) => String(r.component ?? '')} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Open founder reviews</h2>
        <DataTable columns={reviewCols} rows={openReviews} rowKey={(r: any) => r.id} />
      </section>
    </div>
  );
}
