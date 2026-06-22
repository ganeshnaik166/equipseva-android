import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function HospitalCustomerSaturationIndexPage() {
  const sb = await getSupabaseServerClient();

  const [indicesRes, saturatedRes, actionsRes] = await Promise.all([
    sb.rpc('list_saturation_indices_r2007'),
    sb.rpc('saturated_regions_r2007'),
    sb.rpc('recent_saturation_actions_r2007', { p_limit: 50 }),
  ]);

  const indices: any[] = Array.isArray(indicesRes.data) ? indicesRes.data : [];
  const saturated: any[] = Array.isArray(saturatedRes.data) ? saturatedRes.data : [];
  const actions: any[] = Array.isArray(actionsRes.data) ? actionsRes.data : [];

  const indexCols: Column<any>[] = [
    { key: 'region_label', header: 'Region', render: (r: any) => r.region_label ?? '' },
    { key: 'hospital_category', header: 'Category', render: (r: any) => r.hospital_category ?? '' },
    { key: 'total_addressable', header: 'TAM', render: (r: any) => String(r.total_addressable ?? 0) },
    { key: 'customers_won', header: 'Won', render: (r: any) => String(r.customers_won ?? 0) },
    { key: 'customers_lost', header: 'Lost', render: (r: any) => String(r.customers_lost ?? 0) },
    { key: 'saturation_pct', header: 'Saturation pct', render: (r: any) => `${r.saturation_pct ?? 0}%` },
    { key: 'status', header: 'Status', render: (r: any) => r.status ?? '' },
    { key: 'captured_at', header: 'Captured', render: (r: any) => r.captured_at ? new Date(r.captured_at).toLocaleString() : '' },
  ];

  const saturatedCols: Column<any>[] = [
    { key: 'region_label', header: 'Region', render: (r: any) => r.region_label ?? '' },
    { key: 'hospital_category', header: 'Category', render: (r: any) => r.hospital_category ?? '' },
    { key: 'saturation_pct', header: 'Saturation pct', render: (r: any) => `${r.saturation_pct ?? 0}%` },
    { key: 'customers_won', header: 'Won', render: (r: any) => String(r.customers_won ?? 0) },
    { key: 'total_addressable', header: 'TAM', render: (r: any) => String(r.total_addressable ?? 0) },
    { key: 'captured_at', header: 'Captured', render: (r: any) => r.captured_at ? new Date(r.captured_at).toLocaleString() : '' },
  ];

  const actionCols: Column<any>[] = [
    { key: 'action_type', header: 'Action', render: (r: any) => r.action_type ?? '' },
    { key: 'by_email', header: 'By', render: (r: any) => r.by_email ?? '' },
    { key: 'taken_at', header: 'Taken', render: (r: any) => r.taken_at ? new Date(r.taken_at).toLocaleString() : '' },
    { key: 'notes_md', header: 'Notes', render: (r: any) => r.notes_md ?? '' },
  ];

  return (
    <div className="p-6 space-y-8">
      <header>
        <h1 className="text-2xl font-bold">Hospital Customer Saturation Index</h1>
        <p className="text-sm text-gray-600">Saturation by hospital category and region. Track growing, saturated, declining, and recovering markets.</p>
      </header>

      <section>
        <h2 className="text-lg font-semibold mb-2">All Saturation Indices</h2>
        <DataTable rows={indices} columns={indexCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Saturated Regions</h2>
        <DataTable rows={saturated} columns={saturatedCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Recent Saturation Actions</h2>
        <DataTable rows={actions} columns={actionCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>
    </div>
  );
}
