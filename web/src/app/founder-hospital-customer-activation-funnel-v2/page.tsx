import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [funnelsRes, stalledRes, recentRes] = await Promise.all([
    sb.rpc('list_hospital_activation_funnels_r2147', { p_limit: 100 }),
    sb.rpc('list_stalled_hospital_activations_r2147'),
    sb.rpc('list_recent_hospital_activation_actions_r2147', { p_limit: 50 }),
  ]);

  const funnels = (funnelsRes.data ?? []) as any[];
  const stalled = (stalledRes.data ?? []) as any[];
  const recent = (recentRes.data ?? []) as any[];

  const funnelColumns: Column<any>[] = [
    { key: 'hospital_id', header: 'Hospital', render: (r: any) => String(r.hospital_id ?? '').slice(0, 8) },
    { key: 'signed_at', header: 'Signed', render: (r: any) => (r.signed_at ? new Date(r.signed_at).toLocaleDateString() : 'pending') },
    { key: 'first_repair_at', header: 'First Repair', render: (r: any) => (r.first_repair_at ? new Date(r.first_repair_at).toLocaleDateString() : 'none yet') },
    { key: 'days_to_first_repair', header: 'Days to First', render: (r: any) => (r.days_to_first_repair ?? 'n/a') },
    { key: 'activation_status', header: 'Status', render: (r: any) => String(r.activation_status ?? '') },
    { key: 'captured_at', header: 'Captured', render: (r: any) => (r.captured_at ? new Date(r.captured_at).toLocaleString() : '') },
  ];

  const stalledColumns: Column<any>[] = [
    { key: 'hospital_id', header: 'Hospital', render: (r: any) => String(r.hospital_id ?? '').slice(0, 8) },
    { key: 'signed_at', header: 'Signed', render: (r: any) => (r.signed_at ? new Date(r.signed_at).toLocaleDateString() : '') },
    { key: 'days_to_first_repair', header: 'Days Elapsed', render: (r: any) => (r.days_to_first_repair ?? 'n/a') },
    { key: 'activation_status', header: 'Status', render: (r: any) => String(r.activation_status ?? '') },
    { key: 'captured_at', header: 'Captured', render: (r: any) => (r.captured_at ? new Date(r.captured_at).toLocaleString() : '') },
  ];

  const actionColumns: Column<any>[] = [
    { key: 'funnel_id', header: 'Funnel', render: (r: any) => String(r.funnel_id ?? '').slice(0, 8) },
    { key: 'action_type', header: 'Action', render: (r: any) => String(r.action_type ?? '') },
    { key: 'taken_at', header: 'Taken', render: (r: any) => (r.taken_at ? new Date(r.taken_at).toLocaleString() : '') },
    { key: 'by_email', header: 'By', render: (r: any) => String(r.by_email ?? '') },
    { key: 'notes_md', header: 'Notes', render: (r: any) => String(r.notes_md ?? '').slice(0, 80) },
  ];

  return (
    <div className="p-6 space-y-8">
      <header>
        <h1 className="text-2xl font-bold">Hospital Customer Activation Funnel v2</h1>
        <p className="text-sm text-gray-600">Track journey from signup to first repair. Spot stalled hospitals early.</p>
      </header>

      <section>
        <h2 className="text-lg font-semibold mb-2">All Funnels</h2>
        <DataTable rows={funnels} columns={funnelColumns} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Stalled and At-Risk</h2>
        <DataTable rows={stalled} columns={stalledColumns} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Recent Actions</h2>
        <DataTable rows={recent} columns={actionColumns} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>
    </div>
  );
}
