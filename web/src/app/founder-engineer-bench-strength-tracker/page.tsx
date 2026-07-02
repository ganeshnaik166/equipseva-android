import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [benchesRes, thinRes, actionsRes] = await Promise.all([
    sb.rpc('list_benches_r2008'),
    sb.rpc('thin_benches_r2008'),
    sb.rpc('recent_actions_r2008', { p_limit: 50 }),
  ]);

  const benches: any[] = Array.isArray(benchesRes.data) ? benchesRes.data : [];
  const thin: any[] = Array.isArray(thinRes.data) ? thinRes.data : [];
  const actions: any[] = Array.isArray(actionsRes.data) ? actionsRes.data : [];

  const benchCols: Column<any>[] = [
    { key: 'region_label', header: 'Region', render: (r: any) => String(r.region_label ?? '') },
    { key: 'specialty', header: 'Specialty', render: (r: any) => String(r.specialty ?? '') },
    { key: 'active_engineers', header: 'Active engineers', render: (r: any) => String(r.active_engineers ?? 0) },
    { key: 'available_capacity', header: 'Available capacity', render: (r: any) => String(r.available_capacity ?? 0) },
    { key: 'demand_score', header: 'Demand score', render: (r: any) => String(r.demand_score ?? 0) },
    { key: 'bench_status', header: 'Status', render: (r: any) => String(r.bench_status ?? '') },
    { key: 'captured_at', header: 'Captured', render: (r: any) => r.captured_at ? new Date(r.captured_at).toLocaleString() : '' },
  ];

  const thinCols: Column<any>[] = [
    { key: 'region_label', header: 'Region', render: (r: any) => String(r.region_label ?? '') },
    { key: 'specialty', header: 'Specialty', render: (r: any) => String(r.specialty ?? '') },
    { key: 'bench_status', header: 'Status', render: (r: any) => String(r.bench_status ?? '') },
    { key: 'demand_score', header: 'Demand score', render: (r: any) => String(r.demand_score ?? 0) },
    { key: 'available_capacity', header: 'Capacity', render: (r: any) => String(r.available_capacity ?? 0) },
  ];

  const actionCols: Column<any>[] = [
    { key: 'taken_at', header: 'Taken', render: (r: any) => r.taken_at ? new Date(r.taken_at).toLocaleString() : '' },
    { key: 'action_type', header: 'Action', render: (r: any) => String(r.action_type ?? '') },
    { key: 'by_email', header: 'By', render: (r: any) => String(r.by_email ?? '') },
    { key: 'notes_md', header: 'Notes', render: (r: any) => String(r.notes_md ?? '') },
    { key: 'bench_id', header: 'Bench id', render: (r: any) => String(r.bench_id ?? '') },
  ];

  return (
    <div className="p-6 space-y-8">
      <header>
        <h1 className="text-2xl font-bold">Engineer Bench Strength Tracker</h1>
        <p className="text-sm text-gray-600">Track active engineer pool, available capacity and demand pressure per region and specialty. Flag thin or critical benches early.</p>
      </header>

      <section>
        <h2 className="text-lg font-semibold mb-2">All bench snapshots</h2>
        <DataTable rows={benches} columns={benchCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Thin and critical benches</h2>
        <p className="text-sm text-gray-600 mb-2">Benches where status is thin or critical and demand pressure is high.</p>
        <DataTable rows={thin} columns={thinCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Recent bench actions</h2>
        <DataTable rows={actions} columns={actionCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>
    </div>
  );
}
