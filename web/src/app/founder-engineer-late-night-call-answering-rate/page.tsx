import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type RollupRow = {
  engineer_id: string;
  engineer_name: string | null;
  engineer_email: string | null;
  total_calls: number;
  answered_calls: number;
  answer_rate_pct: number | null;
  p0_calls: number;
  p0_answered: number;
  p0_answer_rate_pct: number | null;
  avg_ring_seconds: number | null;
  last_call_at: string | null;
};

type TopicRow = {
  call_topic: string;
  call_count: number;
  answered_count: number;
  answer_rate_pct: number | null;
  avg_duration_seconds: number | null;
};

type HourRow = {
  hour_of_day_ist: number;
  call_count: number;
  answered_count: number;
  answer_rate_pct: number | null;
};

type RecentRow = {
  id: string;
  called_at: string;
  engineer_name: string | null;
  customer_org: string | null;
  hour_of_day_ist: number;
  was_answered: boolean;
  ring_seconds: number;
  call_topic: string;
  urgency_assessed: string;
  callback_within_minutes: number | null;
  resolution_note: string | null;
};

type ScorecardRow = {
  id: string;
  engineer_name: string | null;
  period_start: string;
  period_end: string;
  total_calls: number;
  answer_rate_pct: number | null;
  p0_calls: number;
  p0_answer_rate_pct: number | null;
  avg_ring_seconds: number | null;
  tier_grade: string;
  founder_note: string | null;
};

function fmtPct(n: number | null | undefined): string {
  if (n === null || n === undefined) return '-';
  return `${Number(n).toFixed(1)}%`;
}

function fmtNum(n: number | null | undefined, digits = 1): string {
  if (n === null || n === undefined) return '-';
  return Number(n).toFixed(digits);
}

function fmtTs(s: string | null | undefined): string {
  if (!s) return '-';
  try {
    return new Date(s).toLocaleString('en-IN', { hour12: false });
  } catch {
    return s;
  }
}

