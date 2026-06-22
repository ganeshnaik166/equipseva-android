import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const sb = await getSupabaseServerClient();
  const [summary, recent, byTopic, topOutlets, pending, trend, accuracy] = await Promise.all([
    sb.rpc('founder_press_summary_r2257'),
    sb.rpc('founder_press_recent_mentions_r2257'),
    sb.rpc('founder_press_sentiment_by_topic_r2257'),
    sb.rpc('founder_press_top_outlets_r2257'),
    sb.rpc('founder_press_pending_actions_r2257'),
    sb.rpc('founder_press_monthly_trend_r2257'),
    sb.rpc('founder_press_accuracy_issues_r2257'),
  ]);

  const s = (summary.data && summary.data[0]) || {
    total_mentions: 0,
    mentions_last_30d: 0,
    mentions_last_90d: 0,
    positive_share_pct: 0,
    negative_share_pct: 0,
    total_reach_estimate: 0,
    avg_domain_authority: 0,
    pending_responses: 0,
    corrections_requested: 0,
    unique_outlets: 0,
  };

  const recentRows = (recent.data ?? []) as any[];
  const topicRows = (byTopic.data ?? []) as any[];
  const outletRows = (topOutlets.data ?? []) as any[];
  const pendingRows = (pending.data ?? []) as any[];
  const trendRows = (trend.data ?? []) as any[];
  const accuracyRows = (accuracy.data ?? []) as any[];

  const recentCols: Column<any>[] = [
    { key: 'published_on', header: 'Published', render: (r) => r.published_on },
    { key: 'outlet_name', header: 'Outlet', render: (r) => r.outlet_name },
    { key: 'outlet_type', header: 'Type', render: (r) => r.outlet_type },
    { key: 'headline', header: 'Headline', render: (r) => r.headline },
    { key: 'sentiment', header: 'Sentiment', render: (r) => r.sentiment },
    { key: 'topic_tag', header: 'Topic', render: (r) => r.topic_tag },
    { key: 'reach_estimate_readers', header: 'Reach', render: (r) => Number(r.reach_estimate_readers ?? 0).toLocaleString() },
    { key: 'domain_authority_score', header: 'DA', render: (r) => r.domain_authority_score ?? '-' },
    { key: 'response_status', header: 'Response', render: (r) => r.response_status },
    { key: 'amplification_priority', header: 'Amplify', render: (r) => r.amplification_priority },
  ];

  const topicCols: Column<any>[] = [
    { key: 'topic_tag', header: 'Topic', render: (r) => r.topic_tag },
    { key: 'total_mentions', header: 'Mentions', render: (r) => r.total_mentions },
    { key: 'positive_count', header: 'Positive', render: (r) => r.positive_count },
    { key: 'neutral_count', header: 'Neutral / mixed', render: (r) => r.neutral_count },
    { key: 'negative_count', header: 'Negative', render: (r) => r.negative_count },
    { key: 'total_reach', header: 'Total reach', render: (r) => Number(r.total_reach ?? 0).toLocaleString() },
    { key: 'avg_authority', header: 'Avg DA', render: (r) => r.avg_authority },
  ];

  const outletCols: Column<any>[] = [
    { key: 'outlet_name', header: 'Outlet', render: (r) => r.outlet_name },
    { key: 'outlet_type', header: 'Type', render: (r) => r.outlet_type },
    { key: 'mention_count', header: 'Mentions', render: (r) => r.mention_count },
    { key: 'total_reach', header: 'Total reach', render: (r) => Number(r.total_reach ?? 0).toLocaleString() },
    { key: 'avg_authority', header: 'Avg DA', render: (r) => r.avg_authority },
    { key: 'last_mention', header: 'Last mention', render: (r) => r.last_mention },
    { key: 'positive_pct', header: 'Positive %', render: (r) => `${r.positive_pct}%` },
  ];

  const pendingCols: Column<any>[] = [
    { key: 'outlet_name', header: 'Outlet', render: (r) => r.outlet_name },
    { key: 'headline', header: 'Headline', render: (r) => r.headline },
    { key: 'action_type', header: 'Action', render: (r) => r.action_type },
    { key: 'action_status', header: 'Status', render: (r) => r.action_status },
    { key: 'assigned_to_email', header: 'Owner', render: (r) => r.assigned_to_email ?? '-' },
    { key: 'due_on', header: 'Due', render: (r) => r.due_on ?? '-' },
    { key: 'days_until_due', header: 'Days left', render: (r) => r.days_until_due ?? '-' },
    { key: 'sentiment', header: 'Sentiment', render: (r) => r.sentiment },
  ];

  const trendCols: Column<any>[] = [
    { key: 'month_label', header: 'Month', render: (r) => r.month_label },
    { key: 'mention_count', header: 'Mentions', render: (r) => r.mention_count },
    { key: 'positive_count', header: 'Positive', render: (r) => r.positive_count },
    { key: 'negative_count', header: 'Negative', render: (r) => r.negative_count },
    { key: 'total_reach', header: 'Total reach', render: (r) => Number(r.total_reach ?? 0).toLocaleString() },
  ];

  const accuracyCols: Column<any>[] = [
    { key: 'outlet_name', header: 'Outlet', render: (r) => r.outlet_name },
    { key: 'headline', header: 'Headline', render: (r) => r.headline },
    { key: 'published_on', header: 'Published', render: (r) => r.published_on },
    { key: 'factual_accuracy', header: 'Accuracy', render: (r) => r.factual_accuracy },
    { key: 'sentiment', header: 'Sentiment', render: (r) => r.sentiment },
    { key: 'reach_estimate_readers', header: 'Reach', render: (r) => Number(r.reach_estimate_readers ?? 0).toLocaleString() },
    { key: 'response_status', header: 'Response', render: (r) => r.response_status },
  ];

  return (
    <main style={{ padding: 24, maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: 28, fontWeight: 700, marginBottom: 8 }}>Press & media mention log</h1>
      <p style={{ color: '#555', marginBottom: 24 }}>
        Track external articles, podcasts, blogs, and social posts mentioning Equipseva. Triage sentiment, plan responses, and amplify wins.
      </p>

      <section style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(180px, 1fr))', gap: 12, marginBottom: 24 }}>
        <Card label="Total mentions" value={s.total_mentions} />
        <Card label="Last 30 days" value={s.mentions_last_30d} />
        <Card label="Last 90 days" value={s.mentions_last_90d} />
        <Card label="Positive share" value={`${s.positive_share_pct}%`} />
        <Card label="Negative share" value={`${s.negative_share_pct}%`} />
        <Card label="Total reach (readers)" value={Number(s.total_reach_estimate ?? 0).toLocaleString()} />
        <Card label="Avg domain authority" value={s.avg_domain_authority} />
        <Card label="Unique outlets" value={s.unique_outlets} />
        <Card label="Pending review" value={s.pending_responses} />
        <Card label="Corrections requested" value={s.corrections_requested} />
      </section>

      <Section title="Recent mentions (most recent 100)" hint="Reverse chronological feed of every logged press hit.">
        <DataTable columns={recentCols} rows={recentRows} rowKey={(_, i) => String(i)} />
      </Section>

      <Section title="Sentiment by topic" hint="Where the press conversation skews positive vs negative.">
        <DataTable columns={topicCols} rows={topicRows} rowKey={(_, i) => String(i)} />
      </Section>

      <Section title="Top outlets by reach" hint="Outlets ranked by cumulative estimated readers.">
        <DataTable columns={outletCols} rows={outletRows} rowKey={(_, i) => String(i)} />
      </Section>

      <Section title="Pending response actions" hint="Thank-yous, correction emails, legal notices, and social amplification still open.">
        <DataTable columns={pendingCols} rows={pendingRows} rowKey={(_, i) => String(i)} />
      </Section>

      <Section title="Monthly trend (last 12 months)" hint="Press velocity over time with sentiment split.">
        <DataTable columns={trendCols} rows={trendRows} rowKey={(_, i) => String(i)} />
      </Section>

      <Section title="Accuracy issues requiring correction" hint="Mentions with minor errors, significant errors, or misleading framing.">
        <DataTable columns={accuracyCols} rows={accuracyRows} rowKey={(_, i) => String(i)} />
      </Section>
    </main>
  );
}

function Card({ label, value }: { label: string; value: any }) {
  return (
    <div style={{ border: '1px solid #e5e7eb', borderRadius: 8, padding: 16, background: '#fff' }}>
      <div style={{ fontSize: 12, color: '#6b7280', textTransform: 'uppercase', letterSpacing: 0.5 }}>{label}</div>
      <div style={{ fontSize: 24, fontWeight: 700, marginTop: 6 }}>{value}</div>
    </div>
  );
}

function Section({ title, hint, children }: { title: string; hint: string; children: React.ReactNode }) {
  return (
    <section style={{ marginBottom: 32 }}>
      <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 4 }}>{title}</h2>
      <p style={{ color: '#6b7280', fontSize: 13, marginBottom: 12 }}>{hint}</p>
      {children}
    </section>
  );
}
