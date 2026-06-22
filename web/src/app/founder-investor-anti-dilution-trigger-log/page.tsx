import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [triggersRes, actionsRes, recentTriggersRes] = await Promise.all([
    sb.rpc('list_anti_dilution_triggers_r1965'),
    sb.rpc('list_anti_dilution_actions_r1965', { p_trigger_id: null }),
    sb.rpc('recent_anti_dilution_triggers_r1965', { p_limit: 10 }),
  ]);

  const triggers: any[] = Array.isArray(triggersRes.data) ? triggersRes.data : [];
  const actions: any[] = Array.isArray(actionsRes.data) ? actionsRes.data : [];
  const recent: any[] = Array.isArray(recentTriggersRes.data) ? recentTriggersRes.data : [];

  const finalized = triggers.filter((t) => t.status === 'finalized').length;
  const disputed = triggers.filter((t) => t.status === 'disputed').length;
  const pending = triggers.filter((t) => t.status === 'triggered' || t.status === 'calculating').length;

  const triggerCols: Column<any>[] = [
    { key: 'trigger_event_at', header: 'When', render: (r: any) => new Date(r.trigger_event_at).toLocaleString() },
    { key: 'trigger_event_label', header: 'Event', render: (r: any) => r.trigger_event_label },
    { key: 'investor_id', header: 'Investor', render: (r: any) => String(r.investor_id).slice(0, 8) },
    { key: 'anti_dilution_type', header: 'Type', render: (r: any) => r.anti_dilution_type },
    { key: 'shares_added_to_investor', header: 'Shares added', render: (r: any) => Number(r.shares_added_to_investor ?? 0).toLocaleString() },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'finalized_at', header: 'Finalized', render: (r: any) => r.finalized_at ? new Date(r.finalized_at).toLocaleString() : '—' },
  ];

  const actionCols: Column<any>[] = [
    { key: 'taken_at', header: 'When', render: (r: any) => new Date(r.taken_at).toLocaleString() },
    { key: 'trigger_id', header: 'Trigger', render: (r: any) => String(r.trigger_id).slice(0, 8) },
    { key: 'action_type', header: 'Action', render: (r: any) => r.action_type },
    { key: 'by_email', header: 'By', render: (r: any) => r.by_email ?? '—' },
    { key: 'notes_md', header: 'Notes', render: (r: any) => r.notes_md ? String(r.notes_md).slice(0, 80) : '—' },
  ];

  const recentCols: Column<any>[] = [
    { key: 'trigger_event_at', header: 'When', render: (r: any) => new Date(r.trigger_event_at).toLocaleString() },
    { key: 'trigger_event_label', header: 'Event', render: (r: any) => r.trigger_event_label },
    { key: 'anti_dilution_type', header: 'Type', render: (r: any) => r.anti_dilution_type },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
  ];

  return (
    <main className="p-6 space-y-8">
      <header>
        <h1 className="text-2xl font-bold">Investor Anti-Dilution Trigger Log</h1>
        <p className="text-sm text-gray-600">Log when anti-dilution clauses trigger and track follow-up actions.</p>
      </header>

      <section className="grid grid-cols-1 md:grid-cols-3 gap-4">
        <div className="border rounded p-4">
          <div className="text-xs uppercase text-gray-500">Finalized</div>
          <div className="text-2xl font-semibold">{finalized}</div>
        </div>
        <div className="border rounded p-4">
          <div className="text-xs uppercase text-gray-500">Pending (triggered and calculating)</div>
          <div className="text-2xl font-semibold">{pending}</div>
        </div>
        <div className="border rounded p-4">
          <div className="text-xs uppercase text-gray-500">Disputed</div>
          <div className="text-2xl font-semibold">{disputed}</div>
        </div>
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-3">All triggers</h2>
        <DataTable rows={triggers} columns={triggerCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-3">Action log</h2>
        <DataTable rows={actions} columns={actionCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-3">Recent triggers (top 10)</h2>
        <DataTable rows={recent} columns={recentCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>
    </main>
  );
}
