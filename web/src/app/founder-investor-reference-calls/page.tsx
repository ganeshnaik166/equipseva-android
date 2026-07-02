import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type CallRow = {
  id: string;
  investor_id: string;
  reference_name: string;
  reference_org: string | null;
  reference_email: string | null;
  call_scheduled_at: string | null;
  call_completed_at: string | null;
  call_outcome: string | null;
  question_count: number;
  concerning_count: number;
};

type SummaryRow = {
  investor_id: string;
  total_calls: number;
  completed_calls: number;
  very_positive_count: number;
  positive_count: number;
  neutral_count: number;
  negative_count: number;
  no_show_count: number;
  concerning_questions: number;
};

type ConcerningRow = {
  call_id: string;
  investor_id: string;
  reference_name: string;
  reference_org: string | null;
  call_outcome: string | null;
  concerning_questions: number;
  call_completed_at: string | null;
};

function fmtDate(s: string | null) {
  if (!s) return '—';
  try {
    return new Date(s).toLocaleString('en-IN', { dateStyle: 'medium', timeStyle: 'short' });
  } catch {
    return s;
  }
}

function outcomeBadge(o: string | null) {
  if (!o) return <span className="text-slate-400">pending</span>;
  const map: Record<string, string> = {
    very_positive: 'bg-emerald-100 text-emerald-800',
    positive: 'bg-green-100 text-green-800',
    neutral: 'bg-slate-100 text-slate-700',
    negative: 'bg-red-100 text-red-800',
    no_show: 'bg-amber-100 text-amber-800',
  };
  const cls = map[o] ?? 'bg-slate-100 text-slate-700';
  return <span className={`inline-block px-2 py-0.5 rounded text-xs font-medium ${cls}`}>{o.replace('_', ' ')}</span>;
}

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [callsRes, summaryRes, concerningRes] = await Promise.all([
    sb.rpc('r1673_list_calls'),
    sb.rpc('r1673_reference_summary_per_investor'),
    sb.rpc('r1673_concerning_references'),
  ]);

  const calls: CallRow[] = (callsRes.data as CallRow[] | null) ?? [];
  const summaries: SummaryRow[] = (summaryRes.data as SummaryRow[] | null) ?? [];
  const concerning: ConcerningRow[] = (concerningRes.data as ConcerningRow[] | null) ?? [];

  const totalCalls = calls.length;
  const completedCalls = calls.filter((c) => c.call_completed_at).length;
  const pendingCalls = totalCalls - completedCalls;
  const positiveCalls = calls.filter(
    (c) => c.call_outcome === 'very_positive' || c.call_outcome === 'positive',
  ).length;
  const negativeCalls = calls.filter((c) => c.call_outcome === 'negative').length;
  const noShowCalls = calls.filter((c) => c.call_outcome === 'no_show').length;
  const totalConcerning = concerning.reduce((acc, r) => acc + (r.concerning_questions ?? 0), 0);
  const investorsTracked = summaries.length;

  const callsCols: Column<CallRow>[] = [
    { key: 'reference_name', header: 'Reference', render: (r) => <span className="font-medium">{r.reference_name}</span> },
    { key: 'reference_org', header: 'Org', render: (r) => r.reference_org ?? '—' },
    { key: 'investor_id', header: 'Investor', render: (r) => <code className="text-xs text-slate-500">{r.investor_id.slice(0, 8)}</code> },
    { key: 'call_scheduled_at', header: 'Scheduled', render: (r) => fmtDate(r.call_scheduled_at) },
    { key: 'call_completed_at', header: 'Completed', render: (r) => fmtDate(r.call_completed_at) },
    { key: 'call_outcome', header: 'Outcome', render: (r) => outcomeBadge(r.call_outcome) },
    { key: 'question_count', header: 'Questions', render: (r) => <span className="tabular-nums">{r.question_count}</span> },
    {
      key: 'concerning_count',
      header: 'Concerning',
      render: (r) =>
        r.concerning_count > 0 ? (
          <span className="text-red-700 font-semibold tabular-nums">{r.concerning_count}</span>
        ) : (
          <span className="text-slate-400 tabular-nums">0</span>
        ),
    },
  ];

  const summaryCols: Column<SummaryRow>[] = [
    { key: 'investor_id', header: 'Investor', render: (r) => <code className="text-xs">{r.investor_id.slice(0, 8)}</code> },
    { key: 'total_calls', header: 'Total', render: (r) => <span className="tabular-nums">{r.total_calls}</span> },
    { key: 'completed_calls', header: 'Done', render: (r) => <span className="tabular-nums">{r.completed_calls}</span> },
    { key: 'very_positive_count', header: '★★', render: (r) => <span className="text-emerald-700 tabular-nums">{r.very_positive_count}</span> },
    { key: 'positive_count', header: '★', render: (r) => <span className="text-green-700 tabular-nums">{r.positive_count}</span> },
    { key: 'neutral_count', header: 'Neut', render: (r) => <span className="text-slate-600 tabular-nums">{r.neutral_count}</span> },
    { key: 'negative_count', header: 'Neg', render: (r) => <span className="text-red-700 tabular-nums">{r.negative_count}</span> },
    { key: 'no_show_count', header: 'No-show', render: (r) => <span className="text-amber-700 tabular-nums">{r.no_show_count}</span> },
    {
      key: 'concerning_questions',
      header: 'Concerning Qs',
      render: (r) =>
        r.concerning_questions > 0 ? (
          <span className="text-red-700 font-semibold tabular-nums">{r.concerning_questions}</span>
        ) : (
          <span className="text-slate-400 tabular-nums">0</span>
        ),
    },
  ];

  const concerningCols: Column<ConcerningRow>[] = [
    { key: 'reference_name', header: 'Reference', render: (r) => <span className="font-medium">{r.reference_name}</span> },
    { key: 'reference_org', header: 'Org', render: (r) => r.reference_org ?? '—' },
    { key: 'investor_id', header: 'Investor', render: (r) => <code className="text-xs text-slate-500">{r.investor_id.slice(0, 8)}</code> },
    { key: 'call_outcome', header: 'Outcome', render: (r) => outcomeBadge(r.call_outcome) },
    {
      key: 'concerning_questions',
      header: 'Concerning Qs',
      render: (r) => <span className="text-red-700 font-semibold tabular-nums">{r.concerning_questions}</span>,
    },
    { key: 'call_completed_at', header: 'Completed', render: (r) => fmtDate(r.call_completed_at) },
  ];

  return (
    <div className="p-6 max-w-7xl mx-auto space-y-8">
      <header>
        <h1 className="text-2xl font-bold text-slate-900">Investor Reference Calls</h1>
        <p className="text-sm text-slate-600 mt-1">
          Track reference calls with investors' portfolio references. Surface concerning signals before term sheets close.
        </p>
      </header>

      {/* Section 1 — Summary KPIs */}
      <section>
        <h2 className="text-sm font-semibold text-slate-700 uppercase tracking-wide mb-3">Summary</h2>
        <div className="grid grid-cols-2 md:grid-cols-4 lg:grid-cols-7 gap-3">
          <Kpi label="Total Calls" value={totalCalls} tone="slate" />
          <Kpi label="Completed" value={completedCalls} tone="slate" />
          <Kpi label="Pending" value={pendingCalls} tone="amber" />
          <Kpi label="Positive" value={positiveCalls} tone="emerald" />
          <Kpi label="Negative" value={negativeCalls} tone="red" />
          <Kpi label="No-show" value={noShowCalls} tone="amber" />
          <Kpi label="Concerning Qs" value={totalConcerning} tone={totalConcerning > 0 ? 'red' : 'slate'} />
        </div>
        <p className="text-xs text-slate-500 mt-2">
          {investorsTracked} investor{investorsTracked === 1 ? '' : 's'} tracked across reference calls.
        </p>
      </section>

      {/* Section 2 — Primary table: all calls */}
      <section>
        <h2 className="text-sm font-semibold text-slate-700 uppercase tracking-wide mb-3">All Reference Calls</h2>
        <DataTable<CallRow>
          rows={calls}
          columns={callsCols}
          rowKey={(r, i) => String(r.id ?? i)}
        />
        {calls.length === 0 ? (
          <p className="text-sm text-slate-500 mt-3">No reference calls logged yet.</p>
        ) : null}
      </section>

      {/* Section 3 — Per-investor summary */}
      <section>
        <h2 className="text-sm font-semibold text-slate-700 uppercase tracking-wide mb-3">Per-Investor Summary</h2>
        <DataTable<SummaryRow>
          rows={summaries}
          columns={summaryCols}
          rowKey={(r, i) => String(r.investor_id ?? i)}
        />
        {summaries.length === 0 ? (
          <p className="text-sm text-slate-500 mt-3">No investor reference data yet.</p>
        ) : null}
      </section>

      {/* Section 4 — Action queue: concerning references */}
      <section>
        <h2 className="text-sm font-semibold text-red-700 uppercase tracking-wide mb-3">
          Action Queue — Concerning References
        </h2>
        <p className="text-xs text-slate-600 mb-3">
          References flagged negative, no-show, or with concerning question responses. Address before next investor meeting.
        </p>
        <DataTable<ConcerningRow>
          rows={concerning}
          columns={concerningCols}
          rowKey={(r, i) => String(r.call_id ?? i)}
        />
        {concerning.length === 0 ? (
          <p className="text-sm text-emerald-700 mt-3">No concerning references. All clean.</p>
        ) : null}
      </section>
    </div>
  );
}

function Kpi({ label, value, tone }: { label: string; value: number; tone: 'slate' | 'emerald' | 'red' | 'amber' }) {
  const toneMap: Record<string, string> = {
    slate: 'bg-slate-50 text-slate-900 border-slate-200',
    emerald: 'bg-emerald-50 text-emerald-900 border-emerald-200',
    red: 'bg-red-50 text-red-900 border-red-200',
    amber: 'bg-amber-50 text-amber-900 border-amber-200',
  };
  return (
    <div className={`border rounded-lg p-3 ${toneMap[tone]}`}>
      <div className="text-xs uppercase tracking-wide opacity-70">{label}</div>
      <div className="text-2xl font-bold tabular-nums mt-1">{value}</div>
    </div>
  );
}
