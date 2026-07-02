import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type Mention = {
  id: string;
  publication: string;
  mention_url: string | null;
  mention_type: string;
  mention_date: string;
  sentiment: string;
  reach_estimate: number;
  status: string;
  captured_at: string;
};

type TopPub = {
  publication: string;
  mentions: number;
  total_reach: number;
  positive_count: number;
  critical_count: number;
};

type RecentOutreach = {
  id: string;
  mention_id: string;
  publication: string;
  action_type: string;
  taken_at: string;
  by_email: string | null;
};

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [mentionsRes, topPubsRes, outreachRes] = await Promise.all([
    sb.rpc('list_mentions_r1902'),
    sb.rpc('top_publications_r1902'),
    sb.rpc('recent_outreach_r1902'),
  ]);

  const mentions: Mention[] = (mentionsRes.data as Mention[] | null) ?? [];
  const topPubs: TopPub[] = (topPubsRes.data as TopPub[] | null) ?? [];
  const outreach: RecentOutreach[] = (outreachRes.data as RecentOutreach[] | null) ?? [];

  const totalMentions = mentions.length;
  const totalReach = mentions.reduce((a, m) => a + (m.reach_estimate || 0), 0);
  const positiveShare =
    totalMentions > 0
      ? Math.round(
          (mentions.filter((m) => m.sentiment === 'positive').length / totalMentions) * 100,
        )
      : 0;
  const criticalCount = mentions.filter((m) => m.sentiment === 'critical').length;

  const mentionColumns: Column<Mention>[] = [
    { key: 'mention_date', header: 'Date', render: (r: any) => String(r.mention_date ?? '') },
    { key: 'publication', header: 'Publication', render: (r: any) => String(r.publication ?? '') },
    { key: 'mention_type', header: 'Type', render: (r: any) => String(r.mention_type ?? '') },
    { key: 'sentiment', header: 'Sentiment', render: (r: any) => String(r.sentiment ?? '') },
    {
      key: 'reach_estimate',
      header: 'Reach',
      render: (r: any) => Number(r.reach_estimate ?? 0).toLocaleString(),
    },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
    {
      key: 'mention_url',
      header: 'URL',
      render: (r: any) =>
        r.mention_url ? (
          <a
            href={String(r.mention_url)}
            target="_blank"
            rel="noreferrer"
            style={{ color: '#2563eb', textDecoration: 'underline' }}
          >
            open
          </a>
        ) : (
          <span style={{ color: '#9ca3af' }}>—</span>
        ),
    },
  ];

  const topPubColumns: Column<TopPub>[] = [
    { key: 'publication', header: 'Publication', render: (r: any) => String(r.publication ?? '') },
    {
      key: 'mentions',
      header: 'Mentions',
      render: (r: any) => Number(r.mentions ?? 0).toLocaleString(),
    },
    {
      key: 'total_reach',
      header: 'Total reach',
      render: (r: any) => Number(r.total_reach ?? 0).toLocaleString(),
    },
    {
      key: 'positive_count',
      header: 'Positive',
      render: (r: any) => Number(r.positive_count ?? 0).toLocaleString(),
    },
    {
      key: 'critical_count',
      header: 'Critical',
      render: (r: any) => Number(r.critical_count ?? 0).toLocaleString(),
    },
  ];

  const outreachColumns: Column<RecentOutreach>[] = [
    {
      key: 'taken_at',
      header: 'When',
      render: (r: any) =>
        r.taken_at ? new Date(String(r.taken_at)).toLocaleString() : '',
    },
    { key: 'publication', header: 'Publication', render: (r: any) => String(r.publication ?? '') },
    { key: 'action_type', header: 'Action', render: (r: any) => String(r.action_type ?? '') },
    {
      key: 'by_email',
      header: 'By',
      render: (r: any) => String(r.by_email ?? ''),
    },
  ];

  return (
    <main style={{ padding: 24, maxWidth: 1200, margin: '0 auto' }}>
      <header style={{ marginBottom: 24 }}>
        <h1 style={{ fontSize: 28, fontWeight: 700, margin: 0 }}>Founder Press Mention Log</h1>
        <p style={{ color: '#6b7280', marginTop: 6 }}>
          Track every press mention across news, podcasts & social. Tag sentiment, estimate reach,
          and log outreach so no thank-you slips through.
        </p>
      </header>

      <section
        style={{
          display: 'grid',
          gridTemplateColumns: 'repeat(auto-fit, minmax(180px, 1fr))',
          gap: 12,
          marginBottom: 28,
        }}
      >
        <div style={cardStyle}>
          <div style={kpiLabel}>Total mentions</div>
          <div style={kpiValue}>{totalMentions.toLocaleString()}</div>
        </div>
        <div style={cardStyle}>
          <div style={kpiLabel}>Total reach</div>
          <div style={kpiValue}>{totalReach.toLocaleString()}</div>
        </div>
        <div style={cardStyle}>
          <div style={kpiLabel}>Positive share</div>
          <div style={kpiValue}>{positiveShare}%</div>
        </div>
        <div style={cardStyle}>
          <div style={kpiLabel}>Critical mentions</div>
          <div style={{ ...kpiValue, color: criticalCount > 0 ? '#b91c1c' : '#111827' }}>
            {criticalCount.toLocaleString()}
          </div>
        </div>
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={sectionTitle}>Recent mentions</h2>
        <p style={sectionSub}>Most recent 200 mentions, newest first.</p>
        <DataTable
          rows={mentions}
          columns={mentionColumns}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={sectionTitle}>Top publications</h2>
        <p style={sectionSub}>
          Publications ranked by mention count & total estimated reach.
        </p>
        <DataTable
          rows={topPubs}
          columns={topPubColumns}
          rowKey={(r: any, i: number) => String(r.publication ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={sectionTitle}>Recent outreach</h2>
        <p style={sectionSub}>Last 100 outreach actions logged against tracked mentions.</p>
        <DataTable
          rows={outreach}
          columns={outreachColumns}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>
    </main>
  );
}

const cardStyle: React.CSSProperties = {
  border: '1px solid #e5e7eb',
  borderRadius: 10,
  padding: 14,
  background: '#fff',
};

const kpiLabel: React.CSSProperties = {
  fontSize: 12,
  color: '#6b7280',
  textTransform: 'uppercase',
  letterSpacing: 0.4,
};

const kpiValue: React.CSSProperties = {
  fontSize: 22,
  fontWeight: 700,
  marginTop: 4,
  color: '#111827',
};

const sectionTitle: React.CSSProperties = {
  fontSize: 18,
  fontWeight: 600,
  margin: 0,
  marginBottom: 4,
  color: '#111827',
};

const sectionSub: React.CSSProperties = {
  fontSize: 13,
  color: '#6b7280',
  marginTop: 0,
  marginBottom: 12,
};
