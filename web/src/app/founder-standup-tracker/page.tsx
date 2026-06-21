import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type Entry = {
  id: string;
  entry_date: string;
  yesterday_md: string;
  today_md: string;
  blockers_md: string;
  mood: string | null;
  energy_score: number | null;
  open_blocker_count: number;
  created_at: string;
};

type MoodPoint = {
  entry_date: string;
  mood: string | null;
  energy_score: number | null;
  rolling_avg_energy: number | null;
};

type OpenBlocker = {
  id: string;
  entry_id: string;
  entry_date: string;
  blocker_text: string;
  owner_email: string | null;
  due_date: string | null;
  status: string;
  days_open: number;
  created_at: string;
};

export default async function FounderStandupTrackerPage() {
  const sb = await getSupabaseServerClient();

  const [entriesRes, moodRes, blockersRes] = await Promise.all([
    sb.rpc('r1666_list_entries'),
    sb.rpc('r1666_mood_trend'),
    sb.rpc('r1666_open_blockers_list'),
  ]);

  const entries: Entry[] = (entriesRes.data as Entry[] | null) ?? [];
  const moodTrend: MoodPoint[] = (moodRes.data as MoodPoint[] | null) ?? [];
  const openBlockers: OpenBlocker[] = (blockersRes.data as OpenBlocker[] | null) ?? [];

  const totalEntries = entries.length;
  const last7 = entries.slice(0, 7);
  const avgEnergy7 =
    last7.filter((e) => e.energy_score != null).length === 0
      ? 0
      : last7
          .filter((e) => e.energy_score != null)
          .reduce((acc, e) => acc + (e.energy_score ?? 0), 0) /
        last7.filter((e) => e.energy_score != null).length;
  const totalOpenBlockers = openBlockers.length;
  const overdueBlockers = openBlockers.filter(
    (b) => b.due_date != null && new Date(b.due_date) < new Date()
  ).length;
  const oldestBlockerDays =
    openBlockers.length === 0
      ? 0
      : Math.max(...openBlockers.map((b) => b.days_open));

  const entryColumns: Column<Entry>[] = [
    { key: 'entry_date', header: 'Date', render: (r) => <span className="font-mono text-sm">{r.entry_date}</span> },
    {
      key: 'mood',
      header: 'Mood',
      render: (r) => (
        <span
          className={
            'inline-block rounded px-2 py-0.5 text-xs font-medium ' +
            (r.mood === 'great'
              ? 'bg-green-100 text-green-800'
              : r.mood === 'good'
              ? 'bg-emerald-100 text-emerald-700'
              : r.mood === 'ok'
              ? 'bg-amber-100 text-amber-800'
              : r.mood === 'low'
              ? 'bg-orange-100 text-orange-800'
              : r.mood === 'burned_out'
              ? 'bg-red-100 text-red-800'
              : 'bg-slate-100 text-slate-600')
          }
        >
          {r.mood ?? '—'}
        </span>
      ),
    },
    {
      key: 'energy_score',
      header: 'Energy',
      render: (r) => <span className="font-mono">{r.energy_score ?? '—'}/10</span>,
    },
    {
      key: 'today_md',
      header: 'Today',
      render: (r) => (
        <span className="line-clamp-2 max-w-md text-sm text-slate-700">
          {r.today_md.slice(0, 140) || '—'}
        </span>
      ),
    },
    {
      key: 'open_blocker_count',
      header: 'Open Blockers',
      render: (r) => (
        <span
          className={
            'font-mono ' + (r.open_blocker_count > 0 ? 'text-red-700 font-semibold' : 'text-slate-500')
          }
        >
          {r.open_blocker_count}
        </span>
      ),
    },
  ];

  const blockerColumns: Column<OpenBlocker>[] = [
    {
      key: 'entry_date',
      header: 'From',
      render: (r) => <span className="font-mono text-xs text-slate-600">{r.entry_date}</span>,
    },
    {
      key: 'blocker_text',
      header: 'Blocker',
      render: (r) => <span className="text-sm">{r.blocker_text}</span>,
    },
    {
      key: 'owner_email',
      header: 'Owner',
      render: (r) => <span className="font-mono text-xs">{r.owner_email ?? '—'}</span>,
    },
    {
      key: 'due_date',
      header: 'Due',
      render: (r) => {
        const overdue = r.due_date != null && new Date(r.due_date) < new Date();
        return (
          <span className={'font-mono text-xs ' + (overdue ? 'text-red-700 font-semibold' : 'text-slate-600')}>
            {r.due_date ?? '—'}
          </span>
        );
      },
    },
    {
      key: 'status',
      header: 'Status',
      render: (r) => (
        <span
          className={
            'inline-block rounded px-2 py-0.5 text-xs font-medium ' +
            (r.status === 'open'
              ? 'bg-red-100 text-red-800'
              : r.status === 'in_progress'
              ? 'bg-amber-100 text-amber-800'
              : 'bg-slate-100 text-slate-700')
          }
        >
          {r.status}
        </span>
      ),
    },
    {
      key: 'days_open',
      header: 'Days Open',
      render: (r) => (
        <span className={'font-mono ' + (r.days_open >= 7 ? 'text-red-700 font-semibold' : 'text-slate-600')}>
          {r.days_open}d
        </span>
      ),
    },
  ];

  const moodColumns: Column<MoodPoint>[] = [
    {
      key: 'entry_date',
      header: 'Date',
      render: (r) => <span className="font-mono text-sm">{r.entry_date}</span>,
    },
    {
      key: 'mood',
      header: 'Mood',
      render: (r) => <span className="text-sm">{r.mood ?? '—'}</span>,
    },
    {
      key: 'energy_score',
      header: 'Energy',
      render: (r) => <span className="font-mono">{r.energy_score ?? '—'}</span>,
    },
    {
      key: 'rolling_avg_energy',
      header: '7-day Avg',
      render: (r) => (
        <span className="font-mono text-sm text-slate-600">
          {r.rolling_avg_energy != null ? Number(r.rolling_avg_energy).toFixed(2) : '—'}
        </span>
      ),
    },
  ];

  return (
    <div className="mx-auto max-w-7xl space-y-8 p-6">
      <header className="space-y-1">
        <h1 className="text-2xl font-bold text-slate-900">Founder Daily Standup Tracker</h1>
        <p className="text-sm text-slate-600">
          Daily yesterday/today/blockers log with mood + energy trend and open blocker queue.
        </p>
      </header>

      <section>
        <h2 className="mb-3 text-sm font-semibold uppercase tracking-wide text-slate-500">Summary KPIs</h2>
        <div className="grid grid-cols-2 gap-3 md:grid-cols-5">
          <div className="rounded-lg border border-slate-200 bg-white p-4">
            <div className="text-xs text-slate-500">Entries (60d)</div>
            <div className="mt-1 text-2xl font-semibold text-slate-900">{totalEntries}</div>
          </div>
          <div className="rounded-lg border border-slate-200 bg-white p-4">
            <div className="text-xs text-slate-500">Avg Energy (7d)</div>
            <div className="mt-1 text-2xl font-semibold text-slate-900">{avgEnergy7.toFixed(1)}</div>
          </div>
          <div className="rounded-lg border border-slate-200 bg-white p-4">
            <div className="text-xs text-slate-500">Open Blockers</div>
            <div
              className={
                'mt-1 text-2xl font-semibold ' +
                (totalOpenBlockers > 5 ? 'text-red-700' : 'text-slate-900')
              }
            >
              {totalOpenBlockers}
            </div>
          </div>
          <div className="rounded-lg border border-slate-200 bg-white p-4">
            <div className="text-xs text-slate-500">Overdue</div>
            <div className={'mt-1 text-2xl font-semibold ' + (overdueBlockers > 0 ? 'text-red-700' : 'text-slate-900')}>
              {overdueBlockers}
            </div>
          </div>
          <div className="rounded-lg border border-slate-200 bg-white p-4">
            <div className="text-xs text-slate-500">Oldest Blocker</div>
            <div
              className={
                'mt-1 text-2xl font-semibold ' +
                (oldestBlockerDays >= 14 ? 'text-red-700' : 'text-slate-900')
              }
            >
              {oldestBlockerDays}d
            </div>
          </div>
        </div>
      </section>

      <section>
        <h2 className="mb-3 text-sm font-semibold uppercase tracking-wide text-slate-500">
          Recent Standup Entries
        </h2>
        <DataTable
          rows={entries}
          columns={entryColumns}
          rowKey={(r, i) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 className="mb-3 text-sm font-semibold uppercase tracking-wide text-slate-500">
          Open Blocker Action Queue
        </h2>
        <DataTable
          rows={openBlockers}
          columns={blockerColumns}
          rowKey={(r, i) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 className="mb-3 text-sm font-semibold uppercase tracking-wide text-slate-500">
          Mood + Energy Trend (30d)
        </h2>
        <DataTable
          rows={moodTrend}
          columns={moodColumns}
          rowKey={(r, i) => String(r.entry_date ?? i)}
        />
      </section>
    </div>
  );
}
