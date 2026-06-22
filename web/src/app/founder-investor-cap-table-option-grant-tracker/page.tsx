import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [grantsRes, activeRes, recentRes] = await Promise.all([
    sb.rpc('list_grants_r2177'),
    sb.rpc('active_grants_r2177'),
    sb.rpc('recent_actions_r2177'),
  ]);

  const grants: any[] = Array.isArray(grantsRes.data) ? grantsRes.data : [];
  const active: any[] = Array.isArray(activeRes.data) ? activeRes.data : [];
  const recent: any[] = Array.isArray(recentRes.data) ? recentRes.data : [];

  const grantCols: Column<any>[] = [
    { key: 'grantee_label', header: 'Grantee', render: (r: any) => String(r.grantee_label ?? '') },
    { key: 'grant_type', header: 'Type', render: (r: any) => String(r.grant_type ?? '') },
    { key: 'total_options', header: 'Options', render: (r: any) => String(r.total_options ?? 0) },
    { key: 'exercise_price_rupees', header: 'Exercise Price (Rs)', render: (r: any) => String(r.exercise_price_rupees ?? 0) },
    { key: 'vesting_start_date', header: 'Vesting Start', render: (r: any) => String(r.vesting_start_date ?? '') },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
    { key: 'captured_at', header: 'Captured', render: (r: any) => r.captured_at ? new Date(r.captured_at).toLocaleString() : '' },
  ];

  const activeCols: Column<any>[] = [
    { key: 'grantee_label', header: 'Grantee', render: (r: any) => String(r.grantee_label ?? '') },
    { key: 'grant_type', header: 'Type', render: (r: any) => String(r.grant_type ?? '') },
    { key: 'total_options', header: 'Options', render: (r: any) => String(r.total_options ?? 0) },
    { key: 'exercise_price_rupees', header: 'Price (Rs)', render: (r: any) => String(r.exercise_price_rupees ?? 0) },
    { key: 'vesting_start_date', header: 'Vesting Start', render: (r: any) => String(r.vesting_start_date ?? '') },
    { key: 'captured_at', header: 'Captured', render: (r: any) => r.captured_at ? new Date(r.captured_at).toLocaleString() : '' },
  ];

  const actionCols: Column<any>[] = [
    { key: 'action_type', header: 'Action', render: (r: any) => String(r.action_type ?? '') },
    { key: 'grant_id', header: 'Grant', render: (r: any) => String(r.grant_id ?? '').slice(0, 8) },
    { key: 'by_email', header: 'By', render: (r: any) => String(r.by_email ?? '') },
    { key: 'options_change', header: 'Change', render: (r: any) => String(r.options_change ?? 0) },
    { key: 'taken_at', header: 'Taken', render: (r: any) => r.taken_at ? new Date(r.taken_at).toLocaleString() : '' },
    { key: 'notes_md', header: 'Notes', render: (r: any) => String(r.notes_md ?? '') },
  ];

  return (
    <div className="p-6 space-y-8">
      <header>
        <h1 className="text-2xl font-bold">Investor Cap Table Option Grant Tracker</h1>
        <p className="text-sm text-gray-600">Round r2177 — track option grants per recipient, status, and lifecycle actions.</p>
      </header>

      <section>
        <h2 className="text-lg font-semibold mb-2">All Grants ({grants.length})</h2>
        <DataTable rows={grants} columns={grantCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Active Grants ({active.length})</h2>
        <DataTable rows={active} columns={activeCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Recent Actions ({recent.length})</h2>
        <DataTable rows={recent} columns={actionCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>
    </div>
  );
}
