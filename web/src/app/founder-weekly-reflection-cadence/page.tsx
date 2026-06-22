import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type CadenceRow = {
  id: string;
  week_start: string;
  founder_score: number | null;
  status: string;
  recorded_at: string;
  keep_len: number;
  stop_len: number;
  start_len: number;
  action_count: number;
  done_count: number;
};

type ThemeRow = {
  action_type: string;
  total_count: number;
  open_count: number;
  done_count: number;
  dropped_count: number;
};

type TrendRow = {
  week_start: string;
  founder_score: number | null;
  rolling_avg: string | number | null;
};

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [cadencesRes, themesRes, trendRes] = await Promise.all([
    sb.rpc('list_cadences_r1882'),
    sb.rpc('recent_themes_r1882'),
    sb.rpc('founder_score_trend_r1882'),
  ]);

  const cadences: CadenceRow[] = (cadencesRes.data as CadenceRow[] | null) ?? [];
  const themes: ThemeRow[] = (themesRes.data as ThemeRow[] | null) ?? [];
  const trend: TrendRow[] = (trendRes.data as TrendRow[] | null) ?? [];

  const totalWeeks = cadences.length;
  const totalActions = cadences.reduce((s, r) => s + (r.action_count ?? 0), 0);
  const totalDone = cadences.reduce((s, r) => s + (r.done_count ?? 0), 0);
  const completionPct = totalActions > 0 ? Math.round((totalDone / totalActions) * 100) : 0;
  const latestScore = cadences[0]?.founder_score ?? null;

  const cadenceCols: Column<CadenceRow>[] = [
    { key: 'week', header: 'Week Start', render: (r: any) => <span className="font-mono text-xs">{String(r.week_start)}</span> },
    { key: 'score', header: 'Score (1-10)', render: (r: any) => <span className="font-medium">{r.founder_score ?? '—'}</span> },
    { key: 'status', header: 'Status', render: (r: any) => <span className="rounded bg-gray-100 px-2 py-0.5 text-xs">{r.status}</span> },
    { key: 'keep', header: 'Keep (chars)', render: (r: any) => <span>{r.keep_len}</span> },
    { key: 'stop', header: 'Stop (chars)', render: (r: any) => <span>{r.stop_len}</span> },
    { key: 'start', header: 'Start (chars)', render: (r: any) => <span>{r.start_len}</span> },
    { key: 'actions', header: 'Actions', render: (r: any) => <span>{r.done_count}/{r.action_count}</span> },
    { key: 'recorded', header: 'Recorded', render: (r: any) => <span className="text-xs text-gray-600">{new Date(r.recorded_at).toLocaleString()}</span> },
  ];

  const themeCols: Column<ThemeRow>[] = [
    { key: 'type', header: 'Type', render: (r: any) => <span className="font-medium capitalize">{r.action_type}</span> },
    { key: 'total', header: 'Total (90d)', render: (r: any) => <span>{r.total_count}</span> },
    { key: 'open', header: 'Open', render: (r: any) => <span className="text-amber-700">{r.open_count}</span> },
    { key: 'done', header: 'Done', render: (r: any) => <span className="text-green-700">{r.done_count}</span> },
    { key: 'dropped', header: 'Dropped', render: (r: any) => <span className="text-gray-500">{r.dropped_count}</span> },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'week', header: 'Week', render: (r: any) => <span className="font-mono text-xs">{String(r.week_start)}</span> },
    { key: 'score', header: 'Score', render: (r: any) => <span className="font-medium">{r.founder_score ?? '—'}</span> },
    { key: 'roll', header: 'Rolling Avg (4w)', render: (r: any) => <span>{r.rolling_avg ?? '—'}</span> },
  ];

  return (
    <div className="mx-auto max-w-7xl space-y-6 p-6">
      <header className="space-y-1">
        <h1 className="text-2xl font-semibold">Founder Weekly Reflection Cadence</h1>
        <p className="text-sm text-gray-600">
          Pre-Saturday weekly reflection: what to keep, stop, and start. Self-score 1–10 and track follow-through.
        </p>
      </header>

      <section className="grid grid-cols-2 gap-3 sm:grid-cols-4">
        <div className="rounded border border-gray-200 bg-white p-4">
          <div className="text-xs uppercase tracking-wider text-gray-500">Weeks Logged</div>
          <div className="mt-1 text-2xl font-semibold">{totalWeeks}</div>
        </div>
        <div className="rounded border border-gray-200 bg-white p-4">
          <div className="text-xs uppercase tracking-wider text-gray-500">Latest Score</div>
          <div className="mt-1 text-2xl font-semibold">{latestScore ?? '—'}</div>
        </div>
        <div className="rounded border border-gray-200 bg-white p-4">
          <div className="text-xs uppercase tracking-wider text-gray-500">Total Actions</div>
          <div className="mt-1 text-2xl font-semibold">{totalActions}</div>
        </div>
        <div className="rounded border border-gray-200 bg-white p-4">
          <div className="text-xs uppercase tracking-wider text-gray-500">Done Rate</div>
          <div className="mt-1 text-2xl font-semibold">{completionPct}%</div>
        </div>
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-semibold">Recent Weeks</h2>
        <p className="text-xs text-gray-600">Last 26 cadences. Score range 1–10, where &gt;7 indicates a strong week.</p>
        <DataTable<CadenceRow>
          rows={cadences}
          columns={cadenceCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
          emptyMessage="No cadences recorded yet. Use record_cadence_r1882 RPC to log this week."
        />
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-semibold">Recent Themes (90 days)</h2>
        <p className="text-xs text-gray-600">Aggregate count of keep/stop/start actions across the trailing 90-day window.</p>
        <DataTable<ThemeRow>
          rows={themes}
          columns={themeCols}
          rowKey={(r: any, i: number) => String(r.action_type ?? i)}
          emptyMessage="No actions logged in the last 90 days."
        />
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-semibold">Founder Score Trend</h2>
        <p className="text-xs text-gray-600">Last 12 weeks with 4-week rolling average. Watch for trends &lt; 6 as a burnout signal.</p>
        <DataTable<TrendRow>
          rows={trend}
          columns={trendCols}
          rowKey={(r: any, i: number) => String(r.week_start ?? i)}
          emptyMessage="No score history yet."
        />
      </section>

      <footer className="border-t border-gray-200 pt-3 text-xs text-gray-500">
        Write ops via record_cadence_r1882, log_action_r1882, complete_action_r1882. All actions audit-logged to founder_action_log.
      </footer>
    </div>
  );
}
