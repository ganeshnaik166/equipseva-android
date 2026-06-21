import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function FounderInvestorAnnualLetterTrackerPage() {
  const sb = await getSupabaseServerClient();

  const [lettersRes, summaryRes] = await Promise.all([
    sb.rpc('list_letters_r1741'),
    sb.rpc('reaction_summary_per_letter_r1741'),
  ]);

  const letters: any[] = Array.isArray(lettersRes.data) ? lettersRes.data : [];
  const summaries: any[] = Array.isArray(summaryRes.data) ? summaryRes.data : [];

  const latestLetterId = letters.length > 0 ? letters[0].id : null;
  let reactions: any[] = [];
  if (latestLetterId) {
    const reactionsRes = await sb.rpc('list_reactions_r1741', { p_letter_id: latestLetterId });
    reactions = Array.isArray(reactionsRes.data) ? reactionsRes.data : [];
  }

  const totalLetters = letters.length;
  const sentLetters = letters.filter((l) => l.status === 'sent').length;
  const totalReactions = summaries.reduce((acc, s) => acc + (s.total_reactions ?? 0), 0);
  const lovedItTotal = summaries.reduce((acc, s) => acc + (s.loved_it_count ?? 0), 0);

  const letterColumns: Column<any>[] = [
    { key: 'fiscal_year', header: 'FY', render: (r: any) => <span>{r.fiscal_year}</span> },
    { key: 'status', header: 'Status', render: (r: any) => <span className="capitalize">{String(r.status ?? '').replace(/_/g, ' ')}</span> },
    { key: 'drafted_at', header: 'Drafted', render: (r: any) => <span>{r.drafted_at ? new Date(r.drafted_at).toLocaleDateString() : '—'}</span> },
    { key: 'finalized_at', header: 'Finalized', render: (r: any) => <span>{r.finalized_at ? new Date(r.finalized_at).toLocaleDateString() : '—'}</span> },
    { key: 'sent_at', header: 'Sent', render: (r: any) => <span>{r.sent_at ? new Date(r.sent_at).toLocaleDateString() : '—'}</span> },
    { key: 'reach_count', header: 'Reach', render: (r: any) => <span>{r.reach_count ?? 0}</span> },
    { key: 'reaction_count', header: 'Reactions', render: (r: any) => <span>{r.reaction_count ?? 0}</span> },
  ];

  const summaryColumns: Column<any>[] = [
    { key: 'fiscal_year', header: 'FY', render: (r: any) => <span>{r.fiscal_year}</span> },
    { key: 'total_reactions', header: 'Total', render: (r: any) => <span>{r.total_reactions ?? 0}</span> },
    { key: 'loved_it_count', header: 'Loved it', render: (r: any) => <span className="text-emerald-700">{r.loved_it_count ?? 0}</span> },
    { key: 'positive_count', header: 'Positive', render: (r: any) => <span className="text-emerald-600">{r.positive_count ?? 0}</span> },
    { key: 'neutral_count', header: 'Neutral', render: (r: any) => <span className="text-slate-600">{r.neutral_count ?? 0}</span> },
    { key: 'concerned_count', header: 'Concerned', render: (r: any) => <span className="text-amber-700">{r.concerned_count ?? 0}</span> },
    { key: 'critical_count', header: 'Critical', render: (r: any) => <span className="text-rose-700">{r.critical_count ?? 0}</span> },
  ];

  const reactionColumns: Column<any>[] = [
    { key: 'investor_email', header: 'Investor', render: (r: any) => <span>{r.investor_email ?? r.investor_id?.slice(0, 8) ?? '—'}</span> },
    { key: 'reaction', header: 'Reaction', render: (r: any) => <span className="capitalize">{String(r.reaction ?? '').replace(/_/g, ' ')}</span> },
    { key: 'reaction_note', header: 'Note', render: (r: any) => <span className="text-sm text-slate-600">{r.reaction_note ?? '—'}</span> },
    { key: 'recorded_at', header: 'Recorded', render: (r: any) => <span>{r.recorded_at ? new Date(r.recorded_at).toLocaleString() : '—'}</span> },
  ];

  return (
    <div className="mx-auto max-w-7xl px-6 py-10 space-y-10">
      <header className="space-y-2">
        <h1 className="text-3xl font-bold tracking-tight">Investor Annual Letter Tracker</h1>
        <p className="text-slate-600">
          Buffett-style annual letter to investors. Draft &gt; review &gt; finalize &gt; send. Track reactions per fiscal year.
        </p>
      </header>

      <section className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
        <div className="rounded-xl border border-slate-200 bg-white p-5">
          <div className="text-xs uppercase tracking-wide text-slate-500">Total Letters</div>
          <div className="mt-2 text-3xl font-semibold">{totalLetters}</div>
        </div>
        <div className="rounded-xl border border-slate-200 bg-white p-5">
          <div className="text-xs uppercase tracking-wide text-slate-500">Sent</div>
          <div className="mt-2 text-3xl font-semibold text-emerald-700">{sentLetters}</div>
        </div>
        <div className="rounded-xl border border-slate-200 bg-white p-5">
          <div className="text-xs uppercase tracking-wide text-slate-500">Total Reactions</div>
          <div className="mt-2 text-3xl font-semibold">{totalReactions}</div>
        </div>
        <div className="rounded-xl border border-slate-200 bg-white p-5">
          <div className="text-xs uppercase tracking-wide text-slate-500">Loved It</div>
          <div className="mt-2 text-3xl font-semibold text-emerald-700">{lovedItTotal}</div>
        </div>
      </section>

      <section className="space-y-4">
        <h2 className="text-xl font-semibold">All Letters</h2>
        <p className="text-sm text-slate-600">Lifecycle status by fiscal year. Reach &gt;= total investors notified.</p>
        <DataTable
          rows={letters}
          columns={letterColumns}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section className="space-y-4">
        <h2 className="text-xl font-semibold">Reaction Summary by Fiscal Year</h2>
        <p className="text-sm text-slate-600">Sentiment breakdown. Concerned & critical &gt; 0 warrants 1:1 follow-up.</p>
        <DataTable
          rows={summaries}
          columns={summaryColumns}
          rowKey={(r: any, i: number) => String(r.letter_id ?? i)}
        />
      </section>

      <section className="space-y-4">
        <h2 className="text-xl font-semibold">Latest Letter Reactions</h2>
        <p className="text-sm text-slate-600">
          {latestLetterId ? <>Detailed reactions for FY {letters[0]?.fiscal_year ?? '—'}.</> : <>No letter drafted yet.</>}
        </p>
        <DataTable
          rows={reactions}
          columns={reactionColumns}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>
    </div>
  );
}
