import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [optsRes, proposedRes, recentRes] = await Promise.all([
    sb.rpc('list_optimizations_r2059', { p_limit: 100 }),
    sb.rpc('proposed_optimizations_r2059'),
    sb.rpc('recent_actions_r2059', { p_days: 30 }),
  ]);

  const opts: any[] = Array.isArray(optsRes.data) ? optsRes.data : [];
  const proposed: any[] = Array.isArray(proposedRes.data) ? proposedRes.data : [];
  const recent: any[] = Array.isArray(recentRes.data) ? recentRes.data : [];

  const optCols: Column<any>[] = [
    { key: 'hospital_name', header: 'Hospital', render: (r: any) => String(r.hospital_name ?? '') },
    { key: 'current', header: 'Current Window', render: (r: any) => `${r.current_window_start ?? ''} to ${r.current_window_end ?? ''}` },
    { key: 'proposed', header: 'Proposed Window', render: (r: any) => `${r.proposed_window_start ?? ''} to ${r.proposed_window_end ?? ''}` },
    { key: 'gain', header: 'Expected Gain', render: (r: any) => `${Number(r.expected_efficiency_gain_pct ?? 0).toFixed(2)} percent` },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
    { key: 'captured_at', header: 'Captured', render: (r: any) => r.captured_at ? new Date(r.captured_at).toLocaleString() : '' },
  ];

  const proposedCols: Column<any>[] = [
    { key: 'hospital_name', header: 'Hospital', render: (r: any) => String(r.hospital_name ?? '') },
    { key: 'proposed', header: 'Proposed Window', render: (r: any) => `${r.proposed_window_start ?? ''} to ${r.proposed_window_end ?? ''}` },
    { key: 'gain', header: 'Expected Gain', render: (r: any) => `${Number(r.expected_efficiency_gain_pct ?? 0).toFixed(2)} percent` },
    { key: 'captured_at', header: 'Captured', render: (r: any) => r.captured_at ? new Date(r.captured_at).toLocaleString() : '' },
  ];

  const recentCols: Column<any>[] = [
    { key: 'taken_at', header: 'Taken', render: (r: any) => r.taken_at ? new Date(r.taken_at).toLocaleString() : '' },
    { key: 'action_type', header: 'Action', render: (r: any) => String(r.action_type ?? '') },
    { key: 'by_email', header: 'By', render: (r: any) => String(r.by_email ?? '') },
    { key: 'notes_md', header: 'Notes', render: (r: any) => String(r.notes_md ?? '') },
    { key: 'optimization_id', header: 'Optimization', render: (r: any) => String(r.optimization_id ?? '').slice(0, 8) },
  ];

  return (
    <main className="p-6 space-y-8">
      <header>
        <h1 className="text-2xl font-semibold">Hospital Service Window Optimization</h1>
        <p className="text-sm text-gray-600 mt-1">
          Optimize hospital service windows. Track proposals, expected efficiency gains, and adoption actions.
        </p>
      </header>

      <section>
        <h2 className="text-lg font-medium mb-3">All Optimizations</h2>
        <DataTable
          rows={opts}
          columns={optCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-medium mb-3">Proposed Windows (Pending Decision)</h2>
        <DataTable
          rows={proposed}
          columns={proposedCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-medium mb-3">Recent Actions (30 days)</h2>
        <DataTable
          rows={recent}
          columns={recentCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>
    </main>
  );
}
