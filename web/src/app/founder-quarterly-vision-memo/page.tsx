import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type MemoRow = {
  id: string;
  quarter: string;
  headline: string;
  status: string;
  published_at: string | null;
  feedback_count: number;
  created_at: string;
};

type SummaryRow = {
  memo_id: string;
  quarter: string;
  headline: string;
  status: string;
  total_feedback: number;
  positive_count: number;
  neutral_count: number;
  negative_count: number;
};

type FeedbackRow = {
  id: string;
  memo_id: string;
  reviewer_email: string;
  feedback_md: string;
  sentiment: string;
  submitted_at: string;
};

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [memosRes, summaryRes, feedbackRes] = await Promise.all([
    sb.rpc('r1682_list_memos'),
    sb.rpc('r1682_feedback_summary_per_memo'),
    sb.rpc('r1682_list_feedback', { p_memo_id: null }),
  ]);

  const memos: MemoRow[] = (memosRes.data as MemoRow[]) ?? [];
  const summary: SummaryRow[] = (summaryRes.data as SummaryRow[]) ?? [];
  const feedback: FeedbackRow[] = (feedbackRes.data as FeedbackRow[]) ?? [];

  const totalMemos = memos.length;
  const publishedMemos = memos.filter((m) => m.status === 'published').length;
  const draftMemos = memos.filter((m) => m.status === 'draft').length;
  const totalFeedback = feedback.length;
  const positiveFeedback = feedback.filter((f) => f.sentiment === 'positive').length;
  const negativeFeedback = feedback.filter((f) => f.sentiment === 'negative').length;

  const memoCols: Column<MemoRow>[] = [
    { key: 'quarter', header: 'Quarter', render: (r: any) => <span className="font-mono">{r.quarter}</span> },
    { key: 'headline', header: 'Headline', render: (r: any) => <span>{r.headline}</span> },
    { key: 'status', header: 'Status', render: (r: any) => <span className="uppercase text-xs">{r.status}</span> },
    {
      key: 'published_at',
      header: 'Published',
      render: (r: any) => <span>{r.published_at ? new Date(r.published_at).toLocaleDateString() : '—'}</span>,
    },
    { key: 'feedback_count', header: 'Feedback', render: (r: any) => <span>{r.feedback_count}</span> },
    {
      key: 'created_at',
      header: 'Created',
      render: (r: any) => <span>{new Date(r.created_at).toLocaleDateString()}</span>,
    },
  ];

  const summaryCols: Column<SummaryRow>[] = [
    { key: 'quarter', header: 'Quarter', render: (r: any) => <span className="font-mono">{r.quarter}</span> },
    { key: 'headline', header: 'Headline', render: (r: any) => <span>{r.headline}</span> },
    { key: 'status', header: 'Status', render: (r: any) => <span className="uppercase text-xs">{r.status}</span> },
    { key: 'total_feedback', header: 'Total', render: (r: any) => <span>{r.total_feedback}</span> },
    { key: 'positive_count', header: 'Positive', render: (r: any) => <span className="text-green-700">{r.positive_count}</span> },
    { key: 'neutral_count', header: 'Neutral', render: (r: any) => <span>{r.neutral_count}</span> },
    { key: 'negative_count', header: 'Negative', render: (r: any) => <span className="text-red-700">{r.negative_count}</span> },
  ];

  const actionQueue = memos.filter((m) => m.status === 'draft' || (m.status === 'published' && m.feedback_count === 0));
  const actionCols: Column<MemoRow>[] = [
    { key: 'quarter', header: 'Quarter', render: (r: any) => <span className="font-mono">{r.quarter}</span> },
    { key: 'headline', header: 'Headline', render: (r: any) => <span>{r.headline}</span> },
    { key: 'status', header: 'Status', render: (r: any) => <span className="uppercase text-xs">{r.status}</span> },
    {
      key: 'action',
      header: 'Next Action',
      render: (r: any) => (
        <span className="text-xs">
          {r.status === 'draft' ? 'Publish memo' : 'Solicit reviewer feedback'}
        </span>
      ),
    },
  ];

  return (
    <main className="p-6 space-y-8">
      <header>
        <h1 className="text-2xl font-bold">Founder Quarterly Vision Memo</h1>
        <p className="text-sm text-gray-600">Draft, publish, and track feedback on the quarterly vision memo.</p>
      </header>

      <section>
        <h2 className="text-lg font-semibold mb-3">KPIs</h2>
        <div className="grid grid-cols-2 md:grid-cols-6 gap-3">
          <div className="border rounded p-3">
            <div className="text-xs text-gray-500">Total Memos</div>
            <div className="text-2xl font-semibold">{totalMemos}</div>
          </div>
          <div className="border rounded p-3">
            <div className="text-xs text-gray-500">Published</div>
            <div className="text-2xl font-semibold">{publishedMemos}</div>
          </div>
          <div className="border rounded p-3">
            <div className="text-xs text-gray-500">Drafts</div>
            <div className="text-2xl font-semibold">{draftMemos}</div>
          </div>
          <div className="border rounded p-3">
            <div className="text-xs text-gray-500">Feedback Items</div>
            <div className="text-2xl font-semibold">{totalFeedback}</div>
          </div>
          <div className="border rounded p-3">
            <div className="text-xs text-gray-500">Positive</div>
            <div className="text-2xl font-semibold text-green-700">{positiveFeedback}</div>
          </div>
          <div className="border rounded p-3">
            <div className="text-xs text-gray-500">Negative</div>
            <div className="text-2xl font-semibold text-red-700">{negativeFeedback}</div>
          </div>
        </div>
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-3">Memos</h2>
        <DataTable
          rows={memos}
          columns={memoCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-3">Feedback Summary Per Memo</h2>
        <DataTable
          rows={summary}
          columns={summaryCols}
          rowKey={(r: any, i: number) => String(r.memo_id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-3">Action Queue (drafts & memos awaiting feedback)</h2>
        <DataTable
          rows={actionQueue}
          columns={actionCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>
    </main>
  );
}
