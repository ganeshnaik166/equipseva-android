import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type Cadence = {
  id: string;
  cadence_label: string;
  cadence_frequency: string;
  target_dow: string | null;
  target_time: string | null;
  last_executed_at: string | null;
  next_due_at: string | null;
  status: string;
  owner_email: string | null;
};

type Execution = {
  id: string;
  cadence_id: string;
  executed_at: string;
  outcome: string;
  by_email: string | null;
  notes_md: string | null;
};

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [cadencesRes, dueRes, recentRes] = await Promise.all([
    sb.rpc('list_cadences_r1934'),
    sb.rpc('due_or_overdue_r1934'),
    sb.rpc('recent_executions_r1934', { p_limit: 50 }),
  ]);

  const cadences: Cadence[] = (cadencesRes.data as Cadence[]) || [];
  const due: Cadence[] = (dueRes.data as Cadence[]) || [];
  const recent: Execution[] = (recentRes.data as Execution[]) || [];

  const cadenceCols: Column<Cadence>[] = [
    { key: 'cadence_label', header: 'Cadence', render: (r: any) => r.cadence_label || '—' },
    { key: 'cadence_frequency', header: 'Frequency', render: (r: any) => r.cadence_frequency || '—' },
    { key: 'target_dow', header: 'Target DOW', render: (r: any) => r.target_dow || '—' },
    { key: 'target_time', header: 'Target time', render: (r: any) => r.target_time || '—' },
    { key: 'next_due_at', header: 'Next due', render: (r: any) => r.next_due_at ? new Date(r.next_due_at).toLocaleString() : '—' },
    { key: 'last_executed_at', header: 'Last run', render: (r: any) => r.last_executed_at ? new Date(r.last_executed_at).toLocaleString() : '—' },
    { key: 'status', header: 'Status', render: (r: any) => r.status || '—' },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email || '—' },
  ];

  const dueCols: Column<Cadence>[] = [
    { key: 'cadence_label', header: 'Cadence', render: (r: any) => r.cadence_label || '—' },
    { key: 'cadence_frequency', header: 'Frequency', render: (r: any) => r.cadence_frequency || '—' },
    { key: 'next_due_at', header: 'Next due', render: (r: any) => r.next_due_at ? new Date(r.next_due_at).toLocaleString() : '—' },
    { key: 'status', header: 'Status', render: (r: any) => r.status || '—' },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email || '—' },
  ];

  const execCols: Column<Execution>[] = [
    { key: 'executed_at', header: 'Executed at', render: (r: any) => r.executed_at ? new Date(r.executed_at).toLocaleString() : '—' },
    { key: 'cadence_id', header: 'Cadence', render: (r: any) => r.cadence_id || '—' },
    { key: 'outcome', header: 'Outcome', render: (r: any) => r.outcome || '—' },
    { key: 'by_email', header: 'By', render: (r: any) => r.by_email || '—' },
    { key: 'notes_md', header: 'Notes', render: (r: any) => r.notes_md || '—' },
  ];

  return (
    <main className="p-6 space-y-8">
      <header>
        <h1 className="text-2xl font-semibold">Founder Operating Cadence Health</h1>
        <p className="text-sm text-gray-600">Track adherence to recurring founder cadences. Items due within 3 days surface as due soon or overdue.</p>
      </header>

      <section>
        <h2 className="text-lg font-semibold mb-2">Due or overdue</h2>
        <p className="text-sm text-gray-600 mb-2">Cadences flagged due soon, overdue, or scheduled within 3 days.</p>
        <DataTable rows={due} columns={dueCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">All cadences</h2>
        <p className="text-sm text-gray-600 mb-2">Daily, weekly, biweekly, monthly, quarterly, and annual cadences.</p>
        <DataTable rows={cadences} columns={cadenceCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Recent executions</h2>
        <p className="text-sm text-gray-600 mb-2">Last 50 execution events across all cadences.</p>
        <DataTable rows={recent} columns={execCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>
    </main>
  );
}
