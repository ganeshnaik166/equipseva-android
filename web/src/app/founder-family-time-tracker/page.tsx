import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function FounderFamilyTimeTrackerPage() {
  const sb = await getSupabaseServerClient();

  const [periodsRes, shortRes, recentRes] = await Promise.all([
    sb.rpc('list_family_periods_r2158'),
    sb.rpc('short_family_periods_r2158'),
    sb.rpc('recent_family_actions_r2158'),
  ]);

  const periods: any[] = Array.isArray(periodsRes.data) ? periodsRes.data : [];
  const shorts: any[] = Array.isArray(shortRes.data) ? shortRes.data : [];
  const recent: any[] = Array.isArray(recentRes.data) ? recentRes.data : [];

  const periodCols: Column<any>[] = [
    { key: 'period_label', header: 'Period', render: (r: any) => String(r.period_label ?? '') },
    { key: 'planned_family_hours', header: 'Planned hrs', render: (r: any) => String(r.planned_family_hours ?? 0) },
    { key: 'actual_family_hours', header: 'Actual hrs', render: (r: any) => String(r.actual_family_hours ?? 0) },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
    { key: 'captured_at', header: 'Captured', render: (r: any) => r.captured_at ? new Date(r.captured_at).toLocaleString() : '' },
  ];

  const shortCols: Column<any>[] = [
    { key: 'period_label', header: 'Period', render: (r: any) => String(r.period_label ?? '') },
    { key: 'planned_family_hours', header: 'Planned', render: (r: any) => String(r.planned_family_hours ?? 0) },
    { key: 'actual_family_hours', header: 'Actual', render: (r: any) => String(r.actual_family_hours ?? 0) },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
  ];

  const actionCols: Column<any>[] = [
    { key: 'action_type', header: 'Action', render: (r: any) => String(r.action_type ?? '') },
    { key: 'by_email', header: 'By', render: (r: any) => String(r.by_email ?? '') },
    { key: 'taken_at', header: 'Taken', render: (r: any) => r.taken_at ? new Date(r.taken_at).toLocaleString() : '' },
    { key: 'notes_md', header: 'Notes', render: (r: any) => String(r.notes_md ?? '') },
  ];

  return (
    <main className="p-6 space-y-8">
      <header>
        <h1 className="text-2xl font-semibold">Founder Family Time Tracker</h1>
        <p className="text-sm text-gray-600">Plan family hours, log actual hours, protect non-negotiable family time.</p>
      </header>

      <section>
        <h2 className="text-lg font-medium mb-2">All Periods</h2>
        <DataTable rows={periods} columns={periodCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-medium mb-2">Short or Severely Short Periods</h2>
        <DataTable rows={shorts} columns={shortCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-medium mb-2">Recent Action Log</h2>
        <DataTable rows={recent} columns={actionCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>
    </main>
  );
}
