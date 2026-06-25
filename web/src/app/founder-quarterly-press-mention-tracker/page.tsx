import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type KpiRow = { metric: string; value: number };
type QuarterRow = { quarter: string; mention_count: number; total_reach: number; positive_count: number; uvm_value: number };
type TopicRow = { topic: string; mention_count: number; avg_reach: number; positive_pct: number | null; total_pipeline: number };
type PublicationRow = { publication: string; publication_tier: string; mention_count: number; total_reach: number; avg_word_count: number };
type SentimentRow = { sentiment: string; prominence: string; mention_count: number; total_reach: number };
type FollowupImpactRow = { followup_type: string; business_impact: string; followup_count: number; pipeline_total: number; closed_total: number; avg_response_days: number };
type TopMentionRow = { quarter: string; publication: string; article_title: string; topic: string; sentiment: string; prominence: string; est_reach: number; est_uvm_rupees_value: number; published_at: string };
type FollowupListRow = { publication: string; article_title: string; followup_type: string; source_party: string; business_impact: string; pipeline_rupees: number; closed_rupees: number; days_to_response: number; recorded_at: string };

function fmtInt(n: number | null | undefined): string {
  if (n == null) return '-';
  return new Intl.NumberFormat('en-IN').format(n);
}

function fmtRupees(n: number | null | undefined): string {
  if (n == null) return '-';
  return '₹' + new Intl.NumberFormat('en-IN').format(n);
}

function metricLabel(key: string): string {
  switch (key) {
    case 'total_mentions': return 'Total mentions';
    case 'total_reach': return 'Total reach';
    case 'total_uvm_rupees_value': return 'UVM value';
    case 'positive_share_pct': return 'Positive share %';
    case 'pipeline_rupees': return 'Pipeline';
    case 'closed_rupees': return 'Closed';
    case 'tier1_mentions': return 'Tier-1 mentions';
    default: return key;
  }
}

