import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type RetroRow = {
  quarter: string;
  recorded_at: string;
  summary_md: string;
  hit_count: number;
  miss_count: number;
  carry_count: number;
  total_items: number;
  hit_rate_pct: number;
};

type ActionItemRow = {
  id: string;
  retro_quarter: string;
  okr_id: string;
  okr_title: string;
  status: string;
  miss_reason: string;
  owner: string;
  notes: string;
  updated_at: string;
};

type SummaryRow = {
  quarters_recorded: number;
  total_items: number;
  total_hits: number;
  total_misses: number;
  total_partial: number;
  total_dropped: number;
  total_carry_forward: number;
  overall_hit_rate_pct: number;
  latest_quarter: string;
  top_miss_reason: string;
};

export default async function FounderQuarterlyOkrRetroPage() {
  const sb = await getSupabaseServerClient();

  const [retrosRes, actionsRes, summaryRes] = await Promise.all([
    sb.rpc('founder_list_quarterly_retros_r1662'),
    sb.rpc('founder_quarterly_retro_action_items_r1662'),
    sb.rpc('founder_quarterly_retro_summary_r1662'),
  ]);

  const retros: RetroRow[] = (retrosRes.data as RetroRow[]) ?? [];
  const actions: ActionItemRow[] = (actionsRes.data as ActionItemRow[]) ?? [];
  const summaryArr = (summaryRes.data as SummaryRow[]) ?? [];
  const summary: SummaryRow = summaryArr[0] ?? {
    quarters_recorded: 0,
    total_items: 0,
    total_hits: 0,
    total_misses: 0,
    total_partial: 0,
    total_dropped: 0,
    total_carry_forward: 0,
    overall_hit_rate_pct: 0,
    latest_quarter: '—',
    top_miss_reason: 'none',
  };

  const retroCols: Column<RetroRow>[] = [
    { key: 'quarter', header: 'Quarter', render: (r) => <span className="font-mono font-semibold">{r.quarter}</span> },
    { key: 'recorded_at', header: 'Recorded', render: (r) => <span className="text-xs text-gray-500">{r.recorded_at ? new Date(r.recorded_at).toLocaleDateString() : '—'}</span> },
    { key: 'total_items', header: 'Items', render: (r) => <span>{r.total_items}</span> },
    { key: 'hit_count', header: 'Hits', render: (r) => <span className="text-emerald-700 font-semibold">{r.hit_count}</span> },
    { key: 'miss_count', header: 'Misses', render: (r) => <span className="text-rose-700 font-semibold">{r.miss_count}</span> },
    { key: 'carry_count', header: 'Carry-Fwd', render: (r) => <span className="text-amber-700">{r.carry_count}</span> },
    {
      key: 'hit_rate_pct',
      header: 'Hit Rate',
      render: (r) => {
        const pct = Number(r.hit_rate_pct ?? 0);
        const color = pct >= 70 ? 'bg-emerald-100 text-emerald-800' : pct >= 50 ? 'bg-amber-100 text-amber-800' : 'bg-rose-100 text-rose-800';
        return <span className={`px-2 py-0.5 rounded text-xs font-semibold ${color}`}>{pct}%</span>;
      },
    },
    {
      key: 'summary_md',
      header: 'Summary',
      render: (r) => <span className="text-xs text-gray-600 line-clamp-2 max-w-md">{r.summary_md || '—'}</span>,
    },
  ];

  const actionCols: Column<ActionItemRow>[] = [
    { key: 'retro_quarter', header: 'From Q', render: (r) => <span className="font-mono text-xs">{r.retro_quarter}</span> },
    { key: 'okr_title', header: 'OKR', render: (r) => <span className="font-medium">{r.okr_title || r.okr_id}</span> },
    {
      key: 'status',
      header: 'Status',
      render: (r) => {
        const cls =
          r.status === 'hit' ? 'bg-emerald-100 text-emerald-800' :
          r.status === 'miss' ? 'bg-rose-100 text-rose-800' :
          r.status === 'partial' ? 'bg-amber-100 text-amber-800' :
          r.status === 'dropped' ? 'bg-gray-200 text-gray-700' :
          'bg-blue-100 text-blue-800';
        return <span className={`px-2 py-0.5 rounded text-xs font-semibold ${cls}`}>{r.status}</span>;
      },
    },
    { key: 'miss_reason', header: 'Miss Reason', render: (r) => <span className="text-xs text-gray-600">{r.miss_reason || '—'}</span> },
    { key: 'owner', header: 'Owner', render: (r) => <span className="text-sm">{r.owner || '—'}</span> },
    { key: 'updated_at', header: 'Updated', render: (r) => <span className="text-xs text-gray-500">{r.updated_at ? new Date(r.updated_at).toLocaleDateString() : '—'}</span> },
  ];

  return (
    <main className="p-6 space-y-8">
      <header>
        <h1 className="text-2xl font-bold">Quarterly OKR Retrospective</h1>
        <p className="text-sm text-gray-600 mt-1">
          Per-quarter hit/miss tracking, miss-reason taxonomy, and carry-forward action queue.
        </p>
      </header>

      {/* Section 1 — Summary KPIs */}
      <section>
        <h2 className="text-lg font-semibold mb-3">Cumulative Summary</h2>
        <div className="grid grid-cols-2 md:grid-cols-4 lg:grid-cols-5 gap-4">
          <KpiCard label="Quarters Recorded" value={summary.quarters_recorded} />
          <KpiCard label="Total OKRs" value={summary.total_items} />
          <KpiCard label="Hits" value={summary.total_hits} tone="emerald" />
          <KpiCard label="Misses" value={summary.total_misses} tone="rose" />
          <KpiCard label="Partial" value={summary.total_partial} tone="amber" />
          <KpiCard label="Dropped" value={summary.total_dropped} tone="gray" />
          <KpiCard label="Carry-Forward" value={summary.total_carry_forward} tone="amber" />
          <KpiCard label="Overall Hit Rate" value={`${summary.overall_hit_rate_pct}%`} tone={summary.overall_hit_rate_pct >= 70 ? 'emerald' : summary.overall_hit_rate_pct >= 50 ? 'amber' : 'rose'} />
          <KpiCard label="Latest Quarter" value={summary.latest_quarter || '—'} />
          <KpiCard label="Top Miss Reason" value={summary.top_miss_reason || 'none'} />
        </div>
      </section>

      {/* Section 2 — Quarters Table */}
      <section>
        <div className="flex items-center justify-between mb-3">
          <h2 className="text-lg font-semibold">Recorded Quarters ({retros.length})</h2>
        </div>
        {retros.length === 0 ? (
          <div className="rounded-lg border border-dashed p-8 text-center text-sm text-gray-500">
            No retros recorded yet. Use <code className="font-mono bg-gray-100 px-1 rounded">founder_record_quarterly_retro_r1662</code> to add one.
          </div>
        ) : (
          <DataTable rows={retros} columns={retroCols} rowKey={(r, i) => String((r as RetroRow).quarter ?? i)} />
        )}
      </section>

      {/* Section 3 — Carry-Forward Action Queue */}
      <section>
        <div className="flex items-center justify-between mb-3">
          <h2 className="text-lg font-semibold">Carry-Forward Action Queue ({actions.length})</h2>
          <span className="text-xs text-gray-500">Items flagged for next-quarter follow-up</span>
        </div>
        {actions.length === 0 ? (
          <div className="rounded-lg border border-dashed p-8 text-center text-sm text-gray-500">
            No action items carried forward. Mark items <code className="font-mono bg-gray-100 px-1 rounded">carry_forward=true</code> in the retro.
          </div>
        ) : (
          <DataTable rows={actions} columns={actionCols} rowKey={(r, i) => String((r as ActionItemRow).id ?? i)} />
        )}
      </section>
    </main>
  );
}

function KpiCard({ label, value, tone = 'slate' }: { label: string; value: string | number; tone?: 'slate' | 'emerald' | 'rose' | 'amber' | 'gray' }) {
  const tones: Record<string, string> = {
    slate: 'border-slate-200 bg-slate-50 text-slate-900',
    emerald: 'border-emerald-200 bg-emerald-50 text-emerald-900',
    rose: 'border-rose-200 bg-rose-50 text-rose-900',
    amber: 'border-amber-200 bg-amber-50 text-amber-900',
    gray: 'border-gray-200 bg-gray-50 text-gray-900',
  };
  return (
    <div className={`rounded-lg border p-3 ${tones[tone]}`}>
      <div className="text-xs uppercase tracking-wide opacity-70">{label}</div>
      <div className="text-xl font-bold mt-1">{value}</div>
    </div>
  );
}
