import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function FounderInvestorNewsletterTrackerPage() {
  const sb = await getSupabaseServerClient();

  const [newslettersRes, summaryRes, topRes, trendRes, reactionsRes] = await Promise.all([
    sb.rpc('list_newsletters_r1689'),
    sb.rpc('open_rate_summary_r1689'),
    sb.rpc('top_engaged_investors_r1689'),
    sb.rpc('newsletter_trend_r1689'),
    sb.rpc('list_reactions_r1689', { p_newsletter_id: null }),
  ]);

  const newsletters: any[] = (newslettersRes.data as any[]) || [];
  const summary: any = (summaryRes.data as any[])?.[0] || {};
  const topInvestors: any[] = (topRes.data as any[]) || [];
  const trend: any[] = (trendRes.data as any[]) || [];
  const reactions: any[] = (reactionsRes.data as any[]) || [];

  const newsletterCols: Column<any>[] = [
    { key: 'sent_at', header: 'Sent', render: (r: any) => new Date(r.sent_at).toLocaleString() },
    { key: 'subject', header: 'Subject', render: (r: any) => <span className="font-medium">{r.subject}</span> },
    { key: 'recipients_count', header: 'Recipients', render: (r: any) => r.recipients_count },
    { key: 'opens_count', header: 'Opens', render: (r: any) => r.opens_count },
    { key: 'clicks_count', header: 'Clicks', render: (r: any) => r.clicks_count },
    { key: 'replies_count', header: 'Replies', render: (r: any) => r.replies_count },
    {
      key: 'open_rate_pct',
      header: 'Open Rate',
      render: (r: any) => (
        <span className={Number(r.open_rate_pct) >= 40 ? 'text-green-700 font-semibold' : 'text-gray-700'}>
          {r.open_rate_pct}%
        </span>
      ),
    },
    { key: 'click_rate_pct', header: 'Click Rate', render: (r: any) => `${r.click_rate_pct}%` },
  ];

  const topInvestorCols: Column<any>[] = [
    { key: 'investor_id', header: 'Investor', render: (r: any) => <code className="text-xs">{String(r.investor_id).slice(0, 8)}</code> },
    { key: 'total_reactions', header: 'Total', render: (r: any) => <span className="font-semibold">{r.total_reactions}</span> },
    { key: 'opens', header: 'Opens', render: (r: any) => r.opens },
    { key: 'clicks', header: 'Clicks', render: (r: any) => r.clicks },
    { key: 'replies', header: 'Replies', render: (r: any) => <span className="text-blue-700 font-medium">{r.replies}</span> },
    { key: 'last_reaction_at', header: 'Last Active', render: (r: any) => r.last_reaction_at ? new Date(r.last_reaction_at).toLocaleDateString() : '—' },
  ];

  const trendCols: Column<any>[] = [
    { key: 'week_start', header: 'Week', render: (r: any) => new Date(r.week_start).toLocaleDateString() },
    { key: 'newsletters_sent', header: 'Sent', render: (r: any) => r.newsletters_sent },
    { key: 'recipients', header: 'Recipients', render: (r: any) => r.recipients },
    { key: 'opens', header: 'Opens', render: (r: any) => r.opens },
    { key: 'clicks', header: 'Clicks', render: (r: any) => r.clicks },
    { key: 'replies', header: 'Replies', render: (r: any) => r.replies },
    { key: 'open_rate_pct', header: 'Open Rate', render: (r: any) => `${r.open_rate_pct}%` },
  ];

  const reactionCols: Column<any>[] = [
    { key: 'reaction_at', header: 'When', render: (r: any) => new Date(r.reaction_at).toLocaleString() },
    { key: 'newsletter_subject', header: 'Newsletter', render: (r: any) => r.newsletter_subject },
    { key: 'investor_id', header: 'Investor', render: (r: any) => <code className="text-xs">{String(r.investor_id).slice(0, 8)}</code> },
    {
      key: 'reaction_type',
      header: 'Type',
      render: (r: any) => {
        const colorMap: Record<string, string> = {
          open: 'bg-blue-100 text-blue-800',
          click: 'bg-green-100 text-green-800',
          reply: 'bg-purple-100 text-purple-800',
          unsubscribe: 'bg-red-100 text-red-800',
        };
        return (
          <span className={`px-2 py-0.5 rounded text-xs font-medium ${colorMap[r.reaction_type] || 'bg-gray-100'}`}>
            {r.reaction_type}
          </span>
        );
      },
    },
    { key: 'click_url', header: 'URL', render: (r: any) => r.click_url ? <a href={r.click_url} className="text-blue-600 text-xs underline truncate max-w-xs inline-block" target="_blank" rel="noreferrer">{r.click_url}</a> : '—' },
  ];

  const actionQueue = newsletters.filter((n: any) => Number(n.open_rate_pct) < 20).slice(0, 10);

  return (
    <main className="min-h-screen bg-gray-50 p-6">
      <div className="max-w-7xl mx-auto space-y-6">
        <header className="border-b pb-4">
          <h1 className="text-3xl font-bold text-gray-900">Investor Newsletter Tracker</h1>
          <p className="text-sm text-gray-600 mt-1">
            Sent newsletters, open/click stats, top engaged investors. Strong opens (&gt;40%) flagged green.
          </p>
        </header>

        {/* KPI section */}
        <section className="grid grid-cols-2 md:grid-cols-4 gap-4">
          <div className="bg-white rounded-lg shadow p-4">
            <div className="text-xs text-gray-500 uppercase">Newsletters</div>
            <div className="text-2xl font-bold mt-1">{summary.total_newsletters ?? 0}</div>
          </div>
          <div className="bg-white rounded-lg shadow p-4">
            <div className="text-xs text-gray-500 uppercase">Total Recipients</div>
            <div className="text-2xl font-bold mt-1">{summary.total_recipients ?? 0}</div>
          </div>
          <div className="bg-white rounded-lg shadow p-4">
            <div className="text-xs text-gray-500 uppercase">Avg Open Rate</div>
            <div className="text-2xl font-bold mt-1 text-blue-700">{summary.avg_open_rate_pct ?? 0}%</div>
          </div>
          <div className="bg-white rounded-lg shadow p-4">
            <div className="text-xs text-gray-500 uppercase">Avg Click Rate</div>
            <div className="text-2xl font-bold mt-1 text-green-700">{summary.avg_click_rate_pct ?? 0}%</div>
          </div>
          <div className="bg-white rounded-lg shadow p-4">
            <div className="text-xs text-gray-500 uppercase">Total Opens</div>
            <div className="text-2xl font-bold mt-1">{summary.total_opens ?? 0}</div>
          </div>
          <div className="bg-white rounded-lg shadow p-4">
            <div className="text-xs text-gray-500 uppercase">Total Clicks</div>
            <div className="text-2xl font-bold mt-1">{summary.total_clicks ?? 0}</div>
          </div>
          <div className="bg-white rounded-lg shadow p-4">
            <div className="text-xs text-gray-500 uppercase">Total Replies</div>
            <div className="text-2xl font-bold mt-1 text-purple-700">{summary.total_replies ?? 0}</div>
          </div>
          <div className="bg-white rounded-lg shadow p-4">
            <div className="text-xs text-gray-500 uppercase">Avg Reply Rate</div>
            <div className="text-2xl font-bold mt-1">{summary.avg_reply_rate_pct ?? 0}%</div>
          </div>
        </section>

        {/* Primary table: newsletters */}
        <section className="bg-white rounded-lg shadow p-4">
          <h2 className="text-xl font-semibold mb-3">Newsletters Sent</h2>
          <DataTable rows={newsletters} columns={newsletterCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
        </section>

        {/* Action queue: low-open newsletters */}
        <section className="bg-white rounded-lg shadow p-4 border-l-4 border-orange-400">
          <h2 className="text-xl font-semibold mb-3">Action Queue — Low Open Rate (&lt;20%)</h2>
          <p className="text-sm text-gray-600 mb-3">
            These newsletters underperformed. Consider follow-up, subject-line A/B test, or list hygiene.
          </p>
          <DataTable rows={actionQueue} columns={newsletterCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
        </section>

        {/* Top engaged investors */}
        <section className="bg-white rounded-lg shadow p-4">
          <h2 className="text-xl font-semibold mb-3">Top Engaged Investors</h2>
          <DataTable rows={topInvestors} columns={topInvestorCols} rowKey={(r: any, i: number) => String(r.investor_id ?? i)} />
        </section>

        {/* Weekly trend */}
        <section className="bg-white rounded-lg shadow p-4">
          <h2 className="text-xl font-semibold mb-3">Weekly Trend (last 26 weeks)</h2>
          <DataTable rows={trend} columns={trendCols} rowKey={(r: any, i: number) => String(r.week_start ?? i)} />
        </section>

        {/* Recent reactions */}
        <section className="bg-white rounded-lg shadow p-4">
          <h2 className="text-xl font-semibold mb-3">Recent Reactions</h2>
          <DataTable rows={reactions.slice(0, 50)} columns={reactionCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
        </section>
      </div>
    </main>
  );
}
