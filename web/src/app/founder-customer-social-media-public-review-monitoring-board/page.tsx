import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type StatusRow = { monitoring_status: string; records: number; pct: number };
type PlatformRow = {
  platform_name: string;
  records: number;
  total_reviews: number;
  avg_rating: number | null;
  avg_response_rate_pct: number | null;
  total_escalated: number;
  avg_sentiment_score: number | null;
  viral_risk_count: number;
};
type MatrixRow = {
  platform_class: string;
  monitoring_status: string;
  records: number;
  avg_sentiment_score: number | null;
};
type TrendRow = {
  period_month: string;
  records: number;
  total_reviews: number;
  avg_sentiment_score: number | null;
  avg_response_rate_pct: number | null;
  worsening_records: number;
};
type CapaRow = {
  capa_status: string;
  findings: number;
  overdue_flag: number;
};
type CauseRow = {
  root_cause: string;
  occurrences: number;
  pct: number;
};
type GapRow = {
  platform_class: string;
  records: number;
  responded_within_24h_total: number;
  reviews_received_total: number;
  avg_response_rate_pct: number | null;
  escalated_total: number;
};
type RiskRow = {
  platform_name: string;
  region: string;
  platform_class: string;
  period_month: string;
  monitoring_status: string;
  reviews_received: number;
  avg_rating: number | null;
  sentiment_score: number | null;
  response_rate_pct: number | null;
  viral_risk_flagged: boolean;
  notes: string | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    statusRes,
    platformRes,
    matrixRes,
    trendRes,
    capaRes,
    causeRes,
    gapRes,
    riskRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3735_monitoring_status_rollup'),
    supabase.rpc('founder_r3735_platform_name_scorecard'),
    supabase.rpc('founder_r3735_platform_class_status_matrix'),
    supabase.rpc('founder_r3735_monthly_sentiment_trend'),
    supabase.rpc('founder_r3735_capa_status_board'),
    supabase.rpc('founder_r3735_root_cause_pareto'),
    supabase.rpc('founder_r3735_response_gap_digest'),
    supabase.rpc('founder_r3735_high_risk_queue'),
  ]);

  const statusRows: StatusRow[] = (statusRes.data as StatusRow[]) ?? [];
  const platformRows: PlatformRow[] = (platformRes.data as PlatformRow[]) ?? [];
  const matrixRows: MatrixRow[] = (matrixRes.data as MatrixRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const gapRows: GapRow[] = (gapRes.data as GapRow[]) ?? [];
  const riskRows: RiskRow[] = (riskRes.data as RiskRow[]) ?? [];

  const statusCols: Column<StatusRow>[] = [
    { key: 'monitoring_status', header: 'Monitoring Status' },
    { key: 'records', header: 'Records' },
    { key: 'pct', header: 'Share %' },
  ];

  const platformCols: Column<PlatformRow>[] = [
    { key: 'platform_name', header: 'Platform' },
    { key: 'records', header: 'Records' },
    { key: 'total_reviews', header: 'Total Reviews' },
    { key: 'avg_rating', header: 'Avg Rating' },
    { key: 'avg_response_rate_pct', header: 'Avg Response Rate %' },
    { key: 'total_escalated', header: 'Total Escalated' },
    { key: 'avg_sentiment_score', header: 'Avg Sentiment' },
    { key: 'viral_risk_count', header: 'Viral Risk Count' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'platform_class', header: 'Platform Class' },
    { key: 'monitoring_status', header: 'Monitoring Status' },
    { key: 'records', header: 'Records' },
    { key: 'avg_sentiment_score', header: 'Avg Sentiment' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'period_month', header: 'Month' },
    { key: 'records', header: 'Records' },
    { key: 'total_reviews', header: 'Total Reviews' },
    { key: 'avg_sentiment_score', header: 'Avg Sentiment' },
    { key: 'avg_response_rate_pct', header: 'Avg Response Rate %' },
    { key: 'worsening_records', header: 'Worsening' },
  ];

  const capaCols: Column<CapaRow>[] = [
    { key: 'capa_status', header: 'CAPA Status' },
    { key: 'findings', header: 'Findings' },
    { key: 'overdue_flag', header: 'Overdue' },
  ];

  const causeCols: Column<CauseRow>[] = [
    { key: 'root_cause', header: 'Root Cause' },
    { key: 'occurrences', header: 'Occurrences' },
    { key: 'pct', header: 'Share %' },
  ];

  const gapCols: Column<GapRow>[] = [
    { key: 'platform_class', header: 'Platform Class' },
    { key: 'records', header: 'Records' },
    { key: 'responded_within_24h_total', header: 'Responded within 24h' },
    { key: 'reviews_received_total', header: 'Reviews Received' },
    { key: 'avg_response_rate_pct', header: 'Avg Response Rate %' },
    { key: 'escalated_total', header: 'Escalated to Support' },
  ];

  const riskCols: Column<RiskRow>[] = [
    { key: 'platform_name', header: 'Platform' },
    { key: 'region', header: 'Region' },
    { key: 'platform_class', header: 'Platform Class' },
    { key: 'period_month', header: 'Month' },
    { key: 'monitoring_status', header: 'Monitoring Status' },
    { key: 'reviews_received', header: 'Reviews Received' },
    { key: 'avg_rating', header: 'Avg Rating' },
    { key: 'sentiment_score', header: 'Sentiment Score' },
    { key: 'response_rate_pct', header: 'Response Rate %' },
    { key: 'viral_risk_flagged', header: 'Viral Risk' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Customer Social-Media / Public-Review Monitoring Board
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Public-review platform monitoring &mdash; Google reviews, social-media mentions, app-store
        reviews, healthcare forums &amp; news-media coverage &times; region &times; period month
        &times; sentiment score &times; response time &amp; response-rate SLA &times; negative-review
        escalation to support &times; viral-risk flags &amp; CAPA closure. This board tracks
        reviews received on public platforms and monitored externally &mdash; it is distinct from any
        NPS/CSAT survey board, which captures direct-surveyed customer feedback, not public-review-
        platform monitoring. Founder-gated view: monitoring-status distribution, platform
        scorecards, response-gap digest, root-cause pareto, and a high-risk queue of crisis-risk
        or negative-trend platforms.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Monitoring-status distribution</h2>
        <DataTable
          rows={statusRows}
          columns={statusCols}
          emptyMessage="No monitoring rows logged yet."
          rowKey={(r, i) => String(r.monitoring_status ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Platform scorecard</h2>
        <DataTable
          rows={platformRows}
          columns={platformCols}
          emptyMessage="No platform rollups."
          rowKey={(r, i) => String(r.platform_name ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Platform class &times; monitoring status matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No records by platform class."
          rowKey={(r, i) => `${r.platform_class}-${r.monitoring_status}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Monthly sentiment trend</h2>
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>6. Root cause pareto</h2>
        <DataTable
          rows={causeRows}
          columns={causeCols}
          emptyMessage="No root-cause data."
          rowKey={(r, i) => String(r.root_cause ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>7. Response-gap digest</h2>
        <DataTable
          rows={gapRows}
          columns={gapCols}
          emptyMessage="No response gaps identified."
          rowKey={(r, i) => String(r.platform_class ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk platforms."
          rowKey={(r, i) => `${r.platform_name}-${r.region}-${i}`}
        />
      </section>
    </main>
  );
}
