import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function FounderWeeklyCustomerCallsLogPage() {
  const sb = await getSupabaseServerClient();

  const [callsRes, actionsRes, progressRes, sentimentRes] = await Promise.all([
    sb.rpc('fcc_r1710_list_calls', { p_limit: 200 }),
    sb.rpc('fcc_r1710_list_actions', { p_status: null, p_limit: 200 }),
    sb.rpc('fcc_r1710_weekly_target_progress', { p_weeks: 12 }),
    sb.rpc('fcc_r1710_sentiment_summary', { p_weeks: 4 }),
  ]);

  const calls: any[] = (callsRes.data as any[]) || [];
  const actions: any[] = (actionsRes.data as any[]) || [];
  const progress: any[] = (progressRes.data as any[]) || [];
  const sentiment: any[] = (sentimentRes.data as any[]) || [];

  const currentWeek = progress[0];
  const totalCalls = calls.length;
  const openActions = actions.filter((a) => a.status === 'open').length;
  const followUps = calls.filter((c) => c.follow_up_needed).length;

  const callColumns: Column<any>[] = [
    { key: 'call_date', header: 'Call Date', render: (r: any) => new Date(r.call_date).toLocaleDateString() },
    { key: 'hospital_name', header: 'Hospital', render: (r: any) => <span className="font-medium">{r.hospital_name}</span> },
    { key: 'hospital_city', header: 'City', render: (r: any) => r.hospital_city || '—' },
    { key: 'duration_minutes', header: 'Duration', render: (r: any) => `${r.duration_minutes} min` },
    { key: 'sentiment', header: 'Sentiment', render: (r: any) => <SentimentPill value={r.sentiment} /> },
    { key: 'follow_up_needed', header: 'Follow-up', render: (r: any) => (r.follow_up_needed ? <span className="text-amber-600 font-medium">Yes</span> : <span className="text-gray-400">No</span>) },
    { key: 'open_actions', header: 'Open Actions', render: (r: any) => <span className={r.open_actions > 0 ? 'font-semibold text-blue-600' : 'text-gray-500'}>{r.open_actions}</span> },
    { key: 'week_start', header: 'Week Of', render: (r: any) => r.week_start },
  ];

  const actionColumns: Column<any>[] = [
    { key: 'action_text', header: 'Action', render: (r: any) => <span className="text-sm">{r.action_text}</span> },
    { key: 'hospital_name', header: 'Hospital', render: (r: any) => r.hospital_name },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email || '—' },
    { key: 'due_date', header: 'Due', render: (r: any) => r.due_date || '—' },
    { key: 'status', header: 'Status', render: (r: any) => <StatusPill value={r.status} /> },
    { key: 'done_at', header: 'Done', render: (r: any) => (r.done_at ? new Date(r.done_at).toLocaleDateString() : '—') },
  ];

  const progressColumns: Column<any>[] = [
    { key: 'week_start', header: 'Week', render: (r: any) => r.week_start },
    { key: 'calls_logged', header: 'Calls', render: (r: any) => <span className="font-semibold">{r.calls_logged}</span> },
    { key: 'target', header: 'Target', render: (r: any) => r.target },
    { key: 'on_target', header: 'On Target', render: (r: any) => (r.on_target ? <span className="text-green-600 font-medium">Yes</span> : <span className="text-red-600 font-medium">Missed</span>) },
    { key: 'unique_hospitals', header: 'Unique Hospitals', render: (r: any) => r.unique_hospitals },
    { key: 'avg_duration_minutes', header: 'Avg Duration', render: (r: any) => `${r.avg_duration_minutes} min` },
  ];

  const sentimentColumns: Column<any>[] = [
    { key: 'sentiment', header: 'Sentiment', render: (r: any) => <SentimentPill value={r.sentiment} /> },
    { key: 'call_count', header: 'Calls', render: (r: any) => <span className="font-semibold">{r.call_count}</span> },
    { key: 'pct_of_total', header: 'Pct', render: (r: any) => `${r.pct_of_total}%` },
    { key: 'hospitals_count', header: 'Unique Hospitals', render: (r: any) => r.hospitals_count },
  ];

  return (
    <div className="mx-auto max-w-7xl p-6 space-y-8">
      <header>
        <h1 className="text-2xl font-bold">Founder Weekly Customer Calls Log</h1>
        <p className="text-sm text-gray-600 mt-1">
          Founder discipline tracker. Target: 5 customer calls per week minimum. Track sentiment, capture quotes, drive action items.
        </p>
      </header>

      <section className="grid grid-cols-2 md:grid-cols-4 gap-4">
        <Kpi label="This Week" value={currentWeek ? `${currentWeek.calls_logged} / 5` : '0 / 5'} sub={currentWeek?.on_target ? 'On target' : 'Below target'} />
        <Kpi label="Total Calls Logged" value={String(totalCalls)} sub="all time" />
        <Kpi label="Open Action Items" value={String(openActions)} sub="follow-up needed" />
        <Kpi label="Flagged Follow-ups" value={String(followUps)} sub="calls marked" />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-3">Weekly Target Progress (last 12 weeks)</h2>
        <DataTable rows={progress} columns={progressColumns} rowKey={(r: any, i: number) => String(r.week_start ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-3">Sentiment Summary (last 4 weeks)</h2>
        <DataTable rows={sentiment} columns={sentimentColumns} rowKey={(r: any, i: number) => String(r.sentiment ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-3">Call Log</h2>
        <p className="text-xs text-gray-500 mb-2">
          Sentiment values: very_positive &gt; positive &gt; neutral &gt; negative &gt; concerned. Mark follow-up needed when action items are open.
        </p>
        <DataTable rows={calls} columns={callColumns} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-3">Action Items</h2>
        <p className="text-xs text-gray-500 mb-2">
          Open items first, sorted by due date. Status flows: open → done or open → dropped.
        </p>
        <DataTable rows={actions} columns={actionColumns} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>
    </div>
  );
}

function Kpi({ label, value, sub }: { label: string; value: string; sub?: string }) {
  return (
    <div className="rounded-lg border bg-white p-4">
      <div className="text-xs uppercase tracking-wide text-gray-500">{label}</div>
      <div className="mt-1 text-2xl font-bold">{value}</div>
      {sub ? <div className="mt-1 text-xs text-gray-500">{sub}</div> : null}
    </div>
  );
}

function SentimentPill({ value }: { value: string }) {
  const map: Record<string, string> = {
    very_positive: 'bg-green-100 text-green-800',
    positive: 'bg-emerald-100 text-emerald-800',
    neutral: 'bg-gray-100 text-gray-700',
    negative: 'bg-orange-100 text-orange-800',
    concerned: 'bg-red-100 text-red-800',
  };
  const cls = map[value] || 'bg-gray-100 text-gray-700';
  return <span className={`inline-block rounded-full px-2 py-0.5 text-xs font-medium ${cls}`}>{value}</span>;
}

function StatusPill({ value }: { value: string }) {
  const map: Record<string, string> = {
    open: 'bg-blue-100 text-blue-800',
    done: 'bg-green-100 text-green-800',
    dropped: 'bg-gray-200 text-gray-600',
  };
  const cls = map[value] || 'bg-gray-100 text-gray-700';
  return <span className={`inline-block rounded-full px-2 py-0.5 text-xs font-medium ${cls}`}>{value}</span>;
}
