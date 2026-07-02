import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type OverviewRow = {
  outlet_tier: string;
  total_hits: number;
  total_reach: number;
  avg_sentiment: number;
  negative_share: number;
};

type TopicRow = {
  topic_cluster: string;
  hits: number;
  reach: number;
  avg_sentiment: number;
  off_message_count: number;
};

type TrendRow = {
  hit_date: string;
  hits: number;
  weighted_sentiment: number;
  total_reach: number;
};

type SpokesRow = {
  spokesperson: string;
  hits: number;
  avg_sentiment: number;
  reach: number;
  on_message_share: number;
};

type ResponseRow = {
  response_status: string;
  hits: number;
  reach: number;
  avg_sentiment: number;
};

type TopHitRow = {
  outlet_name: string;
  outlet_tier: string;
  headline: string;
  reach_estimate: number;
  sentiment: string;
  sentiment_score: number;
  response_status: string;
  published_at: string;
};

type SeverityRow = {
  crisis_severity: string;
  active_items: number;
  closed_items: number;
  avg_hours_to_first_response: number | null;
  recovered_reach: number;
};

type PlaybookRow = {
  response_playbook: string;
  total: number;
  positive_outcomes: number;
  negative_outcomes: number;
  avg_hours_to_first_response: number | null;
};

type OpenRow = {
  headline: string;
  outlet_name: string;
  crisis_severity: string;
  response_playbook: string;
  assigned_owner: string;
  approval_status: string;
  outcome_status: string;
  due_at: string;
};

function fmtInt(n: number | null | undefined): string {
  if (n === null || n === undefined) return '-';
  return new Intl.NumberFormat('en-IN').format(n);
}

function fmtSent(n: number | null | undefined): string {
  if (n === null || n === undefined) return '-';
  return n.toFixed(2);
}

function fmtDate(s: string): string {
  return new Date(s).toLocaleString('en-IN', { dateStyle: 'medium', timeStyle: 'short' });
}

