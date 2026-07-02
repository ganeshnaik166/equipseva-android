import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function FounderReflectionFrequencyTrackerPage() {
  const sb = await getSupabaseServerClient();

  const [periodsRes, sparseRes, recentRes] = await Promise.all([
    sb.rpc('list_periods_r2154'),
    sb.rpc('sparse_periods_r2154'),
    sb.rpc('recent_actions_r2154'),
  ]);

  const periods: any[] = Array.isArray(periodsRes.data) ? periodsRes.data : [];
  const sparse: any[] = Array.isArray(sparseRes.data) ? sparseRes.data : [];
  const recent: any[] = Array.isArray(recentRes.data) ? recentRes.data : [];

  const periodCols: Column<any>[] = [
    { key: 'period_label', header: 'Period', render: (r: any) => String(r.period_label ?? '') },
    { key: 'reflection_sessions_count', header: 'Sessions', render: (r: any) => String(r.reflection_sessions_count ?? 0) },
    { key: 'avg_session_minutes', header: 'Avg minutes', render: (r: any) => String(r.avg_session_minutes ?? 0) },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
    { key: 'captured_at', header: 'Captured', render: (r: any) => r.captured_at ? new Date(r.captured_at).toLocaleString() : '' },
  ];

  const sparseCols: Column<any>[] = [
    { key: 'period_label', header: 'Period', render: (r: any) => String(r.period_label ?? '') },
    { key: 'reflection_sessions_count', header: 'Sessions', render: (r: any) => String(r.reflection_sessions_count ?? 0) },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
    { key: 'captured_at', header: 'Captured', render: (r: any) => r.captured_at ? new Date(r.captured_at).toLocaleString() : '' },
  ];

  const recentCols: Column<any>[] = [
    { key: 'action_type', header: 'Action', render: (r: any) => String(r.action_type ?? '') },
    { key: 'by_email', header: 'By', render: (r: any) => String(r.by_email ?? '') },
    { key: 'taken_at', header: 'When', render: (r: any) => r.taken_at ? new Date(r.taken_at).toLocaleString() : '' },
    { key: 'notes_md', header: 'Notes', render: (r: any) => String(r.notes_md ?? '') },
  ];

  return (
    <div className="p-6 space-y-8">
      <header>
        <h1 className="text-2xl font-semibold">Founder Reflection Frequency Tracker</h1>
        <p className="text-sm text-gray-600">Track frequency of personal reflection sessions across periods.</p>
      </header>

      <section>
        <h2 className="text-lg font-medium mb-2">All periods</h2>
        <DataTable rows={periods} columns={periodCols} rowKey={(r, i) => String(r.id ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-medium mb-2">Sparse or none</h2>
        <DataTable rows={sparse} columns={sparseCols} rowKey={(r, i) => String(r.id ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-medium mb-2">Recent actions</h2>
        <DataTable rows={recent} columns={recentCols} rowKey={(r, i) => String(r.id ?? i)} />
      </section>
    </div>
  );
}
