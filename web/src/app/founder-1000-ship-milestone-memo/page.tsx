import { requireFounder } from '@/lib/auth/requireFounder';
import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type Kpi = { label: string; value: string | number };

function fmt(n: number | null | undefined): string {
  if (n === null || n === undefined) return '-';
  return Number(n).toLocaleString('en-IN');
}

function fmtDate(d: string | null | undefined): string {
  if (!d) return '-';
  try { return new Date(d).toLocaleString('en-IN'); } catch { return String(d); }
}

export default async function Page() {
  await requireFounder();
  const sb = await getSupabaseServerClient();

  let memos: any[] = [];
  let latest: any = null;
  let yearSummary: any[] = [];
  let recentWitnesses: any[] = [];

  try {
    const r = await sb.rpc('founder_milestone_list_memos_r1826');
    memos = (r.data as any[]) || [];
  } catch { memos = []; }

  try {
    const r = await sb.rpc('founder_milestone_latest_r1826');
    const arr = (r.data as any[]) || [];
    latest = arr[0] ?? null;
  } catch { latest = null; }

  try {
    const r = await sb.rpc('founder_milestone_year_summary_r1826');
    yearSummary = (r.data as any[]) || [];
  } catch { yearSummary = []; }

  try {
    const r = await sb.rpc('founder_milestone_recent_witnesses_r1826');
    recentWitnesses = (r.data as any[]) || [];
  } catch { recentWitnesses = []; }

  const totalMemos = memos.length;
  const highestMilestone = memos.reduce((acc, m) => Math.max(acc, Number(m.milestone_num) || 0), 0);
  const totalWitnesses = memos.reduce((acc, m) => acc + (Number(m.witness_count) || 0), 0);
  const yearsCovered = yearSummary.length;

  const kpis: Kpi[] = [
    { label: 'Total memos', value: fmt(totalMemos) },
    { label: 'Highest milestone', value: fmt(highestMilestone) },
    { label: 'Total witnesses', value: fmt(totalWitnesses) },
    { label: 'Years covered', value: fmt(yearsCovered) },
    { label: 'Latest milestone', value: latest ? fmt(latest.milestone_num) : '-' },
    { label: 'Latest at', value: latest ? fmtDate(latest.milestone_at) : '-' },
  ];

  const memoCols: Column<any>[] = [
    { key: 'milestone_num', header: 'Milestone', render: (r: any) => fmt(r.milestone_num) },
    { key: 'milestone_at', header: 'Hit at', render: (r: any) => fmtDate(r.milestone_at) },
    { key: 'summary_md', header: 'Summary', render: (r: any) => {
        const s = String(r.summary_md || '');
        return s.length > 120 ? s.slice(0, 120) + '...' : (s || '-');
      } },
    { key: 'top_features', header: 'Top features', render: (r: any) => {
        const arr = Array.isArray(r.top_features) ? r.top_features : [];
        if (arr.length === 0) return '-';
        return arr.slice(0, 5).join(', ') + (arr.length > 5 ? ` +${arr.length - 5}` : '');
      } },
    { key: 'witness_count', header: 'Witnesses', render: (r: any) => fmt(r.witness_count) },
    { key: 'founder_quote_md', header: 'Quote', render: (r: any) => {
        const s = String(r.founder_quote_md || '');
        return s.length > 80 ? s.slice(0, 80) + '...' : (s || '-');
      } },
  ];

  const yearCols: Column<any>[] = [
    { key: 'year_label', header: 'Year', render: (r: any) => r.year_label ?? '-' },
    { key: 'memo_count', header: 'Memos', render: (r: any) => fmt(r.memo_count) },
    { key: 'highest_milestone', header: 'Top milestone', render: (r: any) => fmt(r.highest_milestone) },
    { key: 'total_witnesses', header: 'Witnesses', render: (r: any) => fmt(r.total_witnesses) },
    { key: 'first_at', header: 'First', render: (r: any) => fmtDate(r.first_at) },
    { key: 'last_at', header: 'Last', render: (r: any) => fmtDate(r.last_at) },
  ];

  const witnessCols: Column<any>[] = [
    { key: 'milestone_num', header: 'Milestone', render: (r: any) => fmt(r.milestone_num) },
    { key: 'witness_email', header: 'Witness', render: (r: any) => r.witness_email ?? '-' },
    { key: 'witness_role', header: 'Role', render: (r: any) => r.witness_role ?? '-' },
    { key: 'reaction_md', header: 'Reaction', render: (r: any) => {
        const s = String(r.reaction_md || '');
        return s.length > 140 ? s.slice(0, 140) + '...' : (s || '-');
      } },
    { key: 'recorded_at', header: 'Recorded', render: (r: any) => fmtDate(r.recorded_at) },
  ];

  const latestFeatures: string[] = latest && Array.isArray(latest.top_features) ? latest.top_features : [];

  return (
    <main className="mx-auto max-w-7xl px-4 py-8">
      <div className="mb-6">
        <h1 className="text-2xl font-semibold">Founder 1000-Ship Milestone Memo</h1>
        <p className="mt-1 text-sm text-gray-600">
          Auto-curated memos of every milestone the team crosses on the road past 1000 ships. Read-only ledger — new memos
          append when a milestone is hit.
        </p>
      </div>

      <section className="mb-8">
        <h2 className="mb-3 text-lg font-medium">Ledger snapshot</h2>
        <div className="grid grid-cols-2 gap-3 sm:grid-cols-3 lg:grid-cols-6">
          {kpis.map((k) => (
            <div key={k.label} className="rounded-md border border-gray-200 bg-white p-3">
              <div className="text-xs uppercase tracking-wide text-gray-500">{k.label}</div>
              <div className="mt-1 text-lg font-semibold text-gray-900">{k.value}</div>
            </div>
          ))}
        </div>
      </section>

      <section className="mb-8">
        <h2 className="mb-3 text-lg font-medium">Latest milestone memo</h2>
        {latest ? (
          <div className="rounded-md border border-gray-200 bg-white p-4">
            <div className="flex flex-wrap items-baseline gap-3">
              <div className="text-2xl font-semibold">#{fmt(latest.milestone_num)}</div>
              <div className="text-sm text-gray-500">{fmtDate(latest.milestone_at)}</div>
              <div className="text-sm text-gray-500">witnesses: {fmt(latest.witness_count)}</div>
            </div>
            {latest.summary_md ? (
              <p className="mt-3 whitespace-pre-wrap text-sm text-gray-800">{latest.summary_md}</p>
            ) : (
              <p className="mt-3 text-sm text-gray-500">No summary recorded yet.</p>
            )}
            {latestFeatures.length > 0 && (
              <div className="mt-3">
                <div className="text-xs uppercase tracking-wide text-gray-500">Top features</div>
                <ul className="mt-1 list-inside list-disc text-sm text-gray-800">
                  {latestFeatures.map((f, i) => <li key={i}>{f}</li>)}
                </ul>
              </div>
            )}
            {latest.lessons_md && (
              <div className="mt-3">
                <div className="text-xs uppercase tracking-wide text-gray-500">Lessons</div>
                <p className="mt-1 whitespace-pre-wrap text-sm text-gray-800">{latest.lessons_md}</p>
              </div>
            )}
            {latest.founder_quote_md && (
              <blockquote className="mt-3 border-l-2 border-gray-300 pl-3 text-sm italic text-gray-700">
                {latest.founder_quote_md}
              </blockquote>
            )}
          </div>
        ) : (
          <div className="rounded-md border border-dashed border-gray-300 bg-white p-4 text-sm text-gray-500">
            No memos logged yet. Call founder_milestone_log_r1826 to record the first one.
          </div>
        )}
      </section>

      <section className="mb-8">
        <h2 className="mb-3 text-lg font-medium">All memos (latest 200)</h2>
        <DataTable
          rows={memos}
          columns={memoCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section className="mb-8">
        <h2 className="mb-3 text-lg font-medium">Yearly summary</h2>
        <DataTable
          rows={yearSummary}
          columns={yearCols}
          rowKey={(r: any, i: number) => String(r.year_label ?? i)}
        />
      </section>

      <section className="mb-8">
        <h2 className="mb-3 text-lg font-medium">Recent witness reactions</h2>
        <DataTable
          rows={recentWitnesses}
          columns={witnessCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>
    </main>
  );
}
