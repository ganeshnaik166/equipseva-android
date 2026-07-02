import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type KpiRow = {
  total_events: number;
  total_engineers: number;
  positive_pct: number;
  neutral_pct: number;
  negative_pct: number;
  avg_sentiment: number;
  avg_engagement_sec: number;
  followups_open: number;
};

type LeaderRow = {
  engineer_code: string;
  engineer_name: string;
  total_handovers: number;
  avg_sentiment: number;
  ack_rate_pct: number;
  top_emoji: string;
  rollup_grade: string;
};

type EmojiRow = {
  emoji: string;
  emoji_label: string;
  count: number;
  share_pct: number;
};

type SentimentRow = {
  sentiment_bucket: string;
  count: number;
  avg_engagement_seconds: number;
};

type OutcomeRow = {
  outcome: string;
  count: number;
  followups: number;
  avg_sentiment: number;
};

type EventRow = {
  engineer_name: string;
  hospital_name: string;
  emoji: string;
  emoji_label: string;
  sentiment_score: number;
  outcome: string;
  acknowledged_at: string;
};

type FollowupRow = {
  engineer_name: string;
  hospital_name: string;
  emoji: string;
  outcome: string;
  remarks: string | null;
  acknowledged_at: string;
};

type BandRow = {
  band: string;
  count: number;
  avg_sentiment: number;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    kpiRes,
    leaderRes,
    emojiRes,
    sentimentRes,
    outcomeRes,
    recentRes,
    followupRes,
    bandRes,
  ] = await Promise.all([
    supabase.rpc('founder_r2858_kpi_summary'),
    supabase.rpc('founder_r2858_engineer_leaderboard'),
    supabase.rpc('founder_r2858_emoji_distribution'),
    supabase.rpc('founder_r2858_sentiment_buckets'),
    supabase.rpc('founder_r2858_outcome_breakdown'),
    supabase.rpc('founder_r2858_recent_events'),
    supabase.rpc('founder_r2858_followup_queue'),
    supabase.rpc('founder_r2858_engagement_bands'),
  ]);

  const kpi: KpiRow | null =
    Array.isArray(kpiRes.data) && kpiRes.data.length > 0
      ? (kpiRes.data[0] as KpiRow)
      : null;
  const leaders = (leaderRes.data ?? []) as LeaderRow[];
  const emojis = (emojiRes.data ?? []) as EmojiRow[];
  const sentiments = (sentimentRes.data ?? []) as SentimentRow[];
  const outcomes = (outcomeRes.data ?? []) as OutcomeRow[];
  const recents = (recentRes.data ?? []) as EventRow[];
  const followups = (followupRes.data ?? []) as FollowupRow[];
  const bands = (bandRes.data ?? []) as BandRow[];

  const kpiCards = [
    { label: 'Total Acks', value: kpi?.total_events ?? 0 },
    { label: 'Engineers', value: kpi?.total_engineers ?? 0 },
    { label: 'Positive %', value: kpi?.positive_pct ?? 0 },
    { label: 'Neutral %', value: kpi?.neutral_pct ?? 0 },
    { label: 'Negative %', value: kpi?.negative_pct ?? 0 },
    { label: 'Avg Sentiment', value: kpi?.avg_sentiment ?? 0 },
    { label: 'Avg Engagement (s)', value: kpi?.avg_engagement_sec ?? 0 },
    { label: 'Followups Open', value: kpi?.followups_open ?? 0 },
  ];

  return (
    <main style={{ padding: 24, maxWidth: 1280, margin: '0 auto' }}>
      <header style={{ marginBottom: 24 }}>
        <h1 style={{ fontSize: 28, fontWeight: 700 }}>
          Engineer Monthly Customer Handover Acknowledgement Emoji
        </h1>
        <p style={{ color: '#555', marginTop: 6 }}>
          Track monthly handover acknowledgements per engineer: emoji response,
          sentiment, engagement seconds & downstream outcome (round 2858).
        </p>
      </header>

      <section
        style={{
          display: 'grid',
          gridTemplateColumns: 'repeat(auto-fit, minmax(160px, 1fr))',
          gap: 12,
          marginBottom: 24,
        }}
      >
        {kpiCards.map((card) => (
          <div
            key={card.label}
            style={{
              border: '1px solid #e5e7eb',
              borderRadius: 12,
              padding: 14,
              background: '#fff',
            }}
          >
            <div style={{ fontSize: 12, color: '#6b7280' }}>{card.label}</div>
            <div style={{ fontSize: 22, fontWeight: 700, marginTop: 4 }}>
              {String(card.value)}
            </div>
          </div>
        ))}
      </section>

      <section style={{ marginBottom: 24 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 8 }}>
          Engineer Leaderboard
        </h2>
        <DataTable<LeaderRow>
          rows={leaders}
          columns={[
            { key: 'engineer_code', header: 'Code', render: (r) => r.engineer_code },
            { key: 'engineer_name', header: 'Engineer', render: (r) => r.engineer_name },
            { key: 'total_handovers', header: 'Handovers', render: (r) => r.total_handovers },
            { key: 'ack_rate_pct', header: 'Ack %', render: (r) => `${r.ack_rate_pct}%` },
            { key: 'avg_sentiment', header: 'Avg Sentiment', render: (r) => r.avg_sentiment },
            { key: 'top_emoji', header: 'Top Emoji', render: (r) => r.top_emoji },
            { key: 'rollup_grade', header: 'Grade', render: (r) => r.rollup_grade },
          ]}
          emptyMessage="No data"
          rowKey={(r, i) => String(r.engineer_code ?? i)}
        />
      </section>

      <section style={{ marginBottom: 24 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 8 }}>
          Emoji Distribution
        </h2>
        <DataTable<EmojiRow>
          rows={emojis}
          columns={[
            { key: 'emoji', header: 'Emoji', render: (r) => r.emoji },
            { key: 'emoji_label', header: 'Label', render: (r) => r.emoji_label },
            { key: 'count', header: 'Count', render: (r) => r.count },
            { key: 'share_pct', header: 'Share %', render: (r) => `${r.share_pct}%` },
          ]}
          emptyMessage="No data"
          rowKey={(r, i) => String(r.emoji ?? i)}
        />
      </section>

      <section style={{ marginBottom: 24 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 8 }}>
          Sentiment Buckets
        </h2>
        <DataTable<SentimentRow>
          rows={sentiments}
          columns={[
            { key: 'sentiment_bucket', header: 'Bucket', render: (r) => r.sentiment_bucket },
            { key: 'count', header: 'Count', render: (r) => r.count },
            {
              key: 'avg_engagement_seconds',
              header: 'Avg Engagement (s)',
              render: (r) => r.avg_engagement_seconds,
            },
          ]}
          emptyMessage="No data"
          rowKey={(r, i) => String(r.sentiment_bucket ?? i)}
        />
      </section>

      <section style={{ marginBottom: 24 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 8 }}>
          Outcome Breakdown
        </h2>
        <DataTable<OutcomeRow>
          rows={outcomes}
          columns={[
            { key: 'outcome', header: 'Outcome', render: (r) => r.outcome },
            { key: 'count', header: 'Count', render: (r) => r.count },
            { key: 'followups', header: 'Followups', render: (r) => r.followups },
            { key: 'avg_sentiment', header: 'Avg Sentiment', render: (r) => r.avg_sentiment },
          ]}
          emptyMessage="No data"
          rowKey={(r, i) => String(r.outcome ?? i)}
        />
      </section>

      <section style={{ marginBottom: 24 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 8 }}>
          Engagement Bands
        </h2>
        <DataTable<BandRow>
          rows={bands}
          columns={[
            { key: 'band', header: 'Band', render: (r) => r.band },
            { key: 'count', header: 'Count', render: (r) => r.count },
            { key: 'avg_sentiment', header: 'Avg Sentiment', render: (r) => r.avg_sentiment },
          ]}
          emptyMessage="No data"
          rowKey={(r, i) => String(r.band ?? i)}
        />
      </section>

      <section style={{ marginBottom: 24 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 8 }}>
          Recent Acknowledgements
        </h2>
        <DataTable<EventRow>
          rows={recents}
          columns={[
            { key: 'engineer_name', header: 'Engineer', render: (r) => r.engineer_name },
            { key: 'hospital_name', header: 'Hospital', render: (r) => r.hospital_name },
            { key: 'emoji', header: 'Emoji', render: (r) => r.emoji },
            { key: 'emoji_label', header: 'Label', render: (r) => r.emoji_label },
            { key: 'sentiment_score', header: 'Sentiment', render: (r) => r.sentiment_score },
            { key: 'outcome', header: 'Outcome', render: (r) => r.outcome },
            {
              key: 'acknowledged_at',
              header: 'Acked At',
              render: (r) => new Date(r.acknowledged_at).toLocaleString(),
            },
          ]}
          emptyMessage="No data"
          rowKey={(r, i) => String(i)}
        />
      </section>

      <section style={{ marginBottom: 24 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 8 }}>
          Followup Queue
        </h2>
        <DataTable<FollowupRow>
          rows={followups}
          columns={[
            { key: 'engineer_name', header: 'Engineer', render: (r) => r.engineer_name },
            { key: 'hospital_name', header: 'Hospital', render: (r) => r.hospital_name },
            { key: 'emoji', header: 'Emoji', render: (r) => r.emoji },
            { key: 'outcome', header: 'Outcome', render: (r) => r.outcome },
            { key: 'remarks', header: 'Remarks', render: (r) => r.remarks ?? '' },
            {
              key: 'acknowledged_at',
              header: 'Acked At',
              render: (r) => new Date(r.acknowledged_at).toLocaleString(),
            },
          ]}
          emptyMessage="No data"
          rowKey={(r, i) => String(i)}
        />
      </section>
    </main>
  );
}
