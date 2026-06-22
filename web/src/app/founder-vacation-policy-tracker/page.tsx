import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type Policy = {
  id: string;
  year: number;
  allocated_days: number;
  taken_days: number;
  planned_days: number;
  status: string;
  recorded_at: string;
  last_reviewed_at: string | null;
};

type LogRow = {
  id: string;
  policy_id: string;
  action_type: string;
  taken_at: string | null;
  by_email: string | null;
  notes_md: string | null;
  created_at: string;
};

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const policiesRes = await sb.rpc('list_policies_r1986');
  const currentRes = await sb.rpc('current_year_status_r1986');
  const recentRes = await sb.rpc('recent_actions_r1986', { p_limit: 25 });

  const policies: Policy[] = (policiesRes.data as Policy[]) ?? [];
  const current: Policy[] = (currentRes.data as Policy[]) ?? [];
  const recent: LogRow[] = (recentRes.data as LogRow[]) ?? [];

  const policyCols: Column<Policy>[] = [
    { key: 'year', header: 'Year', render: (r: any) => String(r.year ?? '') },
    { key: 'allocated_days', header: 'Allocated', render: (r: any) => String(r.allocated_days ?? 0) },
    { key: 'taken_days', header: 'Taken', render: (r: any) => String(r.taken_days ?? 0) },
    { key: 'planned_days', header: 'Planned', render: (r: any) => String(r.planned_days ?? 0) },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
    { key: 'recorded_at', header: 'Recorded', render: (r: any) => r.recorded_at ? new Date(r.recorded_at).toLocaleString() : '' },
    { key: 'last_reviewed_at', header: 'Last Review', render: (r: any) => r.last_reviewed_at ? new Date(r.last_reviewed_at).toLocaleString() : '' },
  ];

  const currentCols: Column<Policy>[] = [
    { key: 'year', header: 'Year', render: (r: any) => String(r.year ?? '') },
    { key: 'allocated_days', header: 'Allocated', render: (r: any) => String(r.allocated_days ?? 0) },
    { key: 'taken_days', header: 'Taken', render: (r: any) => String(r.taken_days ?? 0) },
    { key: 'planned_days', header: 'Planned', render: (r: any) => String(r.planned_days ?? 0) },
    { key: 'remaining', header: 'Remaining', render: (r: any) => String((r.allocated_days ?? 0) - (r.taken_days ?? 0) - (r.planned_days ?? 0)) },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
  ];

  const logCols: Column<LogRow>[] = [
    { key: 'created_at', header: 'When', render: (r: any) => r.created_at ? new Date(r.created_at).toLocaleString() : '' },
    { key: 'action_type', header: 'Action', render: (r: any) => String(r.action_type ?? '') },
    { key: 'taken_at', header: 'Date', render: (r: any) => r.taken_at ? String(r.taken_at) : '' },
    { key: 'by_email', header: 'By', render: (r: any) => String(r.by_email ?? '') },
    { key: 'notes_md', header: 'Notes', render: (r: any) => String(r.notes_md ?? '') },
  ];

  return (
    <main className="p-6 space-y-8">
      <header>
        <h1 className="text-2xl font-semibold">Founder Vacation Policy Tracker</h1>
        <p className="text-sm text-gray-600">Track founder vacation days taken and planned against allocated.</p>
      </header>

      <section>
        <h2 className="text-lg font-medium mb-3">Current year status</h2>
        <DataTable
          rows={current}
          columns={currentCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-medium mb-3">All policies</h2>
        <DataTable
          rows={policies}
          columns={policyCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-medium mb-3">Recent actions</h2>
        <DataTable
          rows={recent}
          columns={logCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>
    </main>
  );
}