export default async function FounderPressMediaSentimentCrisisTrackerPage() {
  const supabase = await getSupabaseServerClient();

  const [
    overview,
    topics,
    trend,
    spokes,
    responses,
    topHits,
    severity,
    playbook,
    openQueue,
  ] = await Promise.all([
    supabase.rpc('rpc_press_overview_r3109'),
    supabase.rpc('rpc_press_topic_rollup_r3109'),
    supabase.rpc('rpc_press_sentiment_trend_r3109'),
    supabase.rpc('rpc_press_spokesperson_perf_r3109'),
    supabase.rpc('rpc_press_response_status_r3109'),
    supabase.rpc('rpc_press_top_hits_r3109'),
    supabase.rpc('rpc_crisis_severity_rollup_r3109'),
    supabase.rpc('rpc_crisis_playbook_outcomes_r3109'),
    supabase.rpc('rpc_crisis_open_queue_r3109'),
  ]);

  const overviewRows = (overview.data ?? []) as OverviewRow[];
  const topicRows = (topics.data ?? []) as TopicRow[];
  const trendRows = (trend.data ?? []) as TrendRow[];
  const spokesRows = (spokes.data ?? []) as SpokesRow[];
  const responseRows = (responses.data ?? []) as ResponseRow[];
  const topHitRows = (topHits.data ?? []) as TopHitRow[];
  const severityRows = (severity.data ?? []) as SeverityRow[];
  const playbookRows = (playbook.data ?? []) as PlaybookRow[];
  const openRows = (openQueue.data ?? []) as OpenRow[];

  const overviewCols: Column<OverviewRow>[] = [
    { key: 'outlet_tier', header: 'Outlet tier' },
    { key: 'total_hits', header: 'Hits', render: (r) => fmtInt(r.total_hits) },
    { key: 'total_reach', header: 'Reach', render: (r) => fmtInt(r.total_reach) },
    { key: 'avg_sentiment', header: 'Avg sentiment', render: (r) => fmtSent(r.avg_sentiment) },
    { key: 'negative_share', header: 'Negative %', render: (r) => `${r.negative_share}%` },
  ];

  const topicCols: Column<TopicRow>[] = [
    { key: 'topic_cluster', header: 'Topic cluster' },
    { key: 'hits', header: 'Hits', render: (r) => fmtInt(r.hits) },
    { key: 'reach', header: 'Reach', render: (r) => fmtInt(r.reach) },
    { key: 'avg_sentiment', header: 'Avg sentiment', render: (r) => fmtSent(r.avg_sentiment) },
    { key: 'off_message_count', header: 'Off-message hits', render: (r) => fmtInt(r.off_message_count) },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'hit_date', header: 'Date (IST)', render: (r) => r.hit_date },
    { key: 'hits', header: 'Hits', render: (r) => fmtInt(r.hits) },
    { key: 'weighted_sentiment', header: 'Reach-weighted sentiment', render: (r) => fmtSent(r.weighted_sentiment) },
    { key: 'total_reach', header: 'Reach', render: (r) => fmtInt(r.total_reach) },
  ];

  const spokesCols: Column<SpokesRow>[] = [
    { key: 'spokesperson', header: 'Spokesperson' },
    { key: 'hits', header: 'Hits', render: (r) => fmtInt(r.hits) },
    { key: 'avg_sentiment', header: 'Avg sentiment', render: (r) => fmtSent(r.avg_sentiment) },
    { key: 'reach', header: 'Reach', render: (r) => fmtInt(r.reach) },
    { key: 'on_message_share', header: 'On-message %', render: (r) => `${r.on_message_share}%` },
  ];

  const responseCols: Column<ResponseRow>[] = [
    { key: 'response_status', header: 'Response status' },
    { key: 'hits', header: 'Hits', render: (r) => fmtInt(r.hits) },
    { key: 'reach', header: 'Reach', render: (r) => fmtInt(r.reach) },
    { key: 'avg_sentiment', header: 'Avg sentiment', render: (r) => fmtSent(r.avg_sentiment) },
  ];

  const topHitCols: Column<TopHitRow>[] = [
    { key: 'outlet_name', header: 'Outlet' },
    { key: 'outlet_tier', header: 'Tier' },
    { key: 'headline', header: 'Headline' },
    { key: 'reach_estimate', header: 'Reach', render: (r) => fmtInt(r.reach_estimate) },
    { key: 'sentiment', header: 'Sentiment' },
    { key: 'sentiment_score', header: 'Score', render: (r) => fmtSent(r.sentiment_score) },
    { key: 'response_status', header: 'Response status' },
    { key: 'published_at', header: 'Published', render: (r) => fmtDate(r.published_at) },
  ];

  const severityCols: Column<SeverityRow>[] = [
    { key: 'crisis_severity', header: 'Severity' },
    { key: 'active_items', header: 'Active', render: (r) => fmtInt(r.active_items) },
    { key: 'closed_items', header: 'Closed', render: (r) => fmtInt(r.closed_items) },
    { key: 'avg_hours_to_first_response', header: 'Avg first-response hrs', render: (r) => fmtSent(r.avg_hours_to_first_response ?? 0) },
    { key: 'recovered_reach', header: 'Expected reach recovery', render: (r) => fmtInt(r.recovered_reach) },
  ];

  const playbookCols: Column<PlaybookRow>[] = [
    { key: 'response_playbook', header: 'Playbook' },
    { key: 'total', header: 'Total', render: (r) => fmtInt(r.total) },
    { key: 'positive_outcomes', header: 'Positive outcomes', render: (r) => fmtInt(r.positive_outcomes) },
    { key: 'negative_outcomes', header: 'Negative outcomes', render: (r) => fmtInt(r.negative_outcomes) },
    { key: 'avg_hours_to_first_response', header: 'Avg first-response hrs', render: (r) => fmtSent(r.avg_hours_to_first_response ?? 0) },
  ];

  const openCols: Column<OpenRow>[] = [
    { key: 'headline', header: 'Headline' },
    { key: 'outlet_name', header: 'Outlet' },
    { key: 'crisis_severity', header: 'Severity' },
    { key: 'response_playbook', header: 'Playbook' },
    { key: 'assigned_owner', header: 'Owner' },
    { key: 'approval_status', header: 'Approval' },
    { key: 'outcome_status', header: 'Outcome' },
    { key: 'due_at', header: 'Due', render: (r) => fmtDate(r.due_at) },
  ];

  return (
    <div style={{ padding: '24px', maxWidth: '1400px', margin: '0 auto' }}>
      <h1 style={{ fontSize: '24px', fontWeight: 700, marginBottom: '4px' }}>
        Press & Media Coverage — Sentiment + Crisis Response (r3109)
      </h1>
      <p style={{ color: '#64748b', marginBottom: '24px', fontSize: '14px' }}>
        Outlet × headline × reach × tone × response status × narrative correction queue.
        All RPCs founder-gated.
      </p>

      <section style={{ marginBottom: '28px' }}>
        <h2 style={{ fontSize: '16px', fontWeight: 600, marginBottom: '8px' }}>1. Coverage overview by outlet tier</h2>
        <DataTable
          rows={overviewRows}
          columns={overviewCols}
          emptyMessage="No press hits logged yet."
          rowKey={(r, i) => String(r.outlet_tier ?? i)}
        />
      </section>

      <section style={{ marginBottom: '28px' }}>
        <h2 style={{ fontSize: '16px', fontWeight: 600, marginBottom: '8px' }}>2. Topic cluster rollup</h2>
        <DataTable
          rows={topicRows}
          columns={topicCols}
          emptyMessage="No topics tracked."
          rowKey={(r, i) => String(r.topic_cluster ?? i)}
        />
      </section>

      <section style={{ marginBottom: '28px' }}>
        <h2 style={{ fontSize: '16px', fontWeight: 600, marginBottom: '8px' }}>3. Sentiment trend (reach-weighted, by IST date)</h2>
        <DataTable
          rows={trendRows}
          columns={trendCols}
          emptyMessage="No trend data."
          rowKey={(r, i) => String(r.hit_date ?? i)}
        />
      </section>

      <section style={{ marginBottom: '28px' }}>
        <h2 style={{ fontSize: '16px', fontWeight: 600, marginBottom: '8px' }}>4. Spokesperson performance</h2>
        <DataTable
          rows={spokesRows}
          columns={spokesCols}
          emptyMessage="No spokesperson data."
          rowKey={(r, i) => String(r.spokesperson ?? i)}
        />
      </section>

      <section style={{ marginBottom: '28px' }}>
        <h2 style={{ fontSize: '16px', fontWeight: 600, marginBottom: '8px' }}>5. Response status distribution</h2>
        <DataTable
          rows={responseRows}
          columns={responseCols}
          emptyMessage="No response data."
          rowKey={(r, i) => String(r.response_status ?? i)}
        />
      </section>

      <section style={{ marginBottom: '28px' }}>
        <h2 style={{ fontSize: '16px', fontWeight: 600, marginBottom: '8px' }}>6. Top-25 press hits by reach</h2>
        <DataTable
          rows={topHitRows}
          columns={topHitCols}
          emptyMessage="No top hits."
          rowKey={(r, i) => String(`${r.outlet_name}-${r.published_at}` ?? i)}
        />
      </section>

      <section style={{ marginBottom: '28px' }}>
        <h2 style={{ fontSize: '16px', fontWeight: 600, marginBottom: '8px' }}>7. Crisis queue — severity rollup</h2>
        <DataTable
          rows={severityRows}
          columns={severityCols}
          emptyMessage="No crisis items."
          rowKey={(r, i) => String(r.crisis_severity ?? i)}
        />
      </section>

      <section style={{ marginBottom: '28px' }}>
        <h2 style={{ fontSize: '16px', fontWeight: 600, marginBottom: '8px' }}>8. Playbook outcome scorecard</h2>
        <DataTable
          rows={playbookRows}
          columns={playbookCols}
          emptyMessage="No playbook data."
          rowKey={(r, i) => String(r.response_playbook ?? i)}
        />
      </section>

      <section style={{ marginBottom: '28px' }}>
        <h2 style={{ fontSize: '16px', fontWeight: 600, marginBottom: '8px' }}>9. Open crisis queue (priority order)</h2>
        <DataTable
          rows={openRows}
          columns={openCols}
          emptyMessage="No open crisis items — clean week."
          rowKey={(r, i) => String(`${r.headline}-${r.due_at}` ?? i)}
        />
      </section>
    </div>
  );
}
