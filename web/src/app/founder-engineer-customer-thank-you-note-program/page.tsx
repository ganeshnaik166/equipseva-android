import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const supabase = await getSupabaseServerClient();
  const [notes, actions, topEngineers, kindDist, monthlyTrend, responseRate, ownerLoad] = await Promise.all([
    supabase.rpc('list_notes_r2622'),
    supabase.rpc('list_followup_actions_r2622'),
    supabase.rpc('top_response_engineers_r2622'),
    supabase.rpc('note_kind_distribution_r2622'),
    supabase.rpc('monthly_note_trend_r2622'),
    supabase.rpc('response_rate_summary_r2622'),
    supabase.rpc('owner_load_r2622'),
  ]);

  const noteCols: Column<any>[] = [
    { key: 'sent_at', header: 'Sent At', render: (r: any) => new Date(r.sent_at).toLocaleDateString() },
    { key: 'note_kind', header: 'Kind', render: (r: any) => r.note_kind },
    { key: 'trigger_event_kind', header: 'Trigger', render: (r: any) => r.trigger_event_kind },
    { key: 'response_received', header: 'Responded', render: (r: any) => (r.response_received ? 'yes' : 'no') },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email ?? '' },
    { key: 'customer_response_md', header: 'Response', render: (r: any) => r.customer_response_md ?? '' },
    { key: 'notes', header: 'Notes', render: (r: any) => r.notes ?? '' },
  ];

  const actionCols: Column<any>[] = [
    { key: 'action_at', header: 'Action At', render: (r: any) => new Date(r.action_at).toLocaleDateString() },
    { key: 'action_kind', header: 'Kind', render: (r: any) => r.action_kind },
    { key: 'outcome', header: 'Outcome', render: (r: any) => r.outcome },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email ?? '' },
    { key: 'notes', header: 'Notes', render: (r: any) => r.notes ?? '' },
  ];

  const topCols: Column<any>[] = [
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email ?? '' },
    { key: 'sent_count', header: 'Sent', render: (r: any) => r.sent_count },
    { key: 'response_count', header: 'Responses', render: (r: any) => r.response_count },
  ];

  const kindCols: Column<any>[] = [
    { key: 'note_kind', header: 'Kind', render: (r: any) => r.note_kind },
    { key: 'cnt', header: 'Count', render: (r: any) => r.cnt },
  ];

  const trendCols: Column<any>[] = [
    { key: 'month_start', header: 'Month', render: (r: any) => new Date(r.month_start).toLocaleDateString() },
    { key: 'cnt', header: 'Sent', render: (r: any) => r.cnt },
    { key: 'response_cnt', header: 'Responses', render: (r: any) => r.response_cnt },
  ];

  const ownerCols: Column<any>[] = [
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email ?? '' },
    { key: 'open_notes', header: 'Open Notes', render: (r: any) => r.open_notes },
    { key: 'open_actions', header: 'Open Actions', render: (r: any) => r.open_actions },
  ];

  const rr = (responseRate.data ?? [])[0] ?? { total_notes: 0, responded: 0, no_response: 0, planned: 0, sent_status: 0 };

  return (
    <div className="p-6 space-y-6">
      <h1 className="text-2xl font-bold">Engineer & Customer Thank-You Note Program</h1>
      <p className="text-sm text-gray-600">Track thank-you notes sent by engineers to hospital customers =&gt; warmer relationships, more renewals.</p>

      <section className="grid grid-cols-2 md:grid-cols-5 gap-3">
        <div className="border rounded p-3"><div className="text-xs text-gray-500">Total Notes</div><div className="text-xl font-bold">{rr.total_notes}</div></div>
        <div className="border rounded p-3"><div className="text-xs text-gray-500">Responded</div><div className="text-xl font-bold">{rr.responded}</div></div>
        <div className="border rounded p-3"><div className="text-xs text-gray-500">No Response</div><div className="text-xl font-bold">{rr.no_response}</div></div>
        <div className="border rounded p-3"><div className="text-xs text-gray-500">Planned</div><div className="text-xl font-bold">{rr.planned}</div></div>
        <div className="border rounded p-3"><div className="text-xs text-gray-500">Sent</div><div className="text-xl font-bold">{rr.sent_status}</div></div>
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Thank-You Notes</h2>
        <DataTable rows={notes.data ?? []} columns={noteCols} emptyMessage="No notes" rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Follow-Up Actions</h2>
        <DataTable rows={actions.data ?? []} columns={actionCols} emptyMessage="No actions" rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section className="grid grid-cols-1 md:grid-cols-2 gap-6">
        <div>
          <h2 className="text-lg font-semibold mb-2">Top Engineers by Response</h2>
          <DataTable rows={topEngineers.data ?? []} columns={topCols} emptyMessage="No data" rowKey={(r: any, i: number) => String(r.owner_email ?? i)} />
        </div>
        <div>
          <h2 className="text-lg font-semibold mb-2">Note Kind Distribution</h2>
          <DataTable rows={kindDist.data ?? []} columns={kindCols} emptyMessage="No data" rowKey={(r: any, i: number) => String(r.note_kind ?? i)} />
        </div>
      </section>

      <section className="grid grid-cols-1 md:grid-cols-2 gap-6">
        <div>
          <h2 className="text-lg font-semibold mb-2">Monthly Trend</h2>
          <DataTable rows={monthlyTrend.data ?? []} columns={trendCols} emptyMessage="No data" rowKey={(r: any, i: number) => String(r.month_start ?? i)} />
        </div>
        <div>
          <h2 className="text-lg font-semibold mb-2">Owner Load</h2>
          <DataTable rows={ownerLoad.data ?? []} columns={ownerCols} emptyMessage="No data" rowKey={(r: any, i: number) => String(r.owner_email ?? i)} />
        </div>
      </section>
    </div>
  );
}
