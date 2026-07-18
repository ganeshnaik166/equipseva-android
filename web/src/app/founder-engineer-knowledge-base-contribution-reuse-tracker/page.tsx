import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type VerdictRow = { kb_verdict: string; articles: number; pct: number };
type EngRow = {
  engineer_name: string;
  articles: number;
  total_views_30d: number;
  total_reuse_jobs: number;
  avg_peer_rating: number;
  peer_verified: number;
  gap_topics_covered: number;
  flagged_articles: number;
};
type MatrixRow = {
  article_type: string;
  equipment_category: string;
  articles: number;
  total_reuse_jobs: number;
  avg_peer_rating: number;
};
type TrendRow = {
  publish_month: string;
  articles: number;
  avg_views_30d: number;
  avg_peer_rating: number;
  gap_topics: number;
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
type RegRow = {
  regulatory_impact: string;
  findings: number;
  open_findings: number;
  total_cost_rupees: number;
};
type QueueRow = {
  hospital_name: string;
  engineer_name: string;
  article_code: string;
  article_title: string;
  article_type: string;
  kb_verdict: string;
  freshness_days: number;
  peer_rating: number | null;
  gap_topic_flagged: boolean;
  notes: string | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    verdictRes,
    engRes,
    matrixRes,
    trendRes,
    capaRes,
    causeRes,
    regRes,
    queueRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3236_verdict_rollup'),
    supabase.rpc('founder_r3236_engineer_scorecard'),
    supabase.rpc('founder_r3236_type_category_matrix'),
    supabase.rpc('founder_r3236_monthly_publish_trend'),
    supabase.rpc('founder_r3236_capa_status_board'),
    supabase.rpc('founder_r3236_root_cause_pareto'),
    supabase.rpc('founder_r3236_regulatory_impact_digest'),
    supabase.rpc('founder_r3236_stale_gap_priority_queue'),
  ]);

  const verdictRows: VerdictRow[] = (verdictRes.data as VerdictRow[]) ?? [];
  const engRows: EngRow[] = (engRes.data as EngRow[]) ?? [];
  const matrixRows: MatrixRow[] = (matrixRes.data as MatrixRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const regRows: RegRow[] = (regRes.data as RegRow[]) ?? [];
  const queueRows: QueueRow[] = (queueRes.data as QueueRow[]) ?? [];

  const verdictCols: Column<VerdictRow>[] = [
    { key: 'kb_verdict', header: 'Verdict' },
    { key: 'articles', header: 'Articles' },
    { key: 'pct', header: 'Share %' },
  ];

  const engCols: Column<EngRow>[] = [
    { key: 'engineer_name', header: 'Engineer' },
    { key: 'articles', header: 'Articles' },
    { key: 'total_views_30d', header: 'Views 30d' },
    { key: 'total_reuse_jobs', header: 'Reused in Jobs' },
    { key: 'avg_peer_rating', header: 'Avg Rating' },
    { key: 'peer_verified', header: 'Peer Verified' },
    { key: 'gap_topics_covered', header: 'Gap Topics' },
    { key: 'flagged_articles', header: 'Flagged' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'article_type', header: 'Article Type' },
    { key: 'equipment_category', header: 'Equipment Category' },
    { key: 'articles', header: 'Articles' },
    { key: 'total_reuse_jobs', header: 'Reused in Jobs' },
    { key: 'avg_peer_rating', header: 'Avg Rating' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'publish_month', header: 'Month' },
    { key: 'articles', header: 'Published' },
    { key: 'avg_views_30d', header: 'Avg Views 30d' },
    { key: 'avg_peer_rating', header: 'Avg Rating' },
    { key: 'gap_topics', header: 'Gap Topics' },
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

  const regCols: Column<RegRow>[] = [
    { key: 'regulatory_impact', header: 'Regulatory Impact' },
    { key: 'findings', header: 'Findings' },
    { key: 'open_findings', header: 'Open' },
    { key: 'total_cost_rupees', header: 'Total Cost (INR)' },
  ];

  const queueCols: Column<QueueRow>[] = [
    { key: 'hospital_name', header: 'Hospital' },
    { key: 'engineer_name', header: 'Engineer' },
    { key: 'article_code', header: 'Code' },
    { key: 'article_title', header: 'Title' },
    { key: 'article_type', header: 'Type' },
    { key: 'kb_verdict', header: 'Verdict' },
    { key: 'freshness_days', header: 'Freshness (days)' },
    { key: 'peer_rating', header: 'Rating' },
    { key: 'gap_topic_flagged', header: 'Gap Topic' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Engineer Knowledge-Base Contribution &amp; Fix-Documentation Reuse Tracker
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Engineer KB log — article type &times; equipment category &times; views 30d &times;
        reuse-in-jobs &times; peer rating &times; freshness &times; gap-topic flag &amp; CAPA closure.
        Founder-gated view: verdict rollups, engineer scorecards, root-cause pareto, and the
        stale/gap priority queue (freshness &gt; 180 days or rating &lt; 3.0).
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. KB verdict distribution</h2>
        <DataTable
          rows={verdictRows}
          columns={verdictCols}
          emptyMessage="No KB articles logged yet."
          rowKey={(r, i) => String(r.kb_verdict ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Engineer contribution scorecard</h2>
        <DataTable
          rows={engRows}
          columns={engCols}
          emptyMessage="No engineer rollups."
          rowKey={(r, i) => String(r.engineer_name ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Article type &times; equipment category matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No articles by category."
          rowKey={(r, i) => `${r.article_type}-${r.equipment_category}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Monthly publication trend</h2>
        <DataTable
          rows={trendRows}
          columns={trendCols}
          emptyMessage="No trend data."
          rowKey={(r, i) => String(r.publish_month ?? i)}
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>7. Regulatory impact digest</h2>
        <DataTable
          rows={regRows}
          columns={regCols}
          emptyMessage="No regulatory-impact rollups."
          rowKey={(r, i) => String(r.regulatory_impact ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. Stale / gap priority queue</h2>
        <DataTable
          rows={queueRows}
          columns={queueCols}
          emptyMessage="No stale or gap-flagged articles."
          rowKey={(r, i) => `${r.article_code}-${i}`}
        />
      </section>
    </main>
  );
}
