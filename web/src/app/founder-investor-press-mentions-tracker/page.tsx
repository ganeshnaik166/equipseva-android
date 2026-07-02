import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function FounderInvestorPressMentionsTrackerPage() {
  const sb = await getSupabaseServerClient();

  const [mentionsRes, sentimentRes, publicationsRes, quotesRes, followupsRes] = await Promise.all([
    sb.rpc('list_mentions_r1717'),
    sb.rpc('sentiment_summary_r1717'),
    sb.rpc('top_publications_r1717'),
    sb.rpc('recent_positive_quotes_r1717'),
    sb.rpc('list_followups_r1717', { p_mention_id: null }),
  ]);

  const mentions: any[] = Array.isArray(mentionsRes.data) ? mentionsRes.data : [];
  const sentiment: any[] = Array.isArray(sentimentRes.data) ? sentimentRes.data : [];
  const publications: any[] = Array.isArray(publicationsRes.data) ? publicationsRes.data : [];
  const quotes: any[] = Array.isArray(quotesRes.data) ? quotesRes.data : [];
  const followups: any[] = Array.isArray(followupsRes.data) ? followupsRes.data : [];

  const totalMentions = mentions.length;
  const totalReach = mentions.reduce((s, m) => s + (Number(m.audience_reach) || 0), 0);
  const positiveCount = mentions.filter((m) => m.sentiment === 'very_positive' || m.sentiment === 'positive').length;
  const negativeCount = mentions.filter((m) => m.sentiment === 'very_negative' || m.sentiment === 'negative').length;

  const mentionCols: Column<any>[] = [
    { key: 'published_at', header: 'Published', render: (r: any) => (r.published_at ? new Date(r.published_at).toLocaleDateString() : '—') },
    { key: 'publication', header: 'Publication', render: (r: any) => r.publication ?? '—' },
    { key: 'article_title', header: 'Title', render: (r: any) => (
      r.article_url ? <a href={r.article_url} target="_blank" rel="noreferrer" className="text-blue-700 underline">{r.article_title}</a> : (r.article_title ?? '—')
    ) },
    { key: 'sentiment', header: 'Sentiment', render: (r: any) => <span className="font-mono text-xs">{r.sentiment ?? '—'}</span> },
    { key: 'audience_reach', header: 'Reach', render: (r: any) => Number(r.audience_reach ?? 0).toLocaleString() },
    { key: 'quoted_directly', header: 'Quoted', render: (r: any) => (r.quoted_directly ? 'yes' : 'no') },
    { key: 'followup_count', header: 'Follow-ups', render: (r: any) => Number(r.followup_count ?? 0) },
  ];

  const sentimentCols: Column<any>[] = [
    { key: 'sentiment', header: 'Sentiment', render: (r: any) => r.sentiment ?? '—' },
    { key: 'mention_count', header: 'Mentions', render: (r: any) => Number(r.mention_count ?? 0) },
    { key: 'total_reach', header: 'Total Reach', render: (r: any) => Number(r.total_reach ?? 0).toLocaleString() },
    { key: 'avg_reach', header: 'Avg Reach', render: (r: any) => Number(r.avg_reach ?? 0).toLocaleString() },
  ];

  const pubCols: Column<any>[] = [
    { key: 'publication', header: 'Publication', render: (r: any) => r.publication ?? '—' },
    { key: 'mention_count', header: 'Mentions', render: (r: any) => Number(r.mention_count ?? 0) },
    { key: 'total_reach', header: 'Total Reach', render: (r: any) => Number(r.total_reach ?? 0).toLocaleString() },
    { key: 'positive_count', header: 'Positive', render: (r: any) => Number(r.positive_count ?? 0) },
    { key: 'negative_count', header: 'Negative', render: (r: any) => Number(r.negative_count ?? 0) },
  ];

  const quoteCols: Column<any>[] = [
    { key: 'published_at', header: 'Published', render: (r: any) => (r.published_at ? new Date(r.published_at).toLocaleDateString() : '—') },
    { key: 'publication', header: 'Publication', render: (r: any) => r.publication ?? '—' },
    { key: 'article_title', header: 'Title', render: (r: any) => (
      r.article_url ? <a href={r.article_url} target="_blank" rel="noreferrer" className="text-blue-700 underline">{r.article_title}</a> : (r.article_title ?? '—')
    ) },
    { key: 'key_quote_md', header: 'Quote', render: (r: any) => <span className="text-sm italic">{r.key_quote_md ?? '—'}</span> },
    { key: 'audience_reach', header: 'Reach', render: (r: any) => Number(r.audience_reach ?? 0).toLocaleString() },
  ];

  const followupCols: Column<any>[] = [
    { key: 'taken_at', header: 'Taken', render: (r: any) => (r.taken_at ? new Date(r.taken_at).toLocaleString() : '—') },
    { key: 'action_type', header: 'Action', render: (r: any) => <span className="font-mono text-xs">{r.action_type ?? '—'}</span> },
    { key: 'by_email', header: 'By', render: (r: any) => r.by_email ?? '—' },
    { key: 'note', header: 'Note', render: (r: any) => r.note ?? '—' },
    { key: 'mention_id', header: 'Mention', render: (r: any) => <span className="font-mono text-xs">{String(r.mention_id ?? '').slice(0, 8)}</span> },
  ];

  return (
    <div className="mx-auto max-w-7xl p-6 space-y-8">
      <header className="space-y-1">
        <h1 className="text-2xl font-bold">Investor Press Mentions Tracker</h1>
        <p className="text-sm text-gray-600">
          Round r1717 — track media mentions per investor with sentiment & reach.
        </p>
      </header>

      <section className="grid grid-cols-2 md:grid-cols-4 gap-4">
        <div className="rounded border border-gray-200 p-4">
          <div className="text-xs uppercase text-gray-500">Total Mentions</div>
          <div className="text-2xl font-bold">{totalMentions}</div>
        </div>
        <div className="rounded border border-gray-200 p-4">
          <div className="text-xs uppercase text-gray-500">Total Reach</div>
          <div className="text-2xl font-bold">{totalReach.toLocaleString()}</div>
        </div>
        <div className="rounded border border-gray-200 p-4">
          <div className="text-xs uppercase text-gray-500">Positive</div>
          <div className="text-2xl font-bold text-green-700">{positiveCount}</div>
        </div>
        <div className="rounded border border-gray-200 p-4">
          <div className="text-xs uppercase text-gray-500">Negative</div>
          <div className="text-2xl font-bold text-red-700">{negativeCount}</div>
        </div>
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-semibold">Sentiment Summary</h2>
        <p className="text-sm text-gray-600">Distribution across all logged mentions (positive sentiments boost momentum).</p>
        <DataTable rows={sentiment} columns={sentimentCols} rowKey={(r: any, i: number) => String(r.sentiment ?? i)} />
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-semibold">Top Publications</h2>
        <p className="text-sm text-gray-600">Publications ranked by mention count (top 50).</p>
        <DataTable rows={publications} columns={pubCols} rowKey={(r: any, i: number) => String(r.publication ?? i)} />
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-semibold">All Mentions</h2>
        <p className="text-sm text-gray-600">Latest 200 mentions across all investors & publications.</p>
        <DataTable rows={mentions} columns={mentionCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-semibold">Recent Positive Quotes</h2>
        <p className="text-sm text-gray-600">Direct quotes from positive coverage — candidates for deck inclusion.</p>
        <DataTable rows={quotes} columns={quoteCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-semibold">Recent Follow-ups</h2>
        <p className="text-sm text-gray-600">Actions taken on tracked mentions (thank-emails, social shares, deck inclusions, PR follow-ups).</p>
        <DataTable rows={followups} columns={followupCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>
    </div>
  );
}
