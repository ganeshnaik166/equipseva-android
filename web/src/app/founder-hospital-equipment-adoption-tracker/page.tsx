import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [adoptionsRes, pilotsRes, actionsRes] = await Promise.all([
    sb.rpc('list_adoptions_r2139'),
    sb.rpc('active_pilots_r2139'),
    sb.rpc('recent_actions_r2139'),
  ]);

  const adoptions: any[] = Array.isArray(adoptionsRes.data) ? adoptionsRes.data : [];
  const pilots: any[] = Array.isArray(pilotsRes.data) ? pilotsRes.data : [];
  const actions: any[] = Array.isArray(actionsRes.data) ? actionsRes.data : [];

  const adoptionCols: Column<any>[] = [
    { key: 'hospital_name', header: 'Hospital', render: (r: any) => String(r.hospital_name ?? '') },
    { key: 'equipment_label', header: 'Equipment', render: (r: any) => String(r.equipment_label ?? '') },
    { key: 'adoption_status', header: 'Adoption', render: (r: any) => String(r.adoption_status ?? '') },
    { key: 'adoption_date', header: 'Date', render: (r: any) => r.adoption_date ? String(r.adoption_date) : 'pending' },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
    { key: 'captured_at', header: 'Captured', render: (r: any) => r.captured_at ? new Date(r.captured_at).toLocaleString() : '' },
  ];

  const pilotCols: Column<any>[] = [
    { key: 'hospital_name', header: 'Hospital', render: (r: any) => String(r.hospital_name ?? '') },
    { key: 'equipment_label', header: 'Equipment', render: (r: any) => String(r.equipment_label ?? '') },
    { key: 'adoption_status', header: 'Phase', render: (r: any) => String(r.adoption_status ?? '') },
    { key: 'adoption_date', header: 'Started', render: (r: any) => r.adoption_date ? String(r.adoption_date) : 'pending' },
    { key: 'captured_at', header: 'Captured', render: (r: any) => r.captured_at ? new Date(r.captured_at).toLocaleString() : '' },
  ];

  const actionCols: Column<any>[] = [
    { key: 'equipment_label', header: 'Equipment', render: (r: any) => String(r.equipment_label ?? '') },
    { key: 'action_type', header: 'Action', render: (r: any) => String(r.action_type ?? '') },
    { key: 'by_email', header: 'By', render: (r: any) => String(r.by_email ?? '') },
    { key: 'taken_at', header: 'When', render: (r: any) => r.taken_at ? new Date(r.taken_at).toLocaleString() : '' },
    { key: 'notes_md', header: 'Notes', render: (r: any) => String(r.notes_md ?? '') },
  ];

  return (
    <main style={{ padding: 24, maxWidth: 1200, margin: '0 auto' }}>
      <h1 style={{ fontSize: 24, fontWeight: 700, marginBottom: 4 }}>Hospital Equipment Adoption Tracker</h1>
      <p style={{ color: '#666', marginBottom: 24 }}>
        Track new equipment adoption across hospital partners from evaluation through pilot to active use.
      </p>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>All adoptions</h2>
        <DataTable rows={adoptions} columns={adoptionCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Active pilots and evaluations</h2>
        <DataTable rows={pilots} columns={pilotCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Recent actions</h2>
        <DataTable rows={actions} columns={actionCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>
    </main>
  );
}