function metricFmt(key: string, v: number): string {
  if (key === 'positive_share_pct') return `${v}%`;
  if (key === 'total_uvm_rupees_value' || key === 'pipeline_rupees' || key === 'closed_rupees') return fmtRupees(v);
  return fmtInt(v);
}

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [kpis, quarters, topics, publications, sentiment, followupImpact, topMentions, followupList] = await Promise.all([
    supabase.rpc('rpc_r2689_quarterly_kpis'),
    supabase.rpc('rpc_r2689_mentions_by_quarter'),
    supabase.rpc('rpc_r2689_topic_breakdown'),
    supabase.rpc('rpc_r2689_publication_leaderboard'),
    supabase.rpc('rpc_r2689_sentiment_matrix'),
    supabase.rpc('rpc_r2689_followup_impact'),
    supabase.rpc('rpc_r2689_top_mentions'),
    supabase.rpc('rpc_r2689_followup_list'),
  ]);

  const kpiRows: KpiRow[] = (kpis.data ?? []) as KpiRow[];
  const quarterRows: QuarterRow[] = (quarters.data ?? []) as QuarterRow[];
  const topicRows: TopicRow[] = (topics.data ?? []) as TopicRow[];
  const publicationRows: PublicationRow[] = (publications.data ?? []) as PublicationRow[];
  const sentimentRows: SentimentRow[] = (sentiment.data ?? []) as SentimentRow[];
  const followupImpactRows: FollowupImpactRow[] = (followupImpact.data ?? []) as FollowupImpactRow[];
  const topMentionRows: TopMentionRow[] = (topMentions.data ?? []) as TopMentionRow[];
  const followupListRows: FollowupListRow[] = (followupList.data ?? []) as FollowupListRow[];

  return (
    <main style={{ padding: '24px', maxWidth: '1280px', margin: '0 auto' }}>
      <h1 style={{ fontSize: '28px', fontWeight: 700, marginBottom: '4px' }}>Quarterly Press Mention Tracker</h1>
      <p style={{ color: '#666', marginBottom: '24px' }}>
        Publication × topic × sentiment × reach × follow-up × business impact.
      </p>

      <section style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(180px, 1fr))', gap: '12px', marginBottom: '32px' }}>
        {kpiRows.map((k) => (
          <div key={k.metric} style={{ border: '1px solid #e5e7eb', borderRadius: '8px', padding: '16px' }}>
            <div style={{ fontSize: '12px', color: '#666', textTransform: 'uppercase' }}>{metricLabel(k.metric)}</div>
            <div style={{ fontSize: '22px', fontWeight: 600, marginTop: '6px' }}>{metricFmt(k.metric, Number(k.value))}</div>
          </div>
        ))}
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '20px', fontWeight: 600, marginBottom: '12px' }}>Mentions by quarter</h2>
        <DataTable
          rows={quarterRows}
          columns={[
            { key: 'quarter', header: 'Quarter', render: (r: QuarterRow) => r.quarter },
            { key: 'mention_count', header: 'Mentions', render: (r: QuarterRow) => fmtInt(r.mention_count) },
            { key: 'total_reach', header: 'Reach', render: (r: QuarterRow) => fmtInt(r.total_reach) },
            { key: 'positive_count', header: 'Positive', render: (r: QuarterRow) => fmtInt(r.positive_count) },
            { key: 'uvm_value', header: 'UVM Value', render: (r: QuarterRow) => fmtRupees(r.uvm_value) },
          ]}
          emptyMessage="No data"
          rowKey={(r: QuarterRow, i: number) => String(r.quarter ?? i)}
        />
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '20px', fontWeight: 600, marginBottom: '12px' }}>Topic breakdown</h2>
        <DataTable
          rows={topicRows}
          columns={[
            { key: 'topic', header: 'Topic', render: (r: TopicRow) => r.topic },
            { key: 'mention_count', header: 'Mentions', render: (r: TopicRow) => fmtInt(r.mention_count) },
            { key: 'avg_reach', header: 'Avg reach', render: (r: TopicRow) => fmtInt(r.avg_reach) },
            { key: 'positive_pct', header: 'Positive %', render: (r: TopicRow) => r.positive_pct == null ? '-' : `${r.positive_pct}%` },
            { key: 'total_pipeline', header: 'Pipeline', render: (r: TopicRow) => fmtRupees(r.total_pipeline) },
          ]}
          emptyMessage="No data"
          rowKey={(r: TopicRow, i: number) => String(r.topic ?? i)}
        />
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '20px', fontWeight: 600, marginBottom: '12px' }}>Publication leaderboard</h2>
        <DataTable
          rows={publicationRows}
          columns={[
            { key: 'publication', header: 'Publication', render: (r: PublicationRow) => r.publication },
            { key: 'publication_tier', header: 'Tier', render: (r: PublicationRow) => r.publication_tier },
            { key: 'mention_count', header: 'Mentions', render: (r: PublicationRow) => fmtInt(r.mention_count) },
            { key: 'total_reach', header: 'Total reach', render: (r: PublicationRow) => fmtInt(r.total_reach) },
            { key: 'avg_word_count', header: 'Avg words', render: (r: PublicationRow) => fmtInt(r.avg_word_count) },
          ]}
          emptyMessage="No data"
          rowKey={(r: PublicationRow, i: number) => String(r.publication ?? i)}
        />
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '20px', fontWeight: 600, marginBottom: '12px' }}>Sentiment & prominence matrix</h2>
        <DataTable
          rows={sentimentRows}
          columns={[
            { key: 'sentiment', header: 'Sentiment', render: (r: SentimentRow) => r.sentiment },
            { key: 'prominence', header: 'Prominence', render: (r: SentimentRow) => r.prominence },
            { key: 'mention_count', header: 'Mentions', render: (r: SentimentRow) => fmtInt(r.mention_count) },
            { key: 'total_reach', header: 'Reach', render: (r: SentimentRow) => fmtInt(r.total_reach) },
          ]}
          emptyMessage="No data"
          rowKey={(r: SentimentRow, i: number) => `${r.sentiment}-${r.prominence}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '20px', fontWeight: 600, marginBottom: '12px' }}>Follow-up impact</h2>
        <DataTable
          rows={followupImpactRows}
          columns={[
            { key: 'followup_type', header: 'Follow-up', render: (r: FollowupImpactRow) => r.followup_type },
            { key: 'business_impact', header: 'Impact', render: (r: FollowupImpactRow) => r.business_impact },
            { key: 'followup_count', header: 'Count', render: (r: FollowupImpactRow) => fmtInt(r.followup_count) },
            { key: 'pipeline_total', header: 'Pipeline', render: (r: FollowupImpactRow) => fmtRupees(r.pipeline_total) },
            { key: 'closed_total', header: 'Closed', render: (r: FollowupImpactRow) => fmtRupees(r.closed_total) },
            { key: 'avg_response_days', header: 'Avg days', render: (r: FollowupImpactRow) => `${r.avg_response_days}` },
          ]}
          emptyMessage="No data"
          rowKey={(r: FollowupImpactRow, i: number) => `${r.followup_type}-${r.business_impact}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '20px', fontWeight: 600, marginBottom: '12px' }}>Top mentions by reach</h2>
        <DataTable
          rows={topMentionRows}
          columns={[
            { key: 'quarter', header: 'Q', render: (r: TopMentionRow) => r.quarter },
            { key: 'publication', header: 'Publication', render: (r: TopMentionRow) => r.publication },
            { key: 'article_title', header: 'Title', render: (r: TopMentionRow) => r.article_title },
            { key: 'topic', header: 'Topic', render: (r: TopMentionRow) => r.topic },
            { key: 'sentiment', header: 'Sentiment', render: (r: TopMentionRow) => r.sentiment },
            { key: 'prominence', header: 'Prominence', render: (r: TopMentionRow) => r.prominence },
            { key: 'est_reach', header: 'Reach', render: (r: TopMentionRow) => fmtInt(r.est_reach) },
            { key: 'est_uvm_rupees_value', header: 'UVM', render: (r: TopMentionRow) => fmtRupees(r.est_uvm_rupees_value) },
            { key: 'published_at', header: 'Published', render: (r: TopMentionRow) => new Date(r.published_at).toLocaleDateString('en-IN') },
          ]}
          emptyMessage="No data"
          rowKey={(r: TopMentionRow, i: number) => `${r.publication}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '20px', fontWeight: 600, marginBottom: '12px' }}>Follow-up log</h2>
        <DataTable
          rows={followupListRows}
          columns={[
            { key: 'publication', header: 'Publication', render: (r: FollowupListRow) => r.publication },
            { key: 'article_title', header: 'Article', render: (r: FollowupListRow) => r.article_title },
            { key: 'followup_type', header: 'Type', render: (r: FollowupListRow) => r.followup_type },
            { key: 'source_party', header: 'Source', render: (r: FollowupListRow) => r.source_party },
            { key: 'business_impact', header: 'Impact', render: (r: FollowupListRow) => r.business_impact },
            { key: 'pipeline_rupees', header: 'Pipeline', render: (r: FollowupListRow) => fmtRupees(r.pipeline_rupees) },
            { key: 'closed_rupees', header: 'Closed', render: (r: FollowupListRow) => fmtRupees(r.closed_rupees) },
            { key: 'days_to_response', header: 'Days', render: (r: FollowupListRow) => fmtInt(r.days_to_response) },
            { key: 'recorded_at', header: 'Recorded', render: (r: FollowupListRow) => new Date(r.recorded_at).toLocaleDateString('en-IN') },
          ]}
          emptyMessage="No data"
          rowKey={(r: FollowupListRow, i: number) => `${r.publication}-${i}`}
        />
      </section>
    </main>
  );
}