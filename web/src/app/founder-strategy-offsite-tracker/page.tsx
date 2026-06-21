import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';
export const revalidate = 0;

export default async function FounderStrategyOffsiteTrackerPage() {
  const sb = await getSupabaseServerClient();

  const [offsitesRes, recentOffsitesRes, recentOutcomesRes] = await Promise.all([
    sb.rpc('list_offsites_r1854'),
    sb.rpc('recent_offsites_r1854', { p_limit: 10 }),
    sb.rpc('recent_outcomes_r1854', { p_limit: 25 }),
  ]);

  const offsites: any[] = Array.isArray(offsitesRes.data) ? offsitesRes.data : [];
  const recentOffsites: any[] = Array.isArray(recentOffsitesRes.data) ? recentOffsitesRes.data : [];
  const recentOutcomes: any[] = Array.isArray(recentOutcomesRes.data) ? recentOutcomesRes.data : [];

  const totalOffsites = offsites.length;
  const planned = offsites.filter((o) => o.status === 'planned').length;
  const completed = offsites.filter((o) => o.status === 'completed').length;
  const cancelled = offsites.filter((o) => o.status === 'cancelled').length;
  const totalOutcomes = offsites.reduce((s, o) => s + (Number(o.outcome_count) || 0), 0);
  const doneOutcomes = offsites.reduce((s, o) => s + (Number(o.outcomes_done) || 0), 0);
  const completionPct = totalOutcomes > 0 ? Math.round((doneOutcomes / totalOutcomes) * 100) : 0;

  const offsiteColumns: Column<any>[] = [
    { key: 'offsite_label', header: 'Off-Site', render: (r: any) => <span className="font-medium">{String(r.offsite_label ?? '')}</span> },
    { key: 'location', header: 'Location', render: (r: any) => <span>{String(r.location ?? '—')}</span> },
    { key: 'start_date', header: 'Start', render: (r: any) => <span>{r.start_date ? String(r.start_date) : '—'}</span> },
    { key: 'end_date', header: 'End', render: (r: any) => <span>{r.end_date ? String(r.end_date) : '—'}</span> },
    { key: 'theme', header: 'Theme', render: (r: any) => <span className="text-sm text-gray-600">{String(r.theme ?? '—')}</span> },
    {
      key: 'attendees',
      header: 'Attendees',
      render: (r: any) => {
        const a = Array.isArray(r.attendees) ? r.attendees : [];
        return <span className="text-sm">{a.length} attendee(s)</span>;
      },
    },
    {
      key: 'status',
      header: 'Status',
      render: (r: any) => {
        const s = String(r.status ?? '');
        const cls =
          s === 'completed'
            ? 'bg-green-100 text-green-800'
            : s === 'planned'
            ? 'bg-blue-100 text-blue-800'
            : 'bg-gray-100 text-gray-800';
        return <span className={`px-2 py-0.5 rounded text-xs font-medium ${cls}`}>{s || '—'}</span>;
      },
    },
    {
      key: 'progress',
      header: 'Outcomes',
      render: (r: any) => {
        const tot = Number(r.outcome_count) || 0;
        const done = Number(r.outcomes_done) || 0;
        return (
          <span className="text-sm">
            {done} / {tot} done
          </span>
        );
      },
    },
  ];

  const recentOffsiteColumns: Column<any>[] = [
    { key: 'offsite_label', header: 'Off-Site', render: (r: any) => <span className="font-medium">{String(r.offsite_label ?? '')}</span> },
    { key: 'location', header: 'Location', render: (r: any) => <span>{String(r.location ?? '—')}</span> },
    { key: 'start_date', header: 'Start', render: (r: any) => <span>{r.start_date ? String(r.start_date) : '—'}</span> },
    { key: 'theme', header: 'Theme', render: (r: any) => <span className="text-sm text-gray-600">{String(r.theme ?? '—')}</span> },
    { key: 'status', header: 'Status', render: (r: any) => <span className="text-sm">{String(r.status ?? '—')}</span> },
  ];

  const outcomeColumns: Column<any>[] = [
    { key: 'offsite_label', header: 'Off-Site', render: (r: any) => <span className="font-medium">{String(r.offsite_label ?? '')}</span> },
    { key: 'outcome_text', header: 'Outcome', render: (r: any) => <span>{String(r.outcome_text ?? '')}</span> },
    { key: 'owner_email', header: 'Owner', render: (r: any) => <span className="text-sm">{String(r.owner_email ?? '—')}</span> },
    { key: 'due_date', header: 'Due', render: (r: any) => <span>{r.due_date ? String(r.due_date) : '—'}</span> },
    {
      key: 'status',
      header: 'Status',
      render: (r: any) => {
        const s = String(r.status ?? '');
        const cls =
          s === 'done'
            ? 'bg-green-100 text-green-800'
            : s === 'open'
            ? 'bg-amber-100 text-amber-800'
            : 'bg-gray-100 text-gray-800';
        return <span className={`px-2 py-0.5 rounded text-xs font-medium ${cls}`}>{s || '—'}</span>;
      },
    },
    {
      key: 'created_at',
      header: 'Logged',
      render: (r: any) => <span className="text-xs text-gray-500">{r.created_at ? new Date(r.created_at).toLocaleDateString() : '—'}</span>,
    },
  ];

  return (
    <div className="p-6 max-w-7xl mx-auto space-y-8">
      <header>
        <h1 className="text-2xl font-bold">Founder Strategy Off-Site Tracker</h1>
        <p className="text-sm text-gray-600 mt-1">
          Plan annual strategy off-sites & track decisions through to closed outcomes.
        </p>
      </header>

      <section className="grid grid-cols-2 md:grid-cols-6 gap-3">
        <div className="rounded border bg-white p-3">
          <div className="text-xs text-gray-500">Total off-sites</div>
          <div className="text-xl font-bold">{totalOffsites}</div>
        </div>
        <div className="rounded border bg-white p-3">
          <div className="text-xs text-gray-500">Planned</div>
          <div className="text-xl font-bold text-blue-700">{planned}</div>
        </div>
        <div className="rounded border bg-white p-3">
          <div className="text-xs text-gray-500">Completed</div>
          <div className="text-xl font-bold text-green-700">{completed}</div>
        </div>
        <div className="rounded border bg-white p-3">
          <div className="text-xs text-gray-500">Cancelled</div>
          <div className="text-xl font-bold text-gray-700">{cancelled}</div>
        </div>
        <div className="rounded border bg-white p-3">
          <div className="text-xs text-gray-500">Outcomes logged</div>
          <div className="text-xl font-bold">{totalOutcomes}</div>
        </div>
        <div className="rounded border bg-white p-3">
          <div className="text-xs text-gray-500">Outcome completion</div>
          <div className="text-xl font-bold">{completionPct}%</div>
        </div>
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-semibold">All off-sites</h2>
        <DataTable
          rows={offsites}
          columns={offsiteColumns}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-semibold">Recent off-sites</h2>
        <DataTable
          rows={recentOffsites}
          columns={recentOffsiteColumns}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-semibold">Recent outcomes</h2>
        <DataTable
          rows={recentOutcomes}
          columns={outcomeColumns}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <footer className="text-xs text-gray-500 pt-4 border-t">
        Round r1854 · Annual strategy off-site planning & outcomes ledger · Founder-only.
      </footer>
    </div>
  );
}
