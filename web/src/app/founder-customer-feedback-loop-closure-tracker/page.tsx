import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type SummaryRow = {
  total_feedback: number;
  open_count: number;
  closed_count: number;
  critical_open: number;
  avg_close_hours: number | null;
  median_close_hours: number | null;
  oldest_open_age_hours: number | null;
  unacknowledged_count: number;
};

type BacklogRow = {
  id: string;
  topic_tag: string;
  feedback_channel: string;
  sentiment: string;
  severity: string;
  submitter_role: string;
  feedback_summary: string;
  submitted_at: string;
  age_hours: number;
  acknowledged: boolean;
};

type ChannelRow = {
  feedback_channel: string;
  total: number;
  closed: number;
  open: number;
  closure_rate_pct: number | null;
  avg_close_hours: number | null;
};

type TopicRow = {
  topic_tag: string;
  total: number;
  open_count: number;
  negative_count: number;
  avg_close_hours: number | null;
};

type WeeklyRow = {
  week_start: string;
  total_in: number;
  total_closed: number;
  avg_close_hours: number | null;
};

type ClosureRow = {
  id: string;
  topic_tag: string;
  feedback_channel: string;
  severity: string;
  closure_response: string | null;
  loop_closed_at: string;
  close_hours: number;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [summaryRes, backlogRes, channelRes, topicRes, weeklyRes, closureRes] = await Promise.all([
    supabase.rpc('founder_r2324_feedback_summary'),
    supabase.rpc('founder_r2324_open_backlog'),
    supabase.rpc('founder_r2324_closure_by_channel'),
    supabase.rpc('founder_r2324_topic_breakdown'),
    supabase.rpc('founder_r2324_weekly_trend'),
    supabase.rpc('founder_r2324_recent_closures'),
  ]);

  const summary: SummaryRow | null = (summaryRes.data?.[0] as SummaryRow) ?? null;
  const backlog: BacklogRow[] = (backlogRes.data as BacklogRow[]) ?? [];
  const channels: ChannelRow[] = (channelRes.data as ChannelRow[]) ?? [];
  const topics: TopicRow[] = (topicRes.data as TopicRow[]) ?? [];
  const weekly: WeeklyRow[] = (weeklyRes.data as WeeklyRow[]) ?? [];
  const closures: ClosureRow[] = (closureRes.data as ClosureRow[]) ?? [];

  const backlogCols: Column<BacklogRow>[] = [
    { key: 'severity', header: 'Sev', render: (r: BacklogRow) => <span className={r.severity === 'urgent' ? 'text-red-600 font-semibold' : r.severity === 'high' ? 'text-orange-600' : ''}>{r.severity}</span> },
    { key: 'topic_tag', header: 'Topic', render: (r: BacklogRow) => r.topic_tag },
    { key: 'feedback_channel', header: 'Channel', render: (r: BacklogRow) => r.feedback_channel },
    { key: 'sentiment', header: 'Sentiment', render: (r: BacklogRow) => r.sentiment },
    { key: 'submitter_role', header: 'Role', render: (r: BacklogRow) => r.submitter_role },
    { key: 'feedback_summary', header: 'Summary', render: (r: BacklogRow) => <span className="text-xs">{r.feedback_summary?.slice(0, 80)}</span> },
    { key: 'age_hours', header: 'Age (h)', render: (r: BacklogRow) => <span className={r.age_hours > 72 ? 'text-red-600 font-semibold' : ''}>{r.age_hours}</span> },
    { key: 'acknowledged', header: 'Ack?', render: (r: BacklogRow) => r.acknowledged ? 'yes' : 'no' },
  ];

  const channelCols: Column<ChannelRow>[] = [
    { key: 'feedback_channel', header: 'Channel', render: (r: ChannelRow) => r.feedback_channel },
    { key: 'total', header: 'Total', render: (r: ChannelRow) => r.total },
    { key: 'closed', header: 'Closed', render: (r: ChannelRow) => r.closed },
    { key: 'open', header: 'Open', render: (r: ChannelRow) => r.open },
    { key: 'closure_rate_pct', header: 'Close %', render: (r: ChannelRow) => r.closure_rate_pct ?? '—' },
    { key: 'avg_close_hours', header: 'Avg close (h)', render: (r: ChannelRow) => r.avg_close_hours ?? '—' },
  ];

  const topicCols: Column<TopicRow>[] = [
    { key: 'topic_tag', header: 'Topic', render: (r: TopicRow) => r.topic_tag },
    { key: 'total', header: 'Total', render: (r: TopicRow) => r.total },
    { key: 'open_count', header: 'Open', render: (r: TopicRow) => r.open_count },
    { key: 'negative_count', header: 'Negative/Critical', render: (r: TopicRow) => r.negative_count },
    { key: 'avg_close_hours', header: 'Avg close (h)', render: (r: TopicRow) => r.avg_close_hours ?? '—' },
  ];

  const weeklyCols: Column<WeeklyRow>[] = [
    { key: 'week_start', header: 'Week', render: (r: WeeklyRow) => r.week_start },
    { key: 'total_in', header: 'Incoming', render: (r: WeeklyRow) => r.total_in },
    { key: 'total_closed', header: 'Closed', render: (r: WeeklyRow) => r.total_closed },
    { key: 'avg_close_hours', header: 'Avg close (h)', render: (r: WeeklyRow) => r.avg_close_hours ?? '—' },
  ];

  const closureCols: Column<ClosureRow>[] = [
    { key: 'topic_tag', header: 'Topic', render: (r: ClosureRow) => r.topic_tag },
    { key: 'feedback_channel', header: 'Channel', render: (r: ClosureRow) => r.feedback_channel },
    { key: 'severity', header: 'Sev', render: (r: ClosureRow) => r.severity },
    { key: 'closure_response', header: 'Response', render: (r: ClosureRow) => <span className="text-xs">{r.closure_response?.slice(0, 100) ?? '—'}</span> },
    { key: 'close_hours', header: 'Closed in (h)', render: (r: ClosureRow) => r.close_hours },
    { key: 'loop_closed_at', header: 'Closed at', render: (r: ClosureRow) => new Date(r.loop_closed_at).toLocaleString() },
  ];

  return (
    <div className="p-6 space-y-6">
      <header>
        <h1 className="text-2xl font-bold">Customer Feedback-Loop Closure Tracker</h1>
        <p className="text-sm text-gray-600">Did we close the loop? Avg close time & open backlog by channel, topic & severity.</p>
      </header>

      <section className="grid grid-cols-2 md:grid-cols-4 gap-4">
        <div className="p-4 bg-white rounded-lg shadow border">
          <div className="text-xs text-gray-500">Total feedback</div>
          <div className="text-2xl font-bold">{summary?.total_feedback ?? 0}</div>
        </div>
        <div className="p-4 bg-white rounded-lg shadow border">
          <div className="text-xs text-gray-500">Open backlog</div>
          <div className="text-2xl font-bold text-orange-600">{summary?.open_count ?? 0}</div>
        </div>
        <div className="p-4 bg-white rounded-lg shadow border">
          <div className="text-xs text-gray-500">Critical open (high/urgent)</div>
          <div className="text-2xl font-bold text-red-600">{summary?.critical_open ?? 0}</div>
        </div>
        <div className="p-4 bg-white rounded-lg shadow border">
          <div className="text-xs text-gray-500">Unacknowledged open</div>
          <div className="text-2xl font-bold">{summary?.unacknowledged_count ?? 0}</div>
        </div>
        <div className="p-4 bg-white rounded-lg shadow border">
          <div className="text-xs text-gray-500">Avg close (hours)</div>
          <div className="text-2xl font-bold">{summary?.avg_close_hours ?? '—'}</div>
        </div>
        <div className="p-4 bg-white rounded-lg shadow border">
          <div className="text-xs text-gray-500">Median close (hours)</div>
          <div className="text-2xl font-bold">{summary?.median_close_hours ?? '—'}</div>
        </div>
        <div className="p-4 bg-white rounded-lg shadow border">
          <div className="text-xs text-gray-500">Oldest open age (hours)</div>
          <div className="text-2xl font-bold">{summary?.oldest_open_age_hours ?? '—'}</div>
        </div>
        <div className="p-4 bg-white rounded-lg shadow border">
          <div className="text-xs text-gray-500">Closed (lifetime)</div>
          <div className="text-2xl font-bold text-green-700">{summary?.closed_count ?? 0}</div>
        </div>
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Open backlog (priority order)</h2>
        <DataTable
          columns={backlogCols}
          rows={backlog}
          rowKey={(r: BacklogRow) => r.id}
          emptyMessage="No open feedback — loop fully closed."
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Closure rate by channel</h2>
        <DataTable
          columns={channelCols}
          rows={channels}
          rowKey={(r: ChannelRow) => r.feedback_channel}
          emptyMessage="No channel data yet."
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Topic breakdown (top 50)</h2>
        <DataTable
          columns={topicCols}
          rows={topics}
          rowKey={(r: TopicRow) => r.topic_tag}
          emptyMessage="No topics tagged yet."
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Weekly trend (last 12 weeks)</h2>
        <DataTable
          columns={weeklyCols}
          rows={weekly}
          rowKey={(r: WeeklyRow) => r.week_start}
          emptyMessage="No weekly data yet."
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Recent closures (last 50)</h2>
        <DataTable
          columns={closureCols}
          rows={closures}
          rowKey={(r: ClosureRow) => r.id}
          emptyMessage="No closures yet."
        />
      </section>
    </div>
  );
}