function gradeBadge(g: string): string {
  switch (g) {
    case 'rockstar': return 'bg-emerald-100 text-emerald-800';
    case 'solid': return 'bg-blue-100 text-blue-800';
    case 'at_risk': return 'bg-amber-100 text-amber-800';
    case 'ghost': return 'bg-rose-100 text-rose-800';
    default: return 'bg-slate-100 text-slate-700';
  }
}

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [rollupRes, topicRes, hourRes, recentRes, scoreRes] = await Promise.all([
    supabase.rpc('engineer_late_night_rollup_r2402', { p_days: 30 }),
    supabase.rpc('engineer_late_night_topic_breakdown_r2402', { p_days: 30 }),
    supabase.rpc('engineer_late_night_hour_heatmap_r2402', { p_days: 30 }),
    supabase.rpc('engineer_late_night_recent_r2402', { p_limit: 50 }),
    supabase.rpc('engineer_late_night_scorecards_list_r2402', { p_limit: 30 }),
  ]);

  const rollup: RollupRow[] = (rollupRes.data as RollupRow[]) ?? [];
  const topics: TopicRow[] = (topicRes.data as TopicRow[]) ?? [];
  const hours: HourRow[] = (hourRes.data as HourRow[]) ?? [];
  const recent: RecentRow[] = (recentRes.data as RecentRow[]) ?? [];
  const scorecards: ScorecardRow[] = (scoreRes.data as ScorecardRow[]) ?? [];

  const errors = [rollupRes.error, topicRes.error, hourRes.error, recentRes.error, scoreRes.error]
    .filter((e) => e)
    .map((e) => e!.message);

  // headline metrics
  const totalCalls = rollup.reduce((s, r) => s + (r.total_calls || 0), 0);
  const totalAns = rollup.reduce((s, r) => s + (r.answered_calls || 0), 0);
  const overallRate = totalCalls > 0 ? (totalAns / totalCalls) * 100 : 0;
  const totalP0 = rollup.reduce((s, r) => s + (r.p0_calls || 0), 0);
  const totalP0Ans = rollup.reduce((s, r) => s + (r.p0_answered || 0), 0);
  const p0Rate = totalP0 > 0 ? (totalP0Ans / totalP0) * 100 : 0;

  const rollupCols: Column<RollupRow>[] = [
    { key: 'eng', header: 'Engineer', render: (r) => (
      <div>
        <div className="font-medium">{r.engineer_name ?? '-'}</div>
        <div className="text-xs text-slate-500">{r.engineer_email ?? ''}</div>
      </div>
    ) },
    { key: 'calls', header: 'Calls', render: (r) => r.total_calls },
    { key: 'ans', header: 'Answered', render: (r) => r.answered_calls },
    { key: 'rate', header: 'Answer rate', render: (r) => (
      <span className={Number(r.answer_rate_pct ?? 0) >= 65 ? 'text-emerald-700' : 'text-rose-700'}>
        {fmtPct(r.answer_rate_pct)}
      </span>
    ) },
    { key: 'p0', header: 'P0 calls', render: (r) => r.p0_calls },
    { key: 'p0rate', header: 'P0 answer rate', render: (r) => (
      <span className={Number(r.p0_answer_rate_pct ?? 0) >= 95 ? 'text-emerald-700' : 'text-rose-700'}>
        {fmtPct(r.p0_answer_rate_pct)}
      </span>
    ) },
    { key: 'ring', header: 'Avg ring (s)', render: (r) => fmtNum(r.avg_ring_seconds) },
    { key: 'last', header: 'Last call', render: (r) => fmtTs(r.last_call_at) },
  ];

  const topicCols: Column<TopicRow>[] = [
    { key: 'topic', header: 'Topic', render: (r) => r.call_topic },
    { key: 'count', header: 'Calls', render: (r) => r.call_count },
    { key: 'ans', header: 'Answered', render: (r) => r.answered_count },
    { key: 'rate', header: 'Answer rate', render: (r) => fmtPct(r.answer_rate_pct) },
    { key: 'dur', header: 'Avg dur (s)', render: (r) => fmtNum(r.avg_duration_seconds) },
  ];

  const hourCols: Column<HourRow>[] = [
    { key: 'hr', header: 'Hour IST', render: (r) => `${String(r.hour_of_day_ist).padStart(2, '0')}:00` },
    { key: 'count', header: 'Calls', render: (r) => r.call_count },
    { key: 'ans', header: 'Answered', render: (r) => r.answered_count },
    { key: 'rate', header: 'Answer rate', render: (r) => fmtPct(r.answer_rate_pct) },
  ];

  const recentCols: Column<RecentRow>[] = [
    { key: 'ts', header: 'When', render: (r) => fmtTs(r.called_at) },
    { key: 'eng', header: 'Engineer', render: (r) => r.engineer_name ?? '-' },
    { key: 'cust', header: 'Customer org', render: (r) => r.customer_org ?? '-' },
    { key: 'hr', header: 'Hour IST', render: (r) => `${String(r.hour_of_day_ist).padStart(2, '0')}:00` },
    { key: 'ans', header: 'Answered', render: (r) => (
      <span className={r.was_answered ? 'text-emerald-700' : 'text-rose-700'}>
        {r.was_answered ? 'yes' : 'no'}
      </span>
    ) },
    { key: 'ring', header: 'Ring (s)', render: (r) => r.ring_seconds },
    { key: 'topic', header: 'Topic', render: (r) => r.call_topic },
    { key: 'urg', header: 'Urgency', render: (r) => r.urgency_assessed },
    { key: 'cb', header: 'Callback (min)', render: (r) => r.callback_within_minutes ?? '-' },
    { key: 'note', header: 'Resolution', render: (r) => r.resolution_note ?? '-' },
  ];

  const scoreCols: Column<ScorecardRow>[] = [
    { key: 'eng', header: 'Engineer', render: (r) => r.engineer_name ?? '-' },
    { key: 'period', header: 'Period', render: (r) => `${r.period_start} -> ${r.period_end}` },
    { key: 'total', header: 'Calls', render: (r) => r.total_calls },
    { key: 'rate', header: 'Answer rate', render: (r) => fmtPct(r.answer_rate_pct) },
    { key: 'p0', header: 'P0 calls', render: (r) => r.p0_calls },
    { key: 'p0rate', header: 'P0 answer rate', render: (r) => fmtPct(r.p0_answer_rate_pct) },
    { key: 'ring', header: 'Avg ring (s)', render: (r) => fmtNum(r.avg_ring_seconds) },
    { key: 'grade', header: 'Grade', render: (r) => (
      <span className={`inline-flex rounded px-2 py-0.5 text-xs font-medium ${gradeBadge(r.tier_grade)}`}>
        {r.tier_grade}
      </span>
    ) },
    { key: 'note', header: 'Founder note', render: (r) => r.founder_note ?? '-' },
  ];

  return (
    <div className="space-y-6 p-6">
      <header className="space-y-1">
        <h1 className="text-2xl font-semibold">Engineer late-night call answering rate</h1>
        <p className="text-sm text-slate-600">
          When customers call after-hours, do engineers actually pick up? Tracks answer rate,
          call topic & assessed urgency over the last 30 days. P0 answer rate is the one that matters most.
        </p>
      </header>

      {errors.length > 0 ? (
        <div className="rounded border border-rose-300 bg-rose-50 p-3 text-sm text-rose-800">
          <div className="font-medium">RPC errors</div>
          <ul className="list-disc pl-5">
            {errors.map((e, i) => (<li key={i}>{e}</li>))}
          </ul>
        </div>
      ) : null}

      <section className="grid grid-cols-2 gap-3 md:grid-cols-4">
        <div className="rounded border border-slate-200 bg-white p-3">
          <div className="text-xs uppercase text-slate-500">Calls (30d)</div>
          <div className="text-2xl font-semibold">{totalCalls}</div>
        </div>
        <div className="rounded border border-slate-200 bg-white p-3">
          <div className="text-xs uppercase text-slate-500">Overall answer rate</div>
          <div className={`text-2xl font-semibold ${overallRate >= 65 ? 'text-emerald-700' : 'text-rose-700'}`}>
            {overallRate.toFixed(1)}%
          </div>
        </div>
        <div className="rounded border border-slate-200 bg-white p-3">
          <div className="text-xs uppercase text-slate-500">P0 calls</div>
          <div className="text-2xl font-semibold">{totalP0}</div>
        </div>
        <div className="rounded border border-slate-200 bg-white p-3">
          <div className="text-xs uppercase text-slate-500">P0 answer rate</div>
          <div className={`text-2xl font-semibold ${p0Rate >= 95 ? 'text-emerald-700' : 'text-rose-700'}`}>
            {p0Rate.toFixed(1)}%
          </div>
        </div>
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-semibold">Per-engineer rollup (30 days)</h2>
        <DataTable<RollupRow>
          columns={rollupCols}
          rows={rollup}
          emptyMessage="No late-night calls logged in the last 30 days."
          rowKey={(r) => r.engineer_id}
        />
      </section>

      <section className="grid gap-6 md:grid-cols-2">
        <div className="space-y-2">
          <h2 className="text-lg font-semibold">Call topics (30 days)</h2>
          <DataTable<TopicRow>
            columns={topicCols}
            rows={topics}
            emptyMessage="No topic data yet."
            rowKey={(r) => r.call_topic}
          />
        </div>
        <div className="space-y-2">
          <h2 className="text-lg font-semibold">Hour-of-day heatmap IST (30 days)</h2>
          <DataTable<HourRow>
            columns={hourCols}
            rows={hours}
            emptyMessage="No hour breakdown yet."
            rowKey={(r) => String(r.hour_of_day_ist)}
          />
        </div>
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-semibold">Recent calls</h2>
        <DataTable<RecentRow>
          columns={recentCols}
          rows={recent}
          emptyMessage="No recent calls."
          rowKey={(r) => r.id}
        />
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-semibold">Scorecards</h2>
        <DataTable<ScorecardRow>
          columns={scoreCols}
          rows={scorecards}
          emptyMessage="No scorecards yet. Call engineer_late_night_rebuild_scorecard_r2402 to seed."
          rowKey={(r) => r.id}
        />
      </section>
    </div>
  );
}
