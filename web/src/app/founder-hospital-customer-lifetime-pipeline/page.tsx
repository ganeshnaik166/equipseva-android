import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const sb = await getSupabaseServerClient();
  const [lifetimes, actions, atRisk, recent] = await Promise.all([
    sb.rpc('list_lifetimes_r1987'),
    sb.rpc('list_actions_r1987'),
    sb.rpc('at_risk_customers_r1987'),
    sb.rpc('recent_actions_r1987'),
  ]);

  const lifetimeCols: Column<any>[] = [
    { key: 'hospital_id', header: 'Hospital', render: (r: any) => String(r.hospital_id ?? '').slice(0, 8) },
    { key: 'lifetime_stage', header: 'Stage', render: (r: any) => String(r.lifetime_stage ?? '') },
    { key: 'stage_duration_days', header: 'Days in stage', render: (r: any) => String(r.stage_duration_days ?? 0) },
    { key: 'total_lifetime_value_rupees', header: 'LTV (rupees)', render: (r: any) => String(r.total_lifetime_value_rupees ?? 0) },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
    { key: 'captured_at', header: 'Captured', render: (r: any) => r.captured_at ? new Date(r.captured_at).toLocaleString() : '' },
  ];

  const actionCols: Column<any>[] = [
    { key: 'stage_id', header: 'Stage', render: (r: any) => String(r.stage_id ?? '').slice(0, 8) },
    { key: 'action_type', header: 'Action', render: (r: any) => String(r.action_type ?? '') },
    { key: 'taken_at', header: 'Taken', render: (r: any) => r.taken_at ? new Date(r.taken_at).toLocaleString() : '' },
    { key: 'by_email', header: 'By', render: (r: any) => String(r.by_email ?? '') },
    { key: 'notes_md', header: 'Notes', render: (r: any) => String(r.notes_md ?? '').slice(0, 60) },
  ];

  const atRiskCols: Column<any>[] = [
    { key: 'hospital_id', header: 'Hospital', render: (r: any) => String(r.hospital_id ?? '').slice(0, 8) },
    { key: 'lifetime_stage', header: 'Stage', render: (r: any) => String(r.lifetime_stage ?? '') },
    { key: 'stage_duration_days', header: 'Days', render: (r: any) => String(r.stage_duration_days ?? 0) },
    { key: 'total_lifetime_value_rupees', header: 'LTV', render: (r: any) => String(r.total_lifetime_value_rupees ?? 0) },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
  ];

  const recentCols: Column<any>[] = [
    { key: 'action_type', header: 'Action', render: (r: any) => String(r.action_type ?? '') },
    { key: 'taken_at', header: 'Taken', render: (r: any) => r.taken_at ? new Date(r.taken_at).toLocaleString() : '' },
    { key: 'by_email', header: 'By', render: (r: any) => String(r.by_email ?? '') },
  ];

  return (
    <div className="p-6 space-y-8">
      <header>
        <h1 className="text-2xl font-semibold">Hospital Customer Lifetime Pipeline</h1>
        <p className="text-sm text-gray-600">Track customer lifetime stages and intervention actions per hospital account.</p>
      </header>

      <section>
        <h2 className="text-lg font-medium mb-2">Lifetime stages</h2>
        <DataTable rows={lifetimes.data ?? []} columns={lifetimeCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-medium mb-2">At-risk and dormant customers</h2>
        <DataTable rows={atRisk.data ?? []} columns={atRiskCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-medium mb-2">Action log</h2>
        <DataTable rows={actions.data ?? []} columns={actionCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-medium mb-2">Recent actions (last 30 days)</h2>
        <DataTable rows={recent.data ?? []} columns={recentCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>
    </div>
  );
}
