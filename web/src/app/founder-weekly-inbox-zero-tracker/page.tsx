import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type WeeklySummary = {
  week_start: string;
  received_count: number;
  replied_count: number;
  deferred_count: number;
  unread_count: number;
  reply_rate_pct: number | null;
  oldest_unread_hours: number | null;
  avg_reply_latency_minutes: number | null;
};

type LatencyByCategory = {
  category: string;
  total_emails: number;
  replied_emails: number;
  avg_latency_minutes: number | null;
  median_latency_minutes: number | null;
  max_latency_minutes: number | null;
};

type OldestUnread = {
  id: string;
  sender_email: string;
  subject: string;
  category: string;
  priority: string;
  received_at: string;
  age_hours: number;
  needs_action: boolean;
};

type DeferredItem = {
  id: string;
  sender_email: string;
  subject: string;
  category: string;
  deferred_until: string;
  days_until_due: number;
  notes: string | null;
};

type SnapshotTrend = {
  week_start: string;
  received_count: number;
  replied_count: number;
  unread_count: number;
  oldest_unread_hours: number | null;
  avg_reply_latency_minutes: number | null;
  inbox_zero_achieved: boolean;
};

type PriorityRow = {
  priority: string;
  total_count: number;
  replied_count: number;
  unread_count: number;
  avg_latency_minutes: number | null;
};

type Scorecard = {
  metric: string;
  value: number | null;
  detail: string;
};

