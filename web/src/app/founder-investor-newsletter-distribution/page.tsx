import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function FounderInvestorNewsletterDistributionPage() {
  const sb = await getSupabaseServerClient();

  const [distRes, segRes, topRes, sentRes] = await Promise.all([
    sb.rpc('list_distributions_r1805'),
    sb.rpc('list_segments_r1805'),
    sb.rpc('top_engaged_investors_r1805'),
    sb.rpc('sentiment_summary_r1805'),
  ]);

  const distributions: any[] = Array.isArray(distRes.data) ? distRes.data : [];
  const segments: any[] = Array.isArray(segRes.data) ? segRes.data : [];
  const topInvestors: any[] = Array.isArray(topRes.data) ? topRes.data : [];
  const sentiments: any[] = Array.isArray(sentRes.data) ? sentRes.data : [];

  const distColumns: Column<any>[] = [
    { key: 'newsletter_id', header: 'Newsletter', render: (r: any) => String(r.newsletter_id ?? '').slice(0, 8) },
    { key: 'investor_email', header: 'Investor', render: (r: any) => r.investor_email ?? '—' },
    { key: 'sent_at', header: 'Sent', render: (r: any) => r.sent_at ? new Date(r.sent_at).toLocaleString() : '—' },
    { key: 'opened_at', header: 'Opened', render: (r: any) => r.opened_at ? new Date(r.opened_at).toLocaleString() : '—' },
    { key: 'click_count', header: 'Clicks', render: (r: any) => String(r.click_count ?? 0) },
    { key: 'sentiment_inferred', header: 'Sentiment', render: (r: any) => r.sentiment_inferred ?? 'no_signal' },
    { key: 'replied', header: 'Replied', render: (r: any) => r.replied ? 'yes' : 'no' },
    { key: 'reply_summary', header: 'Reply', render: (r: any) => r.reply_summary ?? '—' },
  ];

  const segColumns: Column<any>[] = [
    { key: 'distribution_id', header: 'Distribution', render: (r: any) => String(r.distribution_id ?? '').slice(0, 8) },
    { key: 'segment', header: 'Segment', render: (r: any) => r.segment ?? '—' },
    { key: 'custom_message_sent', header: 'Custom Msg', render: (r: any) => r.custom_message_sent ? 'yes' : 'no' },
    { key: 'created_at', header: 'Created', render: (r: any) => r.created_at ? new Date(r.created_at).toLocaleString() : '—' },
  ];

  const topColumns: Column<any>[] = [
    { key: 'investor_email', header: 'Investor', render: (r: any) => r.investor_email ?? '—' },
    { key: 'total_sends', header: 'Sends', render: (r: any) => String(r.total_sends ?? 0) },
    { key: 'total_opens', header: 'Opens', render: (r: any) => String(r.total_opens ?? 0) },
    { key: 'total_clicks', header: 'Clicks', render: (r: any) => String(r.total_clicks ?? 0) },
    { key: 'replies', header: 'Replies', render: (r: any) => String(r.replies ?? 0) },
  ];

  const sentColumns: Column<any>[] = [
    { key: 'sentiment', header: 'Sentiment', render: (r: any) => r.sentiment ?? 'no_signal' },
    { key: 'cnt', header: 'Count', render: (r: any) => String(r.cnt ?? 0) },
  ];

  return (
    <div style={{ padding: 24, maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: 24, fontWeight: 700, marginBottom: 8 }}>Investor Newsletter Distribution</h1>
      <p style={{ color: '#666', marginBottom: 24 }}>
        Track investor newsletter sends & opens & clicks. Sentiment &lt;= per-investor signal.
      </p>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Recent Distributions</h2>
        <DataTable
          rows={distributions}
          columns={distColumns}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Recipient Segments</h2>
        <DataTable
          rows={segments}
          columns={segColumns}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Top Engaged Investors</h2>
        <DataTable
          rows={topInvestors}
          columns={topColumns}
          rowKey={(r: any, i: number) => String(r.investor_id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Sentiment Summary</h2>
        <DataTable
          rows={sentiments}
          columns={sentColumns}
          rowKey={(r: any, i: number) => String(r.sentiment ?? i)}
        />
      </section>
    </div>
  );
}
