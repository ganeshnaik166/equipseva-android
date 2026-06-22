import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function FounderGovernanceDocsStatusPage() {
  const sb = await getSupabaseServerClient();

  const [summaryRes, listRes, byRegRes, byOwnerRes, upcomingRes, eventsRes, mixRes] = await Promise.all([
    sb.rpc('gov_docs_r2277_summary'),
    sb.rpc('gov_docs_r2277_list'),
    sb.rpc('gov_docs_r2277_by_regulator'),
    sb.rpc('gov_docs_r2277_by_owner'),
    sb.rpc('gov_docs_r2277_upcoming_30d'),
    sb.rpc('gov_docs_r2277_recent_events', { p_limit: 30 }),
    sb.rpc('gov_docs_r2277_status_mix'),
  ]);

  const summary = (summaryRes.data ?? [])[0] ?? {
    total_docs: 0,
    overdue: 0,
    due_in_7d: 0,
    due_in_30d: 0,
    filed: 0,
    drafting: 0,
    review: 0,
    critical_pending: 0,
    total_penalty_exposure_rupees: 0,
  };
  const list = listRes.data ?? [];
  const byReg = byRegRes.data ?? [];
  const byOwner = byOwnerRes.data ?? [];
  const upcoming = upcomingRes.data ?? [];
  const events = eventsRes.data ?? [];
  const mix = mixRes.data ?? [];

  const listCols: Column<any>[] = [
    { key: 'doc_code', header: 'Code', render: (r) => <span className="font-mono text-xs">{r.doc_code}</span> },
    { key: 'doc_title', header: 'Title', render: (r) => (
      <div className="flex items-center gap-1">
        {r.is_critical ? <span className="text-red-600">*</span> : null}
        <span>{r.doc_title}</span>
      </div>
    ) },
    { key: 'regulator', header: 'Regulator', render: (r) => <span className="uppercase text-xs">{r.regulator}</span> },
    { key: 'owner_role', header: 'Owner', render: (r) => (
      <div className="text-xs">
        <div>{r.owner_role}</div>
        <div className="text-gray-500">{r.owner_email ?? '-'}</div>
      </div>
    ) },
    { key: 'frequency', header: 'Freq', render: (r: any) => String(r.frequency ?? '') },
    { key: 'next_due_on', header: 'Due', render: (r) => r.next_due_on ?? '-' },
    { key: 'days_until_due', header: 'Days', render: (r) => {
      if (r.days_until_due === null || r.days_until_due === undefined) return '-';
      const cls = r.days_until_due < 0 ? 'text-red-600 font-semibold' : r.days_until_due <= 7 ? 'text-orange-600' : 'text-gray-700';
      return <span className={cls}>{r.days_until_due}</span>;
    } },
    { key: 'current_status', header: 'Status', render: (r) => {
      const s = r.current_status;
      const cls = s === 'filed' ? 'bg-green-100 text-green-800'
        : s === 'overdue' ? 'bg-red-100 text-red-800'
        : s === 'signed' ? 'bg-blue-100 text-blue-800'
        : s === 'review' ? 'bg-amber-100 text-amber-800'
        : 'bg-gray-100 text-gray-800';
      return <span className={`px-2 py-1 rounded text-xs ${cls}`}>{s}</span>;
    } },
    { key: 'penalty_if_overdue_rupees', header: 'Penalty', render: (r) => r.penalty_if_overdue_rupees ? `₹${r.penalty_if_overdue_rupees.toLocaleString('en-IN')}` : '-' },
  ];

  const regCols: Column<any>[] = [
    { key: 'regulator', header: 'Regulator', render: (r) => <span className="uppercase font-medium">{r.regulator}</span> },
    { key: 'total', header: 'Total', render: (r: any) => String(r.total ?? '') },
    { key: 'filed', header: 'Filed', render: (r) => <span className="text-green-700">{r.filed}</span> },
    { key: 'pending', header: 'Pending', render: (r: any) => String(r.pending ?? '') },
    { key: 'overdue', header: 'Overdue', render: (r) => <span className={r.overdue > 0 ? 'text-red-600 font-semibold' : ''}>{r.overdue}</span> },
    { key: 'next_due_on', header: 'Next Due', render: (r) => r.next_due_on ?? '-' },
  ];

  const ownerCols: Column<any>[] = [
    { key: 'owner_role', header: 'Role', render: (r: any) => String(r.owner_role ?? '') },
    { key: 'owner_email', header: 'Email', render: (r) => <span className="text-xs">{r.owner_email ?? '-'}</span> },
    { key: 'total', header: 'Total', render: (r: any) => String(r.total ?? '') },
    { key: 'pending', header: 'Pending', render: (r: any) => String(r.pending ?? '') },
    { key: 'overdue', header: 'Overdue', render: (r) => <span className={r.overdue > 0 ? 'text-red-600 font-semibold' : ''}>{r.overdue}</span> },
    { key: 'critical_pending', header: 'Critical', render: (r) => <span className={r.critical_pending > 0 ? 'text-orange-600 font-semibold' : ''}>{r.critical_pending}</span> },
  ];

  const upcomingCols: Column<any>[] = [
    { key: 'next_due_on', header: 'Due', render: (r: any) => String(r.next_due_on ?? '') },
    { key: 'days_until_due', header: 'Days', render: (r) => {
      const cls = r.days_until_due <= 0 ? 'text-red-600 font-semibold' : r.days_until_due <= 7 ? 'text-orange-600' : 'text-gray-700';
      return <span className={cls}>{r.days_until_due}</span>;
    } },
    { key: 'doc_code', header: 'Code', render: (r) => <span className="font-mono text-xs">{r.doc_code}</span> },
    { key: 'doc_title', header: 'Title', render: (r: any) => String(r.doc_title ?? '') },
    { key: 'regulator', header: 'Regulator', render: (r) => <span className="uppercase text-xs">{r.regulator}</span> },
    { key: 'owner_role', header: 'Owner', render: (r: any) => String(r.owner_role ?? '') },
    { key: 'current_status', header: 'Status', render: (r: any) => String(r.current_status ?? '') },
    { key: 'is_critical', header: 'Critical', render: (r) => r.is_critical ? <span className="text-red-600">YES</span> : '-' },
  ];

  const eventCols: Column<any>[] = [
    { key: 'created_at', header: 'When', render: (r) => new Date(r.created_at).toLocaleString('en-IN') },
    { key: 'doc_code', header: 'Doc', render: (r) => <span className="font-mono text-xs">{r.doc_code}</span> },
    { key: 'event_kind', header: 'Event', render: (r: any) => String(r.event_kind ?? '') },
    { key: 'from_status', header: 'From', render: (r) => r.from_status ?? '-' },
    { key: 'to_status', header: 'To', render: (r) => r.to_status ?? '-' },
    { key: 'actor_email', header: 'Actor', render: (r) => <span className="text-xs">{r.actor_email ?? '-'}</span> },
    { key: 'note', header: 'Note', render: (r) => <span className="text-xs">{r.note ?? '-'}</span> },
  ];

  const mixCols: Column<any>[] = [
    { key: 'current_status', header: 'Status', render: (r: any) => String(r.current_status ?? '') },
    { key: 'doc_count', header: 'Count', render: (r: any) => String(r.doc_count ?? '') },
    { key: 'pct_of_total', header: '%', render: (r) => `${r.pct_of_total}%` },
  ];

  return (
    <main className="p-6 space-y-6 max-w-7xl mx-auto">
      <div>
        <h1 className="text-2xl font-bold">Governance Docs Status</h1>
        <p className="text-sm text-gray-600">Board minutes, share resolutions, statutory filings & due-date tracker</p>
      </div>

      <div className="grid grid-cols-2 md:grid-cols-4 gap-3">
        <div className="border rounded p-4">
          <div className="text-xs text-gray-500">Total Docs</div>
          <div className="text-2xl font-bold">{summary.total_docs}</div>
        </div>
        <div className="border rounded p-4 bg-red-50">
          <div className="text-xs text-gray-500">Overdue</div>
          <div className="text-2xl font-bold text-red-700">{summary.overdue}</div>
        </div>
        <div className="border rounded p-4 bg-orange-50">
          <div className="text-xs text-gray-500">Due in 7d</div>
          <div className="text-2xl font-bold text-orange-700">{summary.due_in_7d}</div>
        </div>
        <div className="border rounded p-4 bg-amber-50">
          <div className="text-xs text-gray-500">Due in 30d</div>
          <div className="text-2xl font-bold text-amber-700">{summary.due_in_30d}</div>
        </div>
        <div className="border rounded p-4 bg-green-50">
          <div className="text-xs text-gray-500">Filed</div>
          <div className="text-2xl font-bold text-green-700">{summary.filed}</div>
        </div>
        <div className="border rounded p-4">
          <div className="text-xs text-gray-500">Drafting</div>
          <div className="text-2xl font-bold">{summary.drafting}</div>
        </div>
        <div className="border rounded p-4">
          <div className="text-xs text-gray-500">In Review</div>
          <div className="text-2xl font-bold">{summary.review}</div>
        </div>
        <div className="border rounded p-4 bg-red-50">
          <div className="text-xs text-gray-500">Penalty Exposure</div>
          <div className="text-2xl font-bold text-red-700">₹{Number(summary.total_penalty_exposure_rupees).toLocaleString('en-IN')}</div>
        </div>
      </div>

      <section>
        <h2 className="text-lg font-semibold mb-2">All governance documents</h2>
        <DataTable columns={listCols} rows={list} rowKey={(_, i) => String(i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Upcoming 30 days</h2>
        <DataTable columns={upcomingCols} rows={upcoming} rowKey={(_, i) => String(i)} />
      </section>

      <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
        <section>
          <h2 className="text-lg font-semibold mb-2">By regulator</h2>
          <DataTable columns={regCols} rows={byReg} rowKey={(_, i) => String(i)} />
        </section>
        <section>
          <h2 className="text-lg font-semibold mb-2">By owner</h2>
          <DataTable columns={ownerCols} rows={byOwner} rowKey={(_, i) => String(i)} />
        </section>
      </div>

      <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
        <section>
          <h2 className="text-lg font-semibold mb-2">Status mix</h2>
          <DataTable columns={mixCols} rows={mix} rowKey={(_, i) => String(i)} />
        </section>
        <section>
          <h2 className="text-lg font-semibold mb-2">Recent events</h2>
          <DataTable columns={eventCols} rows={events} rowKey={(_, i) => String(i)} />
        </section>
      </div>
    </main>
  );
}