export default async function FounderWeeklyInboxZeroTrackerPage() {
  const supabase = await getSupabaseServerClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();
  const email = user?.email ?? null;

  const [
    weeklyRes,
    latencyRes,
    oldestRes,
    deferredRes,
    trendRes,
    priorityRes,
    scoreRes,
  ] = await Promise.all([
    supabase.rpc('wiz_r2389_weekly_summary'),
    supabase.rpc('wiz_r2389_latency_by_category'),
    supabase.rpc('wiz_r2389_oldest_unread'),
    supabase.rpc('wiz_r2389_deferred_queue'),
    supabase.rpc('wiz_r2389_snapshot_trend'),
    supabase.rpc('wiz_r2389_priority_breakdown'),
    supabase.rpc('wiz_r2389_current_scorecard'),
  ]);

  const weekly = (weeklyRes.data ?? []) as WeeklySummary[];
  const latency = (latencyRes.data ?? []) as LatencyByCategory[];
  const oldest = (oldestRes.data ?? []) as OldestUnread[];
  const deferred = (deferredRes.data ?? []) as DeferredItem[];
  const trend = (trendRes.data ?? []) as SnapshotTrend[];
  const priority = (priorityRes.data ?? []) as PriorityRow[];
  const scorecard = (scoreRes.data ?? []) as Scorecard[];

  const weeklyCols: Column<WeeklySummary>[] = [
    { key: 'week', header: 'Week start', render: (r) => r.week_start },
    { key: 'rcv', header: 'Received', render: (r) => r.received_count },
    { key: 'rep', header: 'Replied', render: (r) => r.replied_count },
    { key: 'def', header: 'Deferred', render: (r) => r.deferred_count },
    { key: 'unr', header: 'Unread', render: (r) => r.unread_count },
    { key: 'rate', header: 'Reply rate %', render: (r) => r.reply_rate_pct ?? '-' },
    { key: 'old', header: 'Oldest unread (h)', render: (r) => r.oldest_unread_hours ?? '-' },
    { key: 'lat', header: 'Avg latency (min)', render: (r) => r.avg_reply_latency_minutes ?? '-' },
  ];

  const latencyCols: Column<LatencyByCategory>[] = [
    { key: 'cat', header: 'Category', render: (r) => r.category },
    { key: 'tot', header: 'Total', render: (r) => r.total_emails },
    { key: 'rep', header: 'Replied', render: (r) => r.replied_emails },
    { key: 'avg', header: 'Avg latency (min)', render: (r) => r.avg_latency_minutes ?? '-' },
    { key: 'med', header: 'Median (min)', render: (r) => r.median_latency_minutes ?? '-' },
    { key: 'max', header: 'Max (min)', render: (r) => r.max_latency_minutes ?? '-' },
  ];

  const oldestCols: Column<OldestUnread>[] = [
    { key: 'sub', header: 'Subject', render: (r) => r.subject },
    { key: 'snd', header: 'Sender', render: (r) => r.sender_email },
    { key: 'cat', header: 'Category', render: (r) => r.category },
    { key: 'pri', header: 'Priority', render: (r) => r.priority },
    { key: 'age', header: 'Age (h)', render: (r) => r.age_hours },
    { key: 'act', header: 'Needs action', render: (r) => (r.needs_action ? 'yes' : 'no') },
  ];

  const deferredCols: Column<DeferredItem>[] = [
    { key: 'sub', header: 'Subject', render: (r) => r.subject },
    { key: 'snd', header: 'Sender', render: (r) => r.sender_email },
    { key: 'cat', header: 'Category', render: (r) => r.category },
    { key: 'due', header: 'Due', render: (r) => r.deferred_until },
    { key: 'days', header: 'Days until due', render: (r) => r.days_until_due },
    { key: 'nts', header: 'Notes', render: (r) => r.notes ?? '-' },
  ];

  const trendCols: Column<SnapshotTrend>[] = [
    { key: 'wk', header: 'Week', render: (r) => r.week_start },
    { key: 'rcv', header: 'Received', render: (r) => r.received_count },
    { key: 'rep', header: 'Replied', render: (r) => r.replied_count },
    { key: 'unr', header: 'Unread', render: (r) => r.unread_count },
    { key: 'old', header: 'Oldest (h)', render: (r) => r.oldest_unread_hours ?? '-' },
    { key: 'lat', header: 'Avg latency (min)', render: (r) => r.avg_reply_latency_minutes ?? '-' },
    { key: 'iz', header: 'Inbox-zero', render: (r) => (r.inbox_zero_achieved ? 'yes' : 'no') },
  ];

  const priorityCols: Column<PriorityRow>[] = [
    { key: 'pri', header: 'Priority', render: (r) => r.priority },
    { key: 'tot', header: 'Total', render: (r) => r.total_count },
    { key: 'rep', header: 'Replied', render: (r) => r.replied_count },
    { key: 'unr', header: 'Unread', render: (r) => r.unread_count },
    { key: 'lat', header: 'Avg latency (min)', render: (r) => r.avg_latency_minutes ?? '-' },
  ];

  const scoreCols: Column<Scorecard>[] = [
    { key: 'm', header: 'Metric', render: (r) => r.metric },
    { key: 'v', header: 'Value', render: (r) => r.value ?? '-' },
    { key: 'd', header: 'Detail', render: (r) => r.detail },
  ];

  return (
    <div className="p-6 space-y-6">
      <header>
        <h1 className="text-2xl font-semibold">Weekly inbox-zero tracker</h1>
        <p className="text-sm text-[var(--color-muted)]">
          Track emails received vs replied vs deferred. Watch oldest unread age &amp; reply latency by category.
          Goal =&gt; clear weekly backlog and keep urgent replies &lt;= 4 hours.
        </p>
        <p className="text-xs text-[var(--color-muted)]">Signed in as {email ?? 'anonymous'}</p>
      </header>

      <section className="space-y-2">
        <h2 className="text-lg font-medium">Current week scorecard</h2>
        <DataTable<Scorecard>
          columns={scoreCols}
          rows={scorecard}
          emptyMessage="No scorecard data."
          rowKey={(r, i) => `${r.metric}-${i}`}
        />
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-medium">Weekly summary (last 12 weeks)</h2>
        <DataTable<WeeklySummary>
          columns={weeklyCols}
          rows={weekly}
          emptyMessage="No weeks logged yet."
          rowKey={(r) => r.week_start}
        />
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-medium">Reply latency by category</h2>
        <DataTable<LatencyByCategory>
          columns={latencyCols}
          rows={latency}
          emptyMessage="No category data."
          rowKey={(r) => r.category}
        />
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-medium">Oldest unread (top 25)</h2>
        <DataTable<OldestUnread>
          columns={oldestCols}
          rows={oldest}
          emptyMessage="Inbox-zero achieved => no unread."
          rowKey={(r) => r.id}
        />
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-medium">Deferred queue (snoozed for later)</h2>
        <DataTable<DeferredItem>
          columns={deferredCols}
          rows={deferred}
          emptyMessage="Nothing deferred."
          rowKey={(r) => r.id}
        />
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-medium">Snapshot trend (week-over-week)</h2>
        <DataTable<SnapshotTrend>
          columns={trendCols}
          rows={trend}
          emptyMessage="No snapshots stored yet."
          rowKey={(r) => r.week_start}
        />
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-medium">Priority breakdown</h2>
        <DataTable<PriorityRow>
          columns={priorityCols}
          rows={priority}
          emptyMessage="No priority data."
          rowKey={(r) => r.priority}
        />
      </section>
    </div>
  );
}
